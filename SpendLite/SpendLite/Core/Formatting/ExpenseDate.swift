//
//  ExpenseDate.swift
//  SpendLite
//

import Foundation

/// Short, friendly dates for transaction rows:
/// "Today, 9:41 AM" · "Yesterday, 6:05 PM" · "Mon, Nov 3" (this year) · "Dec 28, 2025" (older).
enum ExpenseDate {
    static func label(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        var time = Date.FormatStyle.dateTime.hour().minute()
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time = time.locale(locale)

        if calendar.isDate(date, inSameDayAs: now) {
            return "Today, \(date.formatted(time))"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday, \(date.formatted(time))"
        }

        var style: Date.FormatStyle = calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? .dateTime.weekday(.abbreviated).month(.abbreviated).day()
            : .dateTime.month(.abbreviated).day().year()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style.locale(locale))
    }
}
