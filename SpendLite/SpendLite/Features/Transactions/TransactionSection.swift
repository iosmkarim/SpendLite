//
//  TransactionSection.swift
//  SpendLite
//

import Foundation

/// One month of expenses in the Transactions list, e.g. "November 2026 · $412.60".
struct TransactionSection: Identifiable, Equatable {
    /// The first moment of the month; also used as a stable id.
    let monthStart: Date
    let title: String
    let total: Double
    let items: [ExpenseItem]

    var id: Date { monthStart }

    /// Groups expenses by calendar month, newest month first and newest expense first within a month.
    static func byMonth(
        _ expenses: [ExpenseItem],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [TransactionSection] {
        let grouped = Dictionary(grouping: expenses) { item in
            calendar.dateInterval(of: .month, for: item.date)?.start ?? item.date
        }

        var style = Date.FormatStyle.dateTime.month(.wide).year().locale(locale)
        style.calendar = calendar
        style.timeZone = calendar.timeZone

        return grouped
            .map { monthStart, items in
                TransactionSection(
                    monthStart: monthStart,
                    title: monthStart.formatted(style),
                    total: items.reduce(0) { $0 + $1.amount },
                    items: items.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.monthStart > $1.monthStart }
    }
}
