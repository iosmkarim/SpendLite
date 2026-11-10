//
//  Currency.swift
//  SpendLite
//

import Foundation

/// One place for money formatting, used by every screen.
///
/// Uses Foundation's `FormatStyle`, which caches its formatter internally,
/// so it's cheap to call during rendering (unlike creating a NumberFormatter each time).
enum Currency {
    /// The currency chosen in Settings, or the device region's currency ("Automatic"); falls back to USD.
    static var code: String {
        code(in: AppSettings.store)
    }

    static func code(in store: UserDefaults, locale: Locale = .current) -> String {
        chosenCode(in: store) ?? automaticCode(for: locale)
    }

    /// The code picked in Settings, or nil when set to Automatic (stored as "" or missing).
    static func chosenCode(in store: UserDefaults) -> String? {
        guard let code = store.string(forKey: AppSettings.Key.currencyCode), !code.isEmpty else { return nil }
        return code
    }

    /// The device region's currency.
    static var automaticCode: String {
        automaticCode(for: .current)
    }

    static func automaticCode(for locale: Locale) -> String {
        locale.currency?.identifier ?? "USD"
    }

    /// Symbol for the current currency, e.g. "$", "€", "৳" (shown next to the amount field).
    static var symbol: String {
        symbol(for: code)
    }

    static func symbol(for code: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    /// "US Dollar", "Bangladeshi Taka".
    static func name(for code: String, locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }

    /// Currencies offered in Settings. The device's own currency is always included.
    static var common: [String] {
        let list = ["USD", "EUR", "GBP", "CAD", "AUD", "NZD", "INR", "BDT", "PKR",
                    "JPY", "CNY", "SGD", "AED", "SAR", "CHF", "SEK"]
        return list.contains(automaticCode) ? list : [automaticCode] + list
    }
}

extension Double {
    /// "$1,994.60" in the user's locale and currency. Always shows cents.
    func asCurrency(code: String = Currency.code, locale: Locale = .current) -> String {
        formatted(.currency(code: code).locale(locale))
    }
}

extension Decimal {
    /// "$1,994.60" in the user's locale and currency. Always shows cents.
    func asCurrency(code: String = Currency.code, locale: Locale = .current) -> String {
        formatted(.currency(code: code).locale(locale))
    }
}
