//
//  RecurringExpense.swift
//  SpendLite
//

import Foundation

/// A repeating expense (rent, subscriptions, phone bill). The app turns each due
/// occurrence into a normal `ExpenseItem` (with `recurringID` set) when it opens.
struct RecurringExpense: Identifiable, Equatable {

    enum Frequency: String, CaseIterable, Identifiable {
        case weekly, monthly, yearly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .weekly: "Weekly"
            case .monthly: "Monthly"
            case .yearly: "Yearly"
            }
        }

        /// Roughly how many times per month (for "≈ $X per month").
        var perMonth: Double {
            switch self {
            case .weekly: 52.0 / 12.0
            case .monthly: 1
            case .yearly: 1.0 / 12.0
            }
        }

        fileprivate var component: (Calendar.Component, Int) {
            switch self {
            case .weekly: (.day, 7)
            case .monthly: (.month, 1)
            case .yearly: (.year, 1)
            }
        }
    }

    let id: UUID
    var title: String
    var amount: Double
    var category: String
    var frequency: Frequency
    /// Date of the first occurrence; every later one is counted from it.
    var startDate: Date
    /// How many occurrences have already been turned into expenses.
    var occurrencesGenerated: Int
    var isPaused: Bool

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: String,
        frequency: Frequency,
        startDate: Date,
        occurrencesGenerated: Int = 0,
        isPaused: Bool = false
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.frequency = frequency
        self.startDate = startDate
        self.occurrencesGenerated = occurrencesGenerated
        self.isPaused = isPaused
    }

    var categoryKind: ExpenseCategory { ExpenseCategory(storedName: category) }

    var monthlyEquivalent: Double { amount * frequency.perMonth }

    /// The date of occurrence `index` (0 = start date).
    /// Always counted from the start date, so a rule starting Jan 31 gives Feb 28, then Mar 31
    /// (not Mar 28, which stepping month by month would drift to).
    func date(ofOccurrence index: Int, calendar: Calendar) -> Date {
        let (component, step) = frequency.component
        return calendar.date(byAdding: component, value: step * index, to: startDate) ?? startDate
    }

    /// When the next expense will be added.
    func nextDate(calendar: Calendar) -> Date {
        date(ofOccurrence: occurrencesGenerated, calendar: calendar)
    }

    /// Occurrences that are due (on or before `now`) but not yet added, oldest first.
    /// Paused rules have none. `limit` guards against a runaway catch-up.
    func dueOccurrences(now: Date, calendar: Calendar, limit: Int = 400) -> [Date] {
        guard !isPaused else { return [] }
        var dates: [Date] = []
        var index = occurrencesGenerated
        while dates.count < limit {
            let date = date(ofOccurrence: index, calendar: calendar)
            guard date <= now else { break }
            dates.append(date)
            index += 1
        }
        return dates
    }

    /// Resuming after a pause skips the occurrences that fell inside the pause
    /// (you didn't pay rent you'd paused), continuing from the next one after `now`.
    func resumed(now: Date, calendar: Calendar) -> RecurringExpense {
        var copy = self
        copy.isPaused = false
        while copy.date(ofOccurrence: copy.occurrencesGenerated, calendar: calendar) < calendar.startOfDay(for: now) {
            copy.occurrencesGenerated += 1
        }
        return copy
    }
}
