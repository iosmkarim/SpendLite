//
//  AppLockTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
@testable import SpendLite

@MainActor
struct AppLockTests {

    private func freshStore() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    /// Counts prompts so tests can check we don't ask more than needed.
    final class CountingAuthenticator: Authenticator {
        var succeeds: Bool
        var isAvailable: Bool
        var prompts = 0
        let methodName = "Face ID"
        let systemImage = "faceid"

        init(succeeds: Bool, isAvailable: Bool = true) {
            self.succeeds = succeeds
            self.isAvailable = isAvailable
        }

        func authenticate(reason: String) async -> Bool {
            prompts += 1
            return succeeds
        }
    }

    @Test func offByDefaultAndNeverLocks() {
        let lock = AppLock(store: freshStore(), authenticator: CountingAuthenticator(succeeds: true))
        #expect(!lock.isEnabled)
        #expect(!lock.isLocked)
        lock.lock() // going to the background does nothing when off
        #expect(!lock.isLocked)
    }

    @Test func turningOnAsksFirstAndIsRemembered() async {
        let store = freshStore()
        let auth = CountingAuthenticator(succeeds: true)
        let lock = AppLock(store: store, authenticator: auth)

        #expect(await lock.setEnabled(true))
        #expect(lock.isEnabled)
        #expect(auth.prompts == 1)
        #expect(!lock.isLocked) // turning it on doesn't lock you out right away

        // Next launch starts locked.
        let relaunched = AppLock(store: store, authenticator: auth)
        #expect(relaunched.isEnabled)
        #expect(relaunched.isLocked)
    }

    @Test func failedCheckLeavesTheSettingAlone() async {
        let lock = AppLock(store: freshStore(), authenticator: CountingAuthenticator(succeeds: false))
        #expect(await lock.setEnabled(true) == false)
        #expect(!lock.isEnabled)
    }

    @Test func cantTurnOnWithoutAPasscode() async {
        let auth = CountingAuthenticator(succeeds: true, isAvailable: false)
        let lock = AppLock(store: freshStore(), authenticator: auth)
        #expect(await lock.setEnabled(true) == false)
        #expect(auth.prompts == 0) // no pointless prompt
    }

    @Test func backgroundLocksAndUnlockNeedsSuccess() async {
        let store = freshStore()
        store.set(true, forKey: AppLock.enabledKey)
        let auth = CountingAuthenticator(succeeds: false)
        let lock = AppLock(store: store, authenticator: auth)
        #expect(lock.isLocked)

        await lock.unlock()
        #expect(lock.isLocked) // wrong face / cancelled: stays locked

        auth.succeeds = true
        await lock.unlock()
        #expect(!lock.isLocked)

        lock.lock()
        #expect(lock.isLocked)
    }

    @Test func unlockDoesNothingWhenAlreadyUnlocked() async {
        let auth = CountingAuthenticator(succeeds: true)
        let lock = AppLock(store: freshStore(), authenticator: auth)
        await lock.unlock()
        #expect(auth.prompts == 0)
    }

    @Test func turningOffAsksAndUnlocks() async {
        let store = freshStore()
        store.set(true, forKey: AppLock.enabledKey)
        let auth = CountingAuthenticator(succeeds: true)
        let lock = AppLock(store: store, authenticator: auth)

        #expect(await lock.setEnabled(false))
        #expect(!lock.isEnabled)
        #expect(!lock.isLocked)
        #expect(store.bool(forKey: AppLock.enabledKey) == false)
    }
}
