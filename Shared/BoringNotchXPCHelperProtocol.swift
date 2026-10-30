//
//  BoringNotchXPCHelperProtocol.swift
//  BoringNotchXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import Foundation

enum BoringNotchAppBundleNames {
    static let legacy = "boringNotch.app"
    static let current = "Boring Notch.app"
}

@objc protocol BoringNotchXPCHelperLunarListener {
    func lunarEventDidUpdate(_ event: BNLunarBrightnessEvent)
    func lunarStreamDidStop(_ reason: String?)
}

@objc(BNLunarBrightnessEvent)
final class BNLunarBrightnessEvent: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let brightness: Double
    let display: Int

    init(brightness: Double, display: Int) {
        self.brightness = brightness
        self.display = display
        super.init()
    }

    required init?(coder: NSCoder) {
        brightness = coder.decodeDouble(forKey: "brightness")
        display = coder.decodeInteger(forKey: "display")
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(brightness, forKey: "brightness")
        coder.encode(display, forKey: "display")
    }
}

@objc protocol BoringNotchXPCHelperProtocol {
    func isAccessibilityAuthorized(with reply: @escaping (Bool) -> Void)
    func migrateLegacyAppBundle(from sourcePath: String, to destinationPath: String, with reply: @escaping (Bool) -> Void)
    func requestAccessibilityAuthorization()
    func ensureAccessibilityAuthorization(_ promptIfNeeded: Bool, with reply: @escaping (Bool) -> Void)
    func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    func displayIDForBrightness(with reply: @escaping (NSNumber?) -> Void)
    func currentScreenBrightness(with reply: @escaping (NSNumber?) -> Void)
    func setScreenBrightness(_ value: Float, with reply: @escaping (Bool) -> Void)
    func adjustScreenBrightness(by value: Float, with reply: @escaping (NSNumber?) -> Void)
    func isLunarAvailable(with reply: @escaping (Bool) -> Void)
    func startLunarEventStream(with reply: @escaping (Bool) -> Void)
    func stopLunarEventStream()
    func setLunarOSDHidden(_ hide: Bool, with reply: @escaping (Bool) -> Void)
    func startNotificationWatching(with reply: @escaping (Bool) -> Void)
    func stopNotificationWatching()
    func setNotificationFilter(_ bundleIDs: [String], allApps: Bool)
    /// A `LidGuardSetup` raw value for the root lid-guard script.
    func lidGuardSetupStatus(with reply: @escaping (Int) -> Void)
    /// Turns system sleep off (`true`) or back on through the lid-guard script.
    func setLidGuard(_ enabled: Bool, with reply: @escaping (Bool) -> Void)
    /// Whether the Claude desktop app currently holds an idle-sleep assertion.
    func isClaudeWorking(with reply: @escaping (Bool) -> Void)
}

/// What stands between the app and lid-closed keep-awake. Raw values cross
/// the XPC boundary as plain integers.
enum LidGuardSetup: Int {
    case ready = 0
    case notInstalled = 1
    /// The script or its folder can be changed by someone other than root,
    /// which would turn the sudoers rule into a privilege hole.
    case insecure = 2
    case noSudoRule = 3
    case unknown = 4

    static let scriptPath = "/usr/local/libexec/boringnotch-lidguard"
}

@objc protocol BoringNotchXPCHelperDelegate {
    func notificationDidAppear(_ payload: [String: String])
}

@objc protocol BoringNotchXPCAppDelegate: BoringNotchXPCHelperLunarListener, BoringNotchXPCHelperDelegate {}
