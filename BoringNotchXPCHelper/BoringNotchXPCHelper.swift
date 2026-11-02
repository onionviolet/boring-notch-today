//
//  BoringNotchXPCHelper.swift
//  BoringNotchXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import AppKit
import ApplicationServices
import IOKit
import IOKit.pwr_mgt

class BoringNotchXPCHelper: NSObject, BoringNotchXPCHelperProtocol {
    private weak var connection: NSXPCConnection?

    private let lunarStateQueue = DispatchQueue(label: "BoringNotchXPCHelper.lunar.state")
    private let lunarExecutableURL = URL(fileURLWithPath: "/Applications/Lunar.app/Contents/MacOS/Lunar")
    private var lunarProcess: Process?
    private var lunarPipeHandler: JSONLinesPipeHandler?
    private var lunarStreamTask: Task<Void, Never>?
    private var lunarListener: BoringNotchXPCHelperLunarListener?

    init(connection: NSXPCConnection) {
        self.connection = connection
        super.init()
    }

    override init() {
        super.init()
    }

    deinit {
        var processToTerminate: Process?
        var taskToCancel: Task<Void, Never>?
        var pipeHandlerToClose: JSONLinesPipeHandler?

        lunarStateQueue.sync {
            processToTerminate = self.lunarProcess
            self.lunarProcess = nil

            taskToCancel = self.lunarStreamTask
            self.lunarStreamTask = nil

            pipeHandlerToClose = self.lunarPipeHandler
            self.lunarPipeHandler = nil

            self.lunarListener = nil
        }

        taskToCancel?.cancel()
        if let p = processToTerminate, p.isRunning { p.terminate() }
        if let ph = pipeHandlerToClose {
            Task { await ph.close() }
        }
    }

    @objc func isAccessibilityAuthorized(with reply: @escaping (Bool) -> Void) {
        reply(AXIsProcessTrusted())
    }

    @objc func migrateLegacyAppBundle(
        from sourcePath: String,
        to destinationPath: String,
        with reply: @escaping (Bool) -> Void
    ) {
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        let destinationURL = URL(fileURLWithPath: destinationPath).standardizedFileURL
        let fileManager = FileManager.default

        guard sourceURL.lastPathComponent == BoringNotchAppBundleNames.legacy,
              destinationURL.lastPathComponent == BoringNotchAppBundleNames.current,
              sourceURL.deletingLastPathComponent() == destinationURL.deletingLastPathComponent(),
              fileManager.fileExists(atPath: sourceURL.path),
              !fileManager.fileExists(atPath: destinationURL.path)
        else {
            NSLog("[boringNotch] refused legacy bundle migration for %@ -> %@", sourcePath, destinationPath)
            reply(false)
            return
        }

        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            NSWorkspace.shared.noteFileSystemChanged(destinationURL.deletingLastPathComponent().path)
            reply(true)
        } catch {
            NSLog("[boringNotch] legacy bundle migration failed for %@: %@", sourcePath, error.localizedDescription)
            reply(false)
        }
    }

    @objc func requestAccessibilityAuthorization() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc func ensureAccessibilityAuthorization(_ promptIfNeeded: Bool, with reply: @escaping (Bool) -> Void) {
        if AXIsProcessTrusted() {
            reply(true)
            return
        }

        guard promptIfNeeded else {
            reply(false)
            return
        }

        requestAccessibilityAuthorization()

        let deadline = DispatchTime.now() + .seconds(15)
        func waitForAuthorization() {
            if AXIsProcessTrusted() {
                reply(true)
            } else if DispatchTime.now() >= deadline {
                reply(false)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    waitForAuthorization()
                }
            }
        }
        waitForAuthorization()
    }

    // MARK: - Notification Center banners

    private static let watcher = NotificationWatcher()

    @objc func startNotificationWatching(with reply: @escaping (Bool) -> Void) {
        // Capture the delegate for this connection before hopping queues —
        // NSXPCConnection.current() is only valid inside the incoming call.
        //
        // Cast to BoringNotchXPCAppDelegate, not its parent protocol: the
        // proxy's conformance is built from the exact interface the
        // connection was configured with, so casting to the parent can
        // return nil and silently swallow every callback.
        let connection = NSXPCConnection.current()
        let proxy = connection?.remoteObjectProxyWithErrorHandler { error in
            NSLog("[boringNotch] notification callback failed: \(error.localizedDescription)")
        }
        let delegate = proxy as? BoringNotchXPCAppDelegate

        if delegate == nil {
            NSLog("[boringNotch] could not obtain notification delegate proxy — banners will not reach the app")
        }

        DispatchQueue.main.async {
            let watcher = Self.watcher
            watcher.onBanner = { notification in
                delegate?.notificationDidAppear([
                    "token": notification.token,
                    "appName": notification.appName ?? "",
                    "bundleID": notification.bundleID ?? "",
                    "title": notification.title ?? "",
                    "subtitle": notification.subtitle ?? "",
                    "body": notification.body ?? ""
                ])
            }
            let started = watcher.start()
            NSLog("[boringNotch] notification watcher start -> \(started), AX trusted: \(AXIsProcessTrusted())")
            reply(started)
        }
    }

    @objc func stopNotificationWatching() {
        DispatchQueue.main.async { Self.watcher.stop() }
    }

    @objc func setNotificationFilter(_ bundleIDs: [String], allApps: Bool) {
        DispatchQueue.main.async {
            Self.watcher.configureFilter(bundleIDs: Set(bundleIDs), allApps: allApps)
        }
    }
    private class KeyboardBrightnessClient {
        private static let keyboardID: UInt64 = 1
        private var clientInstance: NSObject?
        private let getSelector = NSSelectorFromString("brightnessForKeyboard:")
        private let setSelector = NSSelectorFromString("setBrightness:forKeyboard:")

        init() {
            var loaded = false
            let bundlePaths = [
                "/System/Library/PrivateFrameworks/CoreBrightness.framework",
                "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
            ]
            for path in bundlePaths where !loaded {
                if let bundle = Bundle(path: path) {
                    loaded = bundle.load()
                }
            }
            if loaded, let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type {
                clientInstance = cls.init()
            }
        }

        func currentBrightness() -> Float? {
            guard let clientInstance,
                  let fn: BrightnessGetter = methodIMP(on: clientInstance, selector: getSelector, as: BrightnessGetter.self)
            else { return nil }
            return fn(clientInstance, getSelector, Self.keyboardID)
        }

        func setBrightness(_ value: Float) -> Bool {
            guard let clientInstance,
                  let fn: BrightnessSetter = methodIMP(on: clientInstance, selector: setSelector, as: BrightnessSetter.self)
            else { return false }
            return fn(clientInstance, setSelector, value, Self.keyboardID).boolValue
        }

        private typealias BrightnessGetter = @convention(c) (NSObject, Selector, UInt64) -> Float
        private typealias BrightnessSetter = @convention(c) (NSObject, Selector, Float, UInt64) -> ObjCBool

        private func methodIMP<T>(on object: NSObject, selector: Selector, as type: T.Type) -> T? {
            guard let cls = object_getClass(object),
                  let method = class_getInstanceMethod(cls, selector)
            else { return nil }
            let imp = method_getImplementation(method)
            return unsafeBitCast(imp, to: type)
        }
    }

    private static let keyboardClient = KeyboardBrightnessClient()

    @objc func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void) {
        reply(Self.keyboardClient.currentBrightness().map { NSNumber(value: $0) })
    }

    @objc func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void) {
        reply(Self.keyboardClient.setBrightness(value))
    }
    // MARK: - Screen Brightness (moved from client app into helper)

    private func brightnessDisplayID() -> CGDirectDisplayID {
        let mainDisplayID = CGMainDisplayID()
        var tmp: Float = 0

        if displayServicesGetBrightness(displayID: mainDisplayID, out: &tmp) {
            return mainDisplayID
        }
        if let service = ioServiceFor(displayID: mainDisplayID) {
            IOObjectRelease(service)
            return mainDisplayID
        }

        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        let allocated = Int(count)
        var ids = [CGDirectDisplayID](repeating: 0, count: allocated)
        CGGetOnlineDisplayList(count, &ids, &count)
        for id in ids {
            if CGDisplayIsBuiltin(id) != 0 {
                return id
            }
        }

        return mainDisplayID
    }

    @objc func currentScreenBrightness(with reply: @escaping (NSNumber?) -> Void) {
        let displayID = brightnessDisplayID()
        var b: Float = 0
        if displayServicesGetBrightness(displayID: displayID, out: &b) {
            reply(NSNumber(value: b))
            return
        }
        if let io = ioServiceFor(displayID: displayID) {
            var level: Float = 0
            if IODisplayGetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, &level) == kIOReturnSuccess {
                IOObjectRelease(io)
                reply(NSNumber(value: level))
                return
            }
            IOObjectRelease(io)
        }
        reply(nil)
    }

    @objc func setScreenBrightness(_ value: Float, with reply: @escaping (Bool) -> Void) {
        let clamped = max(0, min(1, value))
        let displayID = brightnessDisplayID()
        if displayServicesSetBrightness(displayID: displayID, value: clamped) {
            reply(true)
            return
        }
        if let io = ioServiceFor(displayID: displayID) {
            let ok = IODisplaySetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, clamped) == kIOReturnSuccess
            IOObjectRelease(io)
            reply(ok)
            return
        }
        reply(false)
    }

    @objc func adjustScreenBrightness(by value: Float, with reply: @escaping (NSNumber?) -> Void) {
        let displayID = brightnessDisplayID()
        if displayServicesSetBrightnessSmooth(displayID: displayID, value: value) {
            // Read back inside the helper so the client pays for one RPC
            // instead of two (adjust + currentScreenBrightness).
            var b: Float = 0
            if displayServicesGetBrightness(displayID: displayID, out: &b) {
                reply(NSNumber(value: b))
                return
            }
            reply(nil)
            return
        }
        if let io = ioServiceFor(displayID: displayID) {
            var ioCurrent: Float = 0
            if IODisplayGetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, &ioCurrent) == kIOReturnSuccess {
                let target = max(0, min(1, ioCurrent + value))
                let ok = IODisplaySetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, target) == kIOReturnSuccess
                IOObjectRelease(io)
                reply(ok ? NSNumber(value: target) : nil)
                return
            }
            IOObjectRelease(io)
        }
        reply(nil)
    }

    // MARK: - Lunar Events

    @objc func displayIDForBrightness(with reply: @escaping (NSNumber?) -> Void) {
        let id = brightnessDisplayID()
        reply(NSNumber(value: id))
    }

    @objc func isLunarAvailable(with reply: @escaping (Bool) -> Void) {
        reply(FileManager.default.isExecutableFile(atPath: lunarExecutableURL.path))
    }

    @objc func startLunarEventStream(with reply: @escaping (Bool) -> Void) {
        lunarStateQueue.async { [weak self] in
            guard let self else {
                reply(false)
                return
            }

            if let lunarProcess = self.lunarProcess, lunarProcess.isRunning {
                reply(true)
                return
            }

            guard FileManager.default.isExecutableFile(atPath: self.lunarExecutableURL.path) else {
                reply(false)
                return
            }

            guard let connection = self.connection else {
                reply(false)
                return
            }

            let listenerProxy = connection.remoteObjectProxyWithErrorHandler { _ in
                self.stopLunarEventStream()
            } as? BoringNotchXPCHelperLunarListener

            guard let listenerProxy else {
                reply(false)
                return
            }

            let process = Process()
            process.executableURL = self.lunarExecutableURL
            process.arguments = ["@", "listen", "--only-user-adjustments", "-j"]

            let pipeHandler = JSONLinesPipeHandler()
            process.standardOutput = pipeHandler.outputPipe
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { [weak self] _ in
                self?.stopLunarEventStream(reason: "Lunar stream ended")
            }

            do {
                try process.run()
            } catch {
                reply(false)
                return
            }

            self.lunarProcess = process
            self.lunarPipeHandler = pipeHandler
            self.lunarListener = listenerProxy

            let currentPipeHandler = pipeHandler
            self.lunarStreamTask = Task { [weak self] in
                await self?.readLunarEvents(pipeHandler: currentPipeHandler)
            }

            reply(true)
        }
    }

    @objc func stopLunarEventStream() {
        stopLunarEventStream(reason: nil)
    }

    private func stopLunarEventStream(reason: String?) {
        lunarStateQueue.async { [weak self] in
            guard let self else { return }

            self.lunarStreamTask?.cancel()
            self.lunarStreamTask = nil

            if let lunarProcess = self.lunarProcess, lunarProcess.isRunning {
                lunarProcess.terminate()
            }

            self.lunarProcess = nil

            if let pipeHandler = self.lunarPipeHandler {
                pipeHandler.close()
            }

            self.lunarPipeHandler = nil

            if let reason {
                self.lunarListener?.lunarStreamDidStop(reason)
            }

            self.lunarListener = nil
        }
    }

    private func readLunarEvents(pipeHandler: JSONLinesPipeHandler) async {
        await pipeHandler.readJSONLines(as: LunarBrightnessEvent.self) { [weak self] event in
            self?.emitLunarEvent(event)
        }
    }

    private func emitLunarEvent(_ event: LunarBrightnessEvent) {
        let payload = BNLunarBrightnessEvent(
            brightness: event.brightness,
            display: event.display
        )
        lunarStateQueue.async { [weak self] in
            self?.lunarListener?.lunarEventDidUpdate(payload)
        }
    }

    // MARK: - Lunar OSD preference (hideOSD)

    private static let lunarBundleID = "fyi.lunar.Lunar"
    private static let lunarHideOSDKey = "hideOSD"

    @objc func setLunarOSDHidden(_ hide: Bool, with reply: @escaping (Bool) -> Void) {
        let appID = Self.lunarBundleID as CFString
        let key = Self.lunarHideOSDKey as CFString
        let value = hide as CFBoolean
        NSLog("Hide OSD in Lunar: \(hide)")
        CFPreferencesSetValue(key, value, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let ok = CFPreferencesSynchronize(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        reply(ok)
    }

    // MARK: - Private helpers for DisplayServices / IOKit access
    private func displayServicesGetBrightness(displayID: CGDirectDisplayID, out: inout Float) -> Bool {
        guard let sym = dlsym(DisplayServicesHandle.handle, "DisplayServicesGetBrightness") else { return false }
        typealias Fn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        var tmp: Float = 0
        let r = fn(displayID, &tmp)
        if r == 0 { out = tmp; return true }
        return false
    }

    private func displayServicesSetBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let sym = dlsym(DisplayServicesHandle.handle, "DisplayServicesSetBrightness") else { return false }
        typealias Fn = @convention(c) (CGDirectDisplayID, Float) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        return fn(displayID, value) == 0
    }

    private func displayServicesSetBrightnessSmooth(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let sym = dlsym(DisplayServicesHandle.handle, "DisplayServicesSetBrightnessSmooth") else { return false }
        typealias Fn = @convention(c) (CGDirectDisplayID, Float) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        return fn(displayID, value) == 0
    }

    private func ioServiceFor(displayID: CGDirectDisplayID) -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            let info = IODisplayCreateInfoDictionary(service, 0).takeRetainedValue() as NSDictionary
            if let vendorID = info[kDisplayVendorID] as? UInt32,
               let productID = info[kDisplayProductID] as? UInt32,
               vendorID == CGDisplayVendorNumber(displayID),
               productID == CGDisplayModelNumber(displayID) {
                return service
            }
            IOObjectRelease(service)
        }
        return nil
    }

    // MARK: - Helper handle for private framework
    private enum DisplayServicesHandle {
        static let handle: UnsafeMutableRawPointer? = {
            let paths = [
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices"
            ]
            for p in paths {
                if let h = dlopen(p, RTLD_LAZY) { return h }
            }
            return nil
        }()
    }
}

// MARK: - Lunar Parsing

private struct LunarBrightnessEvent: Decodable, Sendable {
    let brightness: Double
    let display: Int
}

// MARK: - Keep Awake

extension BoringNotchXPCHelper {
    /// Desktop apps whose own idle-sleep assertion means an agent is mid-turn.
    /// Electron names every blocker "Electron", so these match by PID.
    private static let agentAppBundleIDs = ["com.anthropic.claudefordesktop", "com.openai.codex"]
    /// CLI executables matched by name: Codex holds its own assertion for an
    /// active turn, and Claude Code spawns `caffeinate -i` as its child.
    private static let agentExecutables: Set<String> = ["claude", "codex"]

    @objc func lidGuardSetupStatus(with reply: @escaping (Int) -> Void) {
        reply(Self.lidGuardSetup().rawValue)
    }

    private static func lidGuardSetup() -> LidGuardSetup {
        let path = LidGuardSetup.scriptPath
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: path) else {
            return .notInstalled
        }
        // Root must own the script and every folder above it, with no group
        // or world write access; otherwise anyone who can rename a folder in
        // the chain can swap the script, so refuse the sudoers rule.
        var chain = [path]
        var folder = (path as NSString).deletingLastPathComponent
        while folder != "/" && !folder.isEmpty {
            chain.append(folder)
            folder = (folder as NSString).deletingLastPathComponent
        }
        for item in chain {
            guard let attrs = try? fm.attributesOfItem(atPath: item),
                  (attrs[.ownerAccountID] as? NSNumber)?.intValue == 0,
                  let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue,
                  perms & 0o022 == 0
            else {
                return .insecure
            }
        }
        let allowed = runSudo(["-n", "-l", path, "off"]) == 0
        return allowed ? .ready : .noSudoRule
    }

    @objc func setLidGuard(_ enabled: Bool, with reply: @escaping (Bool) -> Void) {
        let path = LidGuardSetup.scriptPath
        guard enabled else {
            reply(Self.runSudo(["-n", path, "off"]) == 0)
            return
        }
        // The watchdog follows the app, not this helper: launchd can stop an
        // idle XPC service while the app keeps running.
        guard let pid = connection?.processIdentifier, pid > 0 else {
            reply(false)
            return
        }
        reply(Self.runSudo(["-n", path, "on", String(pid)]) == 0)
    }

    @objc func configureLidGuard(_ install: Bool, with reply: @escaping (Int) -> Void) {
        let script = LidGuardSetup.scriptPath
        let sudoers = LidGuardSetup.sudoersPath
        let command: String
        if install {
            // The user name goes into a sudoers line, so only plain account
            // names pass; the script is copied from this app's own bundle,
            // never from a path the app hands over.
            let user = NSUserName()
            guard user.range(of: "^[A-Za-z0-9_][A-Za-z0-9_.-]*$", options: .regularExpression) != nil,
                  let source = Self.bundledLidGuardURL()
            else {
                reply(Self.lidGuardSetup().rawValue)
                return
            }
            let rule = "\(user) ALL=(root) NOPASSWD: \(script)"
            // visudo checks the rule before it lands: a malformed file in
            // sudoers.d breaks sudo for the whole Mac.
            command = """
            set -e
            tmp=$(/usr/bin/mktemp /private/tmp/boringnotch-lidguard.XXXXXX)
            trap '/bin/rm -f "$tmp"' EXIT
            printf '%s\\n' \(Self.shellQuote(rule)) > "$tmp"
            /usr/sbin/visudo -cf "$tmp" >/dev/null
            /usr/bin/install -d -o root -g wheel -m 755 /usr/local/libexec
            /usr/bin/install -o root -g wheel -m 755 \(Self.shellQuote(source.path)) \(Self.shellQuote(script))
            /usr/bin/install -o root -g wheel -m 440 "$tmp" \(Self.shellQuote(sudoers))
            """
        } else {
            // Turn sleep back on before the rule that allows it disappears.
            command = """
            \(Self.shellQuote(script)) off >/dev/null 2>&1 || true
            /bin/rm -f \(Self.shellQuote(sudoers)) \(Self.shellQuote(script))
            """
        }
        let status = Self.runAsAdministrator(command)
        reply(status == .cancelled ? LidGuardSetup.cancelled : Self.lidGuardSetup().rawValue)
    }

    @objc func isAgentWorking(with reply: @escaping (Bool) -> Void) {
        let appPIDs = Set(Self.agentAppBundleIDs
            .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            .map(\.processIdentifier))
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byPID = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else {
            reply(false)
            return
        }
        let sleepTypes: Set<String> = [
            "NoIdleSleepAssertion",
            kIOPMAssertionTypePreventUserIdleSystemSleep as String,
        ]
        let working = byPID.contains { pid, assertions in
            guard assertions.contains(where: {
                sleepTypes.contains($0[kIOPMAssertionTypeKey as String] as? String ?? "")
            }) else { return false }
            let pid = pid.int32Value
            if appPIDs.contains(pid) { return true }
            guard let name = Self.executableName(pid) else { return false }
            if Self.agentExecutables.contains(name) { return true }
            // Only a caffeinate an agent started counts, not one from a shell.
            if name == "caffeinate", let parent = Self.parentPID(pid),
               let parentName = Self.executableName(parent) {
                return Self.agentExecutables.contains(parentName)
            }
            return false
        }
        reply(working)
    }

    /// The helper sits at Boring Notch.app/Contents/XPCServices/*.xpc.
    private static func bundledLidGuardURL() -> URL? {
        let contents = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = contents
            .appendingPathComponent("Resources")
            .appendingPathComponent(LidGuardSetup.bundledScriptName)
        return FileManager.default.isReadableFile(atPath: url.path) ? url : nil
    }

    private static func executableName(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return (String(cString: buffer) as NSString).lastPathComponent
    }

    private static func parentPID(_ pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private enum AdminStatus { case ok, failed, cancelled }

    /// One macOS administrator prompt for the whole command.
    private static func runAsAdministrator(_ command: String) -> AdminStatus {
        let literal = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"\(literal)\" with administrator privileges"]
        let errors = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        do {
            try process.run()
        } catch {
            return .failed
        }
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        if process.terminationStatus == 0 { return .ok }
        // AppleScript error -128 is "User canceled."
        return message.contains("-128") ? .cancelled : .failed
    }

    /// Runs sudo with no prompt (`-n`), so a missing rule fails at once
    /// instead of hanging on a password. Returns the exit status, or -1.
    private static func runSudo(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
