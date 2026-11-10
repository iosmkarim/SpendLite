//
//  SpendLiteApp.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/4/25.
//

import SwiftUI

@main
struct SpendLiteApp: App {
    /// UI tests launch with this flag so they run on throwaway in-memory data
    /// instead of reading or adding to the real expenses and budget.
    static let uiTestingArgument = "-ui-testing"

    private let container: AppContainer

    @AppStorage(AppSettings.Key.appearance) private var appearance: Appearance = .system

    init() {
        container = AppContainer(
            inMemory: ProcessInfo.processInfo.arguments.contains(SpendLiteApp.uiTestingArgument)
        )
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
