//
//  WidgetSync.swift
//  SpendLite
//

import Foundation
import Combine
import WidgetKit

/// Keeps the Home Screen widget up to date: whenever expenses or the budget change, writes a
/// small `WidgetSnapshot` to the shared App Group and asks WidgetKit to reload the widget.
final class WidgetSync {

    private let defaults: UserDefaults?
    private let now: () -> Date
    private let calendar: Calendar
    private let reloadWidget: () -> Void
    private var latest: (expenses: [ExpenseItem], budget: Double)?
    private var cancellables = Set<AnyCancellable>()

    init(
        expenses: ExpenseRepository,
        budget: BudgetRepository,
        defaults: UserDefaults? = WidgetSnapshotStore.defaults,
        now: @escaping () -> Date = { .now },
        calendar: Calendar = .current,
        debounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
        reloadWidget: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.widgetKind) }
    ) {
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        self.reloadWidget = reloadWidget

        expenses.expensesPublisher
            .combineLatest(budget.monthlyBudgetPublisher)
            // Several saves in a row (e.g. recurring catch-up) cause one widget reload, not many.
            .debounce(for: debounce, scheduler: DispatchQueue.main)
            .sink { [weak self] items, budget in
                self?.latest = (items, budget)
                self?.write()
            }
            .store(in: &cancellables)
    }

    /// Re-writes with the current values (e.g. after the currency changes in Settings).
    func refresh() {
        write()
    }

    private func write() {
        guard let latest else { return }
        let snapshot = Self.makeSnapshot(
            expenses: latest.expenses,
            monthlyBudget: latest.budget,
            currencyCode: Currency.code,
            now: now(),
            calendar: calendar
        )
        WidgetSnapshotStore.save(snapshot, to: defaults)
        reloadWidget()
    }

    /// This month's totals plus the three newest expenses.
    static func makeSnapshot(
        expenses: [ExpenseItem],
        monthlyBudget: Double,
        currencyCode: String,
        now: Date,
        calendar: Calendar
    ) -> WidgetSnapshot {
        let summary = HomeSummary.forMonth(containing: now, expenses: expenses, monthlyBudget: monthlyBudget, calendar: calendar)
        let recent = expenses
            .filter { $0.date <= now } // future-dated ones aren't "recent"
            .sorted { $0.date > $1.date }
            .prefix(3)
            .map { WidgetSnapshot.Expense(id: $0.id, title: $0.title, amount: $0.amount, date: $0.date) }

        return WidgetSnapshot(
            monthStart: calendar.dateInterval(of: .month, for: now)?.start ?? now,
            monthlyBudget: monthlyBudget,
            spentThisMonth: summary.totalSpent,
            currencyCode: currencyCode,
            recent: Array(recent),
            updatedAt: now
        )
    }
}
