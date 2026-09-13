import Combine
import Darwin
import Foundation

@MainActor
final class TodayStore: ObservableObject {
    enum State: Equatable { case loading, ready(TodayPayload, isStale: Bool), empty, malformed(String) }

    static let shared = TodayStore()
    @Published private(set) var state: State = .loading
    @Published private(set) var bridgeConnection: TodayBridgeConnection = .disconnected
    @Published private(set) var refreshPending = false
    @Published private(set) var notice: String?
    private var timer: Timer?
    private var watcher: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var debounceWorkItem: DispatchWorkItem?
    private var lastGoodPayload: TodayPayload?
    private var lastRefreshRequestAt: Date?

    private init() {}

    deinit {
        timer?.invalidate()
        debounceWorkItem?.cancel()
        watcher?.cancel()
    }

    static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("boring.notch/Today", isDirectory: true)
    }
    static var payloadURL: URL { directoryURL.appendingPathComponent("payload.json") }
    static var refreshRequestURL: URL { directoryURL.appendingPathComponent("refresh-request.json") }
    static var bridgeStatusURL: URL { directoryURL.appendingPathComponent("bridge-status.json") }

    private static func rejectSymlinks(_ urls: [URL]) throws {
        for url in urls where (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
            throw TodayPayloadError.unsafeAction("storage")
        }
    }

    func start() {
        reload()
        installWatcherIfNeeded()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
                self?.installWatcherIfNeeded()
            }
        }
    }

    func reload() {
        reloadBridgeStatus()
        reloadRefreshPending()
        guard FileManager.default.fileExists(atPath: Self.payloadURL.path) else {
            lastGoodPayload = nil
            state = .empty
            return
        }
        do {
            try Self.rejectSymlinks([Self.directoryURL.deletingLastPathComponent(), Self.directoryURL, Self.payloadURL])
            let values = try Self.payloadURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 64 * 1024 else {
                throw TodayPayloadError.invalidText("payload file")
            }
            let payload = try TodayPayload.decodeValidated(from: Data(contentsOf: Self.payloadURL))
            lastGoodPayload = payload
            if !refreshPending { notice = nil }
            state = .ready(payload, isStale: payload.isStale())
        } catch {
            notice = "Latest update was rejected."
            if let lastGoodPayload {
                state = .ready(lastGoodPayload, isStale: lastGoodPayload.isStale())
            } else {
                state = .malformed("The local Today payload is invalid.")
            }
        }
    }

    func requestRefresh() {
        let now = Date()
        guard lastRefreshRequestAt.map({ now.timeIntervalSince($0) >= 2 }) ?? true else {
            notice = "A refresh is already pending."
            return
        }
        let requestID = UUID().uuidString
        let body: [String: Any] = [
            "schemaVersion": 1,
            "id": requestID,
            "requestedAt": ISO8601DateFormatter().string(from: now),
            "source": "Boring Notch Today"
        ]
        do {
            try Self.rejectSymlinks([Self.directoryURL.deletingLastPathComponent(), Self.directoryURL, Self.refreshRequestURL])
            if FileManager.default.fileExists(atPath: Self.directoryURL.path) {
                let values = try Self.directoryURL.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard values.isSymbolicLink != true else { throw TodayPayloadError.unsafeAction("storage") }
            }
            try FileManager.default.createDirectory(at: Self.directoryURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: Self.directoryURL.path)
            let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            try data.write(to: Self.refreshRequestURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.refreshRequestURL.path)
            lastRefreshRequestAt = now
            refreshPending = true
            notice = "Refresh requested. An authorized AI run must respond."
        } catch {
            notice = "Could not create the local refresh request."
        }
    }

    private func reloadBridgeStatus() {
        guard FileManager.default.fileExists(atPath: Self.bridgeStatusURL.path) else {
            bridgeConnection = .disconnected
            return
        }
        do {
            try Self.rejectSymlinks([Self.directoryURL.deletingLastPathComponent(), Self.directoryURL, Self.bridgeStatusURL])
            let values = try Self.bridgeStatusURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 4 * 1024 else {
                throw TodayPayloadError.invalidText("bridge status")
            }
            bridgeConnection = try TodayBridgeStatus.decodeConnection(from: Data(contentsOf: Self.bridgeStatusURL))
        } catch {
            bridgeConnection = .error
        }
    }

    private func reloadRefreshPending() {
        guard FileManager.default.fileExists(atPath: Self.refreshRequestURL.path) else {
            refreshPending = false
            return
        }
        do {
            try Self.rejectSymlinks([Self.directoryURL.deletingLastPathComponent(), Self.directoryURL, Self.refreshRequestURL])
            let values = try Self.refreshRequestURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 4 * 1024,
                  let object = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.refreshRequestURL)) as? [String: Any],
                  Set(object.keys) == Set(["schemaVersion", "id", "requestedAt", "source"]),
                  object["schemaVersion"] as? Int == 1,
                  object["source"] as? String == "Boring Notch Today",
                  let requestID = object["id"] as? String, UUID(uuidString: requestID) != nil,
                  let requestedAt = object["requestedAt"] as? String,
                  ISO8601DateFormatter().date(from: requestedAt) != nil else {
                throw TodayPayloadError.invalidText("refresh request")
            }
            refreshPending = true
        } catch {
            refreshPending = false
        }
    }

    private func nearestExistingWatchURL() -> URL? {
        var candidate = Self.directoryURL
        while candidate.path != "/" {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return nil
    }

    private func installWatcherIfNeeded(force: Bool = false) {
        guard let target = nearestExistingWatchURL() else { return }
        if !force, watcher != nil, watchedURL == target { return }
        watcher?.cancel()
        watcher = nil
        watchedURL = nil
        let descriptor = open(target.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            let flags = source?.data ?? []
            Task { @MainActor in
                self?.scheduleReload(rebind: flags.contains(.rename) || flags.contains(.delete))
            }
        }
        source.setCancelHandler { close(descriptor) }
        watcher = source
        watchedURL = target
        source.resume()
    }

    private func scheduleReload(rebind: Bool) {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.reload()
                let nowWatchingToday = self.watchedURL == Self.directoryURL
                self.installWatcherIfNeeded(force: rebind || !nowWatchingToday)
            }
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}
