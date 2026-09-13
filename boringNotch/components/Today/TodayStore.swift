import Combine
import Foundation

@MainActor
final class TodayStore: ObservableObject {
    enum State: Equatable { case loading, ready(TodayPayload, isStale: Bool), empty, malformed(String) }

    static let shared = TodayStore()
    @Published private(set) var state: State = .loading
    private var timer: Timer?

    private init() {}

    deinit { timer?.invalidate() }

    static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("boring.notch/Today", isDirectory: true)
    }
    static var payloadURL: URL { directoryURL.appendingPathComponent("payload.json") }
    static var refreshRequestURL: URL { directoryURL.appendingPathComponent("refresh-request.json") }

    private static func rejectSymlinks(_ urls: [URL]) throws {
        for url in urls where (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
            throw TodayPayloadError.unsafeAction("storage")
        }
    }

    func start() {
        reload()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: Self.payloadURL.path) else { state = .empty; return }
        do {
            try Self.rejectSymlinks([Self.directoryURL.deletingLastPathComponent(), Self.directoryURL, Self.payloadURL])
            let values = try Self.payloadURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 64 * 1024 else {
                throw TodayPayloadError.invalidText("payload file")
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(TodayPayload.self, from: Data(contentsOf: Self.payloadURL)).validated()
            state = .ready(payload, isStale: payload.isStale())
        } catch {
            state = .malformed(error.localizedDescription)
        }
    }

    func requestRefresh() {
        let body = ["requestedAt": ISO8601DateFormatter().string(from: Date()), "source": "Boring Notch Today"]
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
        } catch { state = .malformed("Could not request refresh: \(error.localizedDescription)") }
    }
}
