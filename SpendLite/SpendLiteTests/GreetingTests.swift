//
//  GreetingTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
@testable import SpendLite

struct GreetingTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: hour, minute: minute))!
    }

    @Test(arguments: [
        (0, 0, "Hello"),
        (1, 16, "Hello"),          // the screenshot time that said "Good Evening"
        (4, 59, "Hello"),
        (5, 0, "Good Morning"),
        (11, 59, "Good Morning"),
        (12, 0, "Good Afternoon"),
        (16, 59, "Good Afternoon"),
        (17, 0, "Good Evening"),
        (21, 59, "Good Evening"),
        (22, 0, "Hello"),
    ])
    func greetingForTimeOfDay(hour: Int, minute: Int, expected: String) {
        #expect(Greeting.text(for: at(hour, minute), calendar: calendar) == expected)
    }
}
