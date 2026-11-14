//
//  WidgetSnapshot.swift
//  SpendLite (shared by the app and the widget extension)
//

import Foundation

/// What the Home Screen widget shows. The app writes it to the shared App Group whenever
/// expenses or the budget change; the widget only reads it (it never opens the database).
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {

    struct Expense: Codable, Equatable, Sendable, Identifiable {
        var id: UUID
        var title: String
        var amount: Double
        var date: Date
    }

    /// First moment of the month the totals belong to.
    var monthStart: Date
    var monthlyBudget: Double
    var spentThisMonth: Double
    var currencyCode: String
    /// Newest first, at most a few.
    var recent: [Expense]
    var updatedAt: Date

    // MARK: - Derived (same rules as Home's budget card)

    /// The month may have rolled over since the app last wrote this (e.g. the app wasn't opened
    /// on the 1st). Then nothing has been spent in the new month yet as far as we know.
    func spent(asOf now: Date, calendar: Calendar = .current) -> Double {
        calendar.isDate(monthStart, equalTo: now, toGranularity: .month) ? spentThisMonth : 0
    }

    func remaining(asOf now: Date, calendar: Calendar = .current) -> Double {
        monthlyBudget - spent(asOf: now, calendar: calendar)
    }

    /// Share of the budget spent (0...1, capped for the ring).
    func progress(asOf now: Date, calendar: Calendar = .current) -> Double {
        let spent = spent(asOf: now, calendar: calendar)
        guard monthlyBudget > 0 else { return spent > 0 ? 1 : 0 }
        return min(1, max(0, spent / monthlyBudget))
    }

    enum Status: Equatable, Sendable { case onTrack, nearLimit, overBudget }

    func status(asOf now: Date, calendar: Calendar = .current) -> Status {
        let spent = spent(asOf: now, calendar: calendar)
        if spent > monthlyBudget || (monthlyBudget == 0 && spent > 0) { return .overBudget }
        guard monthlyBudget > 0 else { return .onTrack }
        return spent / monthlyBudget >= 0.8 ? .nearLimit : .onTrack
    }

    /// Shown before the app has ever written a snapshot (or in the widget gallery).
    static let placeholder = WidgetSnapshot(
        monthStart: Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now,
        monthlyBudget: 2000,
        spentThisMonth: 742.35,
        currencyCode: Locale.current.currency?.identifier ?? "USD",
        recent: [
            Expense(id: UUID(), title: "Groceries", amount: 62.10, date: .now),
            Expense(id: UUID(), title: "Coffee", amount: 4.75, date: .now.addingTimeInterval(-3600 * 5)),
            Expense(id: UUID(), title: "Uber", amount: 18.20, date: .now.addingTimeInterval(-3600 * 26)),
        ],
        updatedAt: .now
    )
}

/// Reads and writes the snapshot in the App Group shared by the app and the widget.
nonisolated enum WidgetSnapshotStore {
    static let appGroup = "group.com.iosmkarim.SpendLite"
    static let key = "widgetSnapshot"
    /// The widget's `kind`, used to reload just this widget.
    static let widgetKind = "SpendLiteBudgetWidget"

    /// Opens the Add Expense form ("spendlite://add").
    static let addExpenseURL = URL(string: "spendlite://add")!
    /// Opens the app on Home ("spendlite://home").
    static let homeURL = URL(string: "spendlite://home")!

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func load(from defaults: UserDefaults? = defaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = defaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }
}
