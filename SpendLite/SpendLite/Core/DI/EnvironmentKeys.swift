//
//  EnvironmentKeys.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/5/25.
//

import SwiftUI

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue = AppContainer(inMemory: true) // safe for previews
}

extension EnvironmentValues {
    var container: AppContainer {
        get { self[AppContainerKey.self]}
        set {self[AppContainerKey.self] = newValue }
    }
}
