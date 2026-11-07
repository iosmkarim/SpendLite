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
    /// The user's currency code (e.g. "USD", "EUR"); falls back to USD.
    static var code: String {
        Locale.current.currency?.identifier ?? "USD"
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
