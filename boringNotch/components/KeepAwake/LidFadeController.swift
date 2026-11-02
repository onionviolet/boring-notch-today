//
//  LidFadeController.swift
//  boringNotch
//
//  Duo-style fade: as the lid closes, the built-in screen fades to black,
//  and fades back in as it opens. The hinge angle comes from the lid-angle
//  sensor (Apple SPU HID device 0x05AC:0x8104, usage page 0x20, usage 0x8A),
//  read as feature report 1. The fade is a click-through black window, never
//  a gamma change, so it vanishes with the app and can't get stuck on.
//

import AppKit
import Combine
import Defaults
import IOKit.hid

@MainActor
final class LidFadeController: ObservableObject {
    static let shared = LidFadeController()

    /// Nil until the sensor is first tried; false on Macs without one (or
    /// when a sandboxed build can't open it).
    @Published private(set) var sensorAvailable: Bool?

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var timer: Timer?
    private var overlay: NSWindow?
    private var lastAngle: Double?
    /// When the screen went fully dark while the lid switch still says open.
    private var darkSince: Date?
    /// Set by the failsafe; cleared once the lid reads open again.
    private var suspended = false
    private var started = false
    private var cancellables: Set<AnyCancellable> = []

    /// A sensor that reports "closed" while the lid switch says open for
    /// this long is treated as wrong, so a bad reading can't hold the screen
    /// black.
    private let failsafeDelay: TimeInterval = 5

    private init() {}

    /// Called once at launch.
    func start() {
        guard !started else { return }
        started = true
        Defaults.publisher(.lidFadeEnabled).sink { [weak self] change in
            Task { @MainActor in change.newValue ? self?.enable() : self?.disable() }
        }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.placeOverlay() } }
            .store(in: &cancellables)
    }

    func stop() {
        disable()
    }

    // MARK: - Sensor

    private func enable() {
        guard openSensor() else {
            sensorAvailable = false
            return
        }
        sensorAvailable = true
        schedule(after: 0)
    }

    private func disable() {
        timer?.invalidate()
        timer = nil
        hideOverlay()
        closeSensor()
        lastAngle = nil
        darkSince = nil
        suspended = false
    }

    private func openSensor() -> Bool {
        if device != nil { return true }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
            kIOHIDPrimaryUsagePageKey: 0x20,
            kIOHIDPrimaryUsageKey: 0x8A,
        ] as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let device = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first,
              IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess
        else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }
        self.manager = manager
        self.device = device
        guard readAngle() != nil else {
            closeSensor()
            return false
        }
        return true
    }

    private func closeSensor() {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        manager = nil
    }

    /// Degrees, 0 shut to roughly 130+ fully open.
    private func readAngle() -> Double? {
        guard let device else { return nil }
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length) == kIOReturnSuccess,
              length >= 3
        else { return nil }
        return Double(Int(report[1]) | Int(report[2]) << 8)
    }

    // MARK: - Loop

    private func schedule(after interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let angle = readAngle() else {
            // Lost the sensor mid-run (a handle can die across sleep): show
            // the screen, drop the handle and reopen it on a slow retry.
            hideOverlay()
            closeSensor()
            lastAngle = nil
            if openSensor() {
                schedule(after: 0)
            } else {
                schedule(after: 1)
            }
            return
        }
        let interval = LidFadeCurve.pollInterval(angle: angle)
        schedule(after: interval)

        if suspended {
            guard angle >= LidFadeCurve.fadeStart else { return }
            suspended = false
            lastAngle = nil
        }

        let opacity = LidFadeCurve.opacity(angle: angle)
        if opacity >= 1 && !Self.lidSwitchClosed() {
            let since = darkSince ?? Date()
            darkSince = since
            if Date().timeIntervalSince(since) > failsafeDelay {
                suspended = true
                darkSince = nil
                hideOverlay()
                return
            }
        } else {
            darkSince = nil
        }

        // Ignore sensor jitter.
        if let lastAngle, abs(angle - lastAngle) < 1 { return }
        lastAngle = angle
        setOverlay(opacity: opacity, over: interval)
    }

    /// The lid's magnet switch, independent of the angle sensor.
    private static func lidSwitchClosed() -> Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        let value = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return (value?.takeRetainedValue() as? Bool) ?? false
    }

    // MARK: - Overlay

    private func setOverlay(opacity: Double, over duration: TimeInterval) {
        guard opacity > 0 else {
            hideOverlay()
            return
        }
        guard let window = overlay ?? makeOverlay() else { return }
        if !window.isVisible {
            window.alphaValue = 0
            window.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            window.animator().alphaValue = opacity
        }
    }

    private func hideOverlay() {
        overlay?.orderOut(nil)
        overlay?.alphaValue = 0
    }

    private func makeOverlay() -> NSWindow? {
        guard let screen = Self.builtInScreen() else { return nil }
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.backgroundColor = .black
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // Above the notch, menu bar and Dock.
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.setFrame(screen.frame, display: false)
        overlay = window
        return window
    }

    private func placeOverlay() {
        guard let overlay else { return }
        if let screen = Self.builtInScreen() {
            overlay.setFrame(screen.frame, display: true)
        } else {
            // Built-in display gone (clamshell with an external screen).
            hideOverlay()
        }
    }

    private static func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
    }
}
