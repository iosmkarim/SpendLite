//
//  InsightsViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Recomputes the Insights summary whenever expenses or the selected period change.
final class InsightsViewModel: ObservableObject {

    @Published var period: InsightsPeriod = .thisMonth
    @Published private(set) var summary: InsightsSummary?

    private let now: () -> Date
    private let calendar: Calendar
    private let refreshTrigger = CurrentValueSubject<Void, Never>(())
    private var cancellables = Set<AnyCancellable>()

    init(expenses: ExpenseRepository, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.now = now
        self.calendar = calendar

        expenses.expensesPublisher
            .combineLatest($period, refreshTrigger)
            .map { items, period, _ in
                InsightsSummary.make(period: period, expenses: items, now: now(), calendar: calendar)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.summary = $0 }
            .store(in: &cancellables)
    }

    /// Recalculate with the current time (e.g. when the tab reappears on a new day).
    func refresh() {
        refreshTrigger.send(())
    }

    // MARK: - Labels

    /// "Nov 1 – 9", "October", "Sep 1 – Nov 9".
    var periodLabel: String {
        guard let summary else { return "" }
        return Self.label(for: summary.interval, period: summary.period, calendar: calendar)
    }

    /// The previous period, e.g. "Oct 1 – 9" (same days last month), "September".
    var comparisonLabel: String {
        guard let summary else { return "" }
        let previous = summary.period.previousInterval(now: now(), calendar: calendar)
        return Self.label(for: previous, period: summary.period, calendar: calendar)
    }

    var averagePerDay: Double {
        summary?.averagePerDay(calendar: calendar) ?? 0
    }

    static func label(for interval: DateInterval, period: InsightsPeriod, calendar: Calendar, locale: Locale = .current) -> String {
        // `end` is exclusive; show the last day actually included.
        let lastDay = max(interval.start, interval.end.addingTimeInterval(-1))

        // A whole calendar month reads better as just its name.
        if period == .lastMonth {
            var style = Date.FormatStyle.dateTime.month(.wide).locale(locale)
            style.calendar = calendar
            style.timeZone = calendar.timeZone
            return interval.start.formatted(style)
        }

        var style = Date.IntervalFormatStyle.interval.month(.abbreviated).day().locale(locale)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return (interval.start..<lastDay).formatted(style)
    }
}
