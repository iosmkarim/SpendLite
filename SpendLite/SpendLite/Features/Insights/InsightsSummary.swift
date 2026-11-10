//
//  InsightsSummary.swift
//  SpendLite
//

import Foundation

/// The time range the Insights tab looks at.
enum InsightsPeriod: String, CaseIterable, Identifiable {
    case thisMonth
    case lastMonth
    case last3Months

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisMonth: "This month"
        case .lastMonth: "Last month"
        case .last3Months: "3 months"
        }
    }

    /// How many calendar months the period covers (also how far back the comparison period is).
    var months: Int { self == .last3Months ? 3 : 1 }

    /// The dates covered: `start` inclusive, `end` exclusive.
    /// "This month" and "3 months" run up to `now`, so they're compared fairly with the
    /// same number of days in the previous period (Nov 1–9 vs Oct 1–9, not all of October).
    func interval(now: Date, calendar: Calendar) -> DateInterval {
        let startOfThisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        switch self {
        case .thisMonth:
            return DateInterval(start: startOfThisMonth, end: max(now, startOfThisMonth))
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
            return DateInterval(start: start, end: startOfThisMonth)
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -2, to: startOfThisMonth)!
            return DateInterval(start: start, end: max(now, start))
        }
    }

    /// The period just before, of the same length, used for "↓ 8% vs last month".
    func previousInterval(now: Date, calendar: Calendar) -> DateInterval {
        let current = interval(now: now, calendar: calendar)
        let start = calendar.date(byAdding: .month, value: -months, to: current.start)!
        let end = calendar.date(byAdding: .month, value: -months, to: current.end)!
        return DateInterval(start: start, end: max(end, start))
    }
}

/// Everything the Insights tab shows, worked out from the expense list.
/// Pure data + maths so it can be unit tested without any UI.
struct InsightsSummary: Equatable {

    struct CategoryShare: Equatable, Identifiable {
        let category: ExpenseCategory
        let total: Double
        /// 0...1 share of the period's total.
        let share: Double
        let count: Int
        var id: ExpenseCategory { category }
    }

    /// One bar in the spending chart (a day, or a week for the 3-month view).
    struct TrendPoint: Equatable, Identifiable {
        let start: Date
        let total: Double
        var id: Date { start }
    }

    let period: InsightsPeriod
    let interval: DateInterval
    let total: Double
    let previousTotal: Double
    let transactionCount: Int
    /// Biggest category first.
    let categories: [CategoryShare]
    /// Every day (or week) in the period, including empty ones, so the chart has no gaps.
    let trend: [TrendPoint]
    let trendUnit: Calendar.Component

    var isEmpty: Bool { transactionCount == 0 }

    /// Change vs the previous period (0.25 = 25% more). Nil when there's nothing to compare with.
    var changeFromPrevious: Double? {
        guard previousTotal > 0 else { return nil }
        return (total - previousTotal) / previousTotal
    }

    /// Average spend per day in the period (days so far, for periods that end today).
    func averagePerDay(calendar: Calendar) -> Double {
        let days = max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
        // A period that ends partway through today still counts today.
        let partial = calendar.startOfDay(for: interval.end) != interval.end ? 1 : 0
        return total / Double(days + partial)
    }

    static func make(
        period: InsightsPeriod,
        expenses: [ExpenseItem],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> InsightsSummary {
        let interval = period.interval(now: now, calendar: calendar)
        let previous = period.previousInterval(now: now, calendar: calendar)

        let inPeriod = expenses.filter { $0.date >= interval.start && $0.date < interval.end }
        let total = inPeriod.reduce(0) { $0 + $1.amount }
        let previousTotal = expenses
            .filter { $0.date >= previous.start && $0.date < previous.end }
            .reduce(0) { $0 + $1.amount }

        // Group by category (old names like "Food & Drink" fold into Food).
        let byCategory = Dictionary(grouping: inPeriod, by: \.categoryKind)
        let categories = byCategory
            .map { category, items in
                let sum = items.reduce(0) { $0 + $1.amount }
                return CategoryShare(
                    category: category,
                    total: sum,
                    share: total > 0 ? sum / total : 0,
                    count: items.count
                )
            }
            .sorted { ($0.total, $1.category.name) > ($1.total, $0.category.name) }

        let unit: Calendar.Component = period == .last3Months ? .weekOfYear : .day
        let trend = makeTrend(inPeriod, interval: interval, unit: unit, calendar: calendar)

        return InsightsSummary(
            period: period,
            interval: interval,
            total: total,
            previousTotal: previousTotal,
            transactionCount: inPeriod.count,
            categories: categories,
            trend: trend,
            trendUnit: unit
        )
    }

    private static func makeTrend(
        _ items: [ExpenseItem],
        interval: DateInterval,
        unit: Calendar.Component,
        calendar: Calendar
    ) -> [TrendPoint] {
        func bucketStart(_ date: Date) -> Date {
            calendar.dateInterval(of: unit, for: date)?.start ?? calendar.startOfDay(for: date)
        }

        var totals: [Date: Double] = [:]
        for item in items {
            totals[bucketStart(item.date), default: 0] += item.amount
        }

        // Zero-fill every bucket from the start of the period to its end.
        var points: [TrendPoint] = []
        var cursor = bucketStart(interval.start)
        while cursor < interval.end {
            points.append(TrendPoint(start: cursor, total: totals[cursor] ?? 0))
            guard let next = calendar.date(byAdding: unit, value: 1, to: cursor) else { break }
            cursor = next
        }
        return points
    }
}
