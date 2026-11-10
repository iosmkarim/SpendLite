//
//  AppSettings.swift
//  SpendLite
//

import SwiftUI

/// User preferences (currency, appearance) stored in UserDefaults.
///
/// `store` is the UserDefaults the whole app reads them from. It's `.standard` normally;
/// UI tests and previews swap in a throwaway suite (see `AppContainer`) so they never change
/// the real settings. Views read the same store through `.defaultAppStorage`.
enum AppSettings {
    nonisolated(unsafe) static var store: UserDefaults = .standard

    enum Key {
        /// ISO currency code, or missing for "Automatic" (follow the device region).
        static let currencyCode = "currencyCode"
        static let appearance = "appearance"
    }
}

/// Light / Dark / follow the system.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil = follow the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
