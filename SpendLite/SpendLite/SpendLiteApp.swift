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

    private let container = AppContainer(
        inMemory: ProcessInfo.processInfo.arguments.contains(SpendLiteApp.uiTestingArgument)
    )

    var body: some Scene {
        WindowGroup {
            TabShellView()
                .environment(\.container, container)
        }
    }
}
