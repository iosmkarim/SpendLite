//
//  SpendLiteApp.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/4/25.
//

import SwiftUI
import AppIntents

@main
struct SpendLiteApp: App {
    /// UI tests launch with this flag so they run on throwaway in-memory data
    /// instead of reading or adding to the real expenses and budget.
    static let uiTestingArgument = "-ui-testing"
    /// UI tests only: start with the lock turned on, and make Face ID succeed or fail.
    static let lockEnabledArgument = "-ui-testing-lock-enabled"
    static let authFailsArgument = "-ui-testing-auth-fails"

    private let container: AppContainer

    @AppStorage(AppSettings.Key.appearance) private var appearance: Appearance = .system

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let uiTesting = arguments.contains(SpendLiteApp.uiTestingArgument)
        if uiTesting {
            // A fake Face ID that answers instantly, so tests never wait for a real face.
            let fake = FakeAuthenticator(succeeds: !arguments.contains(SpendLiteApp.authFailsArgument))
            let defaults = UserDefaults(suiteName: "SpendLite.uiTesting.\(UUID().uuidString)") ?? .standard
            if arguments.contains(SpendLiteApp.lockEnabledArgument) {
                defaults.set(true, forKey: AppLock.enabledKey)
            }
            container = AppContainer(inMemory: true, authenticator: fake, defaults: defaults)
        } else {
            container = .live
            // Lets Siri learn phrases with a category in them ("Add a Food expense in SpendLite").
            SpendLiteShortcuts.updateAppShortcutParameters()
        }
        // Preferences (currency, appearance) come from the container's store,
        // so UI tests never change the real settings.
        AppSettings.store = container.defaults
        _appearance = AppStorage(wrappedValue: .system, AppSettings.Key.appearance, store: container.defaults)
    }

    var body: some Scene {
        WindowGroup {
            TabShellView()
                .environment(\.container, container)
                .defaultAppStorage(container.defaults)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
