//
//  BudgetAlerts.swift
//  SpendLite
//

import Foundation

/// Decides which budget alert (if any) to send. Pure logic, unit tested.
///
/// Rules:
/// - Alert once when spending reaches 80% of the month's budget, and once when it goes over.
/// - Each alert fires at most once per month…
/// - …but if spending drops back below the line (budget raised, expense deleted), crossing
///   it again alerts again.
enum BudgetAlerts {

    enum Level: String, CaseIterable {
        case nearLimit, overBudget
    }

    struct Alert: Equatable {
        let level: Level
        let title: String
        let body: String
    }

    /// Which levels have been alerted this month, e.g. ["nearLimit"] for "2026-11".
    struct SentState: Equatable {
        var month: String
        var levels: Set<Level>
    }

    static func monthKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// Returns the alert to send now (at most one: "over" wins over "near"), and the new state.
    static func evaluate(summary: HomeSummary, now: Date, calendar: Calendar,
                         state: SentState?) -> (alert: Alert?, state: SentState) {
        let month = monthKey(for: now, calendar: calendar)
        var levels = (state?.month == month) ? state!.levels : []

        let reached: Set<Level>
        switch summary.status {
        case .onTrack: reached = []
        case .nearLimit: reached = [.nearLimit]
        case .overBudget: reached = [.nearLimit, .overBudget]
        }
        // Dropped back below a line: allow that alert again later.
        levels.formIntersection(reached)

        let new = reached.subtracting(levels)
        levels.formUnion(new)
        let newState = SentState(month: month, levels: levels)

        var monthName = Date.FormatStyle.dateTime.month(.wide)
        monthName.calendar = calendar
        monthName.timeZone = calendar.timeZone
        let name = now.formatted(monthName)

        if new.contains(.overBudget) {
            return (Alert(level: .overBudget,
                          title: "You're over your \(name) budget",
                          body: "\(summary.amountOver.asCurrency()) over your \(summary.monthlyBudget.asCurrency()) budget."),
                    newState)
        }
        if new.contains(.nearLimit) {
            return (Alert(level: .nearLimit,
                          title: "\(summary.percentSpentLabel) of your \(name) budget used",
                          body: "You have \(summary.remaining.asCurrency()) left of \(summary.monthlyBudget.asCurrency())."),
                    newState)
        }
        return (nil, newState)
    }
}

/// Plans the daily "log your spending" reminders: the next 7 evenings at the chosen time,
/// skipping today if something was already logged today (or the time has passed).
enum DailyReminders {
    static let count = 7
    static func id(_ index: Int) -> String { "dailyReminder.\(index)" }
    static var allIDs: [String] { (0..<count).map(id) }

    static func dates(now: Date, hour: Int, minute: Int, loggedToday: Bool, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0...count).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let at = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }
            if offset == 0 && (loggedToday || at <= now) { return nil }
            return at
        }
        .prefix(count)
        .map { $0 }
    }

    static let title = "Did you log today's spending?"
    static let body = "Takes a few seconds. Open SpendLite or ask Siri to add an expense."
}
