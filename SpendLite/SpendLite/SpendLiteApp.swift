//
//  SpendLiteApp.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/4/25.
//

import SwiftUI
import CoreData

@main
struct SpendLiteApp: App {
    private let container = AppContainer(inMemory: false) // production

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.container, container)
        }
    }
}
