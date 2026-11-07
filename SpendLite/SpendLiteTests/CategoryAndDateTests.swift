//
//  CategoryAndDateTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
@testable import SpendLite

struct CategoryTests {

    @Test(arguments: ExpenseCategory.allCases)
    func storedNameRoundTrips(category: ExpenseCategory) {
        #expect(ExpenseCategory(storedName: category.rawValue) == category)
    }

    @Test func legacyNamesMapToCurrentCategories() {
        #expect(ExpenseCategory(storedName: "Food & Drink") == .food)  // old sample data
        #expect(ExpenseCategory(storedName: "Food & Dining") == .food)
        #expect(ExpenseCategory(storedName: "Transportation") == .transport)
        #expect(ExpenseCategory(storedName: "Entertainment") == .fun)
    }

    @Test func unknownNameFallsBackToOther() {
        #expect(ExpenseCategory(storedName: "Crypto") == .other)
        #expect(ExpenseCategory(storedName: "") == .other)
    }
}

struct ExpenseDateTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
    private let us = Locale(identifier: "en_US")

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private var now: Date { date(2026, 11, 7, 13, 0) }

    private func label(_ d: Date) -> String {
        // Normalise the narrow no-break space iOS uses before AM/PM.
        ExpenseDate.label(for: d, now: now, calendar: calendar, locale: us)
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test func today() {
        #expect(label(date(2026, 11, 7, 9, 41)) == "Today, 9:41 AM")
    }

    @Test func yesterday() {
        #expect(label(date(2026, 11, 6, 18, 5)) == "Yesterday, 6:05 PM")
    }

    @Test func earlierThisYear() {
        #expect(label(date(2026, 11, 3, 12)) == "Tue, Nov 3")
    }

    @Test func previousYearIncludesYear() {
        #expect(label(date(2025, 12, 28, 12)) == "Dec 28, 2025")
    }
}
