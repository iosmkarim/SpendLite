//
//  Greeting.swift
//  SpendLite
//

import Foundation

/// Time-of-day greeting for the Home header.
enum Greeting {
    /// 5–11 morning, 12–16 afternoon, 17–21 evening, 22–4 a neutral "Hello"
    /// (saying "Good Evening" at 1 AM, or "Good Night" as a hello, both read oddly).
    static func text(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Hello"
        }
    }
}
