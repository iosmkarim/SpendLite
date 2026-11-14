//
//  AppLock.swift
//  SpendLite
//

import Foundation
import Combine
import LocalAuthentication

/// Something that can check it's really the owner (Face ID / Touch ID, falling back to the passcode).
protocol Authenticator {
    /// "Face ID", "Touch ID", "Optic ID" or "Passcode".
    var methodName: String { get }
    /// SF Symbol for the method.
    var systemImage: String { get }
    /// False when the device has no passcode set, so locking would be impossible.
    var isAvailable: Bool { get }
    func authenticate(reason: String) async -> Bool
}

/// The real thing, using LocalAuthentication. `.deviceOwnerAuthentication` falls back to the
/// device passcode, so a failed or unavailable Face ID never locks the owner out.
struct DeviceAuthenticator: Authenticator {
    private var biometry: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var methodName: String {
        switch biometry {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Passcode"
        }
    }

    var systemImage: String {
        switch biometry {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock.fill"
        }
    }

    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func authenticate(reason: String) async -> Bool {
        do {
            return try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

/// For tests and UI tests: always succeeds or always fails, instantly.
struct FakeAuthenticator: Authenticator {
    var succeeds: Bool
    var methodName = "Face ID"
    var systemImage = "faceid"
    var isAvailable = true

    func authenticate(reason: String) async -> Bool { succeeds }
}

/// Locks SpendLite behind Face ID / Touch ID / passcode when the user turns it on in Settings.
final class AppLock: ObservableObject {

    static let enabledKey = "appLockEnabled"

    /// The setting. Changed only through `setEnabled`, which asks for authentication first.
    @Published private(set) var isEnabled: Bool
    /// True while the lock screen should cover the app.
    @Published private(set) var isLocked: Bool
    /// True while the system authentication prompt is showing (so we don't prompt twice).
    @Published private(set) var isAuthenticating = false

    let authenticator: Authenticator
    private let store: UserDefaults

    init(store: UserDefaults, authenticator: Authenticator) {
        self.store = store
        self.authenticator = authenticator
        let enabled = store.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        isLocked = enabled // locked on launch
    }

    var methodName: String { authenticator.methodName }

    /// Called when the app goes to the background: next time it opens, ask again.
    func lock() {
        if isEnabled { isLocked = true }
    }

    /// Shows the system prompt and unlocks on success.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        let ok = await authenticator.authenticate(reason: "Unlock SpendLite to see your spending.")
        isAuthenticating = false
        if ok { isLocked = false }
    }

    /// Turns the lock on or off, after confirming it's the owner. Returns whether it changed.
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled != isEnabled else { return true }
        guard !enabled || authenticator.isAvailable else { return false }
        let reason = enabled ? "Turn on the SpendLite lock." : "Turn off the SpendLite lock."
        isAuthenticating = true
        let ok = await authenticator.authenticate(reason: reason)
        isAuthenticating = false
        guard ok else { return false }
        isEnabled = enabled
        store.set(enabled, forKey: Self.enabledKey)
        if !enabled { isLocked = false }
        return true
    }
}
