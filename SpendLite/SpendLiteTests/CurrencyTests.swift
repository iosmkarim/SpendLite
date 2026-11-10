//
//  CurrencyTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
@testable import SpendLite

struct CurrencyTests {

    private let us = Locale(identifier: "en_US")

    @Test func keepsCents() {
        #expect(5.40.asCurrency(code: "USD", locale: us) == "$5.40")
        #expect(1994.60.asCurrency(code: "USD", locale: us) == "$1,994.60")
        #expect(7.25.asCurrency(code: "USD", locale: us) == "$7.25")
    }

    @Test func wholeAndZeroAmounts() {
        #expect(2000.0.asCurrency(code: "USD", locale: us) == "$2,000.00")
        #expect(0.0.asCurrency(code: "USD", locale: us) == "$0.00")
    }

    @Test func negativeAmounts() {
        #expect((-5.40).asCurrency(code: "USD", locale: us) == "-$5.40")
    }

    @Test func decimalMatchesDouble() {
        #expect(Decimal(string: "1250.5")!.asCurrency(code: "USD", locale: us) == "$1,250.50")
    }

    @Test func followsLocaleAndCurrency() {
        let germany = Locale(identifier: "de_DE")
        let result = 1234.5.asCurrency(code: "EUR", locale: germany)
        #expect(result.contains("1.234,50"))
        #expect(result.contains("€"))
    }
}
