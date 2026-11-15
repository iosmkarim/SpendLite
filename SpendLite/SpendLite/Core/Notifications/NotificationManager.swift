//
//  NotificationManager.swift
//  SpendLite
//

import Foundation
import Combine

/// Budget alerts (80% / over) and the optional daily reminder.
/// Watches expenses and the budget, so alerts fire whatever added the expense
/// (the app, Siri, or a recurring expense).
final class NotificationManager: ObservableObject {

    enum Key {
        static let budgetAlerts = "notify.budgetAlerts"
        static let dailyReminder = "notify.dailyReminder"
        static let reminderHour = "notify.reminderHour"
        static let reminderMinute = "notify.reminderMinute"
        static let alertState = "notify.alertState"
    }

    @Published private(set) var budgetAlertsEnabled: Bool
    @Published private(set) var dailyReminderEnabled: Bool
    @Published private(set) var reminderHour: Int
    @Published private(set) var reminderMinute: Int
    /// True when iOS Settings has notifications turned off for SpendLite.
    @Published private(set) var permissionDenied = false

    let scheduler: NotificationScheduler
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar
    private var latest: (expenses: [ExpenseItem], budget: Double)?
    private var cancellables = Set<AnyCancellable>()

    init(
        expenses: ExpenseRepository,
        budget: BudgetRepository,
        defaults: UserDefaults,
        scheduler: NotificationScheduler,
        now: @escaping () -> Date = { .now },
        calendar: Calendar = .current,
        debounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300)
    ) {
        self.defaults = defaults
        self.scheduler = scheduler
        self.now = now
        self.calendar = calendar
        budgetAlertsEnabled = defaults.bool(forKey: Key.budgetAlerts)
        dailyReminderEnabled = defaults.bool(forKey: Key.dailyReminder)
        reminderHour = defaults.object(forKey: Key.reminderHour) as? Int ?? 20
        reminderMinute = defaults.object(forKey: Key.reminderMinute) as? Int ?? 0

        expenses.expensesPublisher
            .combineLatest(budget.monthlyBudgetPublisher)
            .debounce(for: debounce, scheduler: DispatchQueue.main)
            .sink { [weak self] items, budget in
                self?.latest = (items, budget)
                Task { await self?.update() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Settings

    /// Turns budget alerts on (asking for permission first) or off. Returns the resulting state.
    @discardableResult
    func setBudgetAlerts(_ enabled: Bool) async -> Bool {
        if enabled, !(await askPermission()) { return false }
        budgetAlertsEnabled = enabled
        defaults.set(enabled, forKey: Key.budgetAlerts)
        // Start fresh: what was (or wasn't) sent while alerts were off shouldn't carry over.
        defaults.removeObject(forKey: Key.alertState)
        await update()
        return enabled
    }

    @discardableResult
    func setDailyReminder(_ enabled: Bool) async -> Bool {
        if enabled, !(await askPermission()) { return false }
        dailyReminderEnabled = enabled
        defaults.set(enabled, forKey: Key.dailyReminder)
        await rescheduleReminders()
        return enabled
    }

    func setReminderTime(hour: Int, minute: Int) async {
        reminderHour = hour
        reminderMinute = minute
        defaults.set(hour, forKey: Key.reminderHour)
        defaults.set(minute, forKey: Key.reminderMinute)
        await rescheduleReminders()
    }

    /// Re-checks iOS Settings (e.g. after coming back from it).
    func refreshPermission() async {
        permissionDenied = await scheduler.isDenied()
    }

    private func askPermission() async -> Bool {
        let granted = await scheduler.requestAuthorization()
        permissionDenied = !granted
        return granted
    }

    // MARK: - Work

    /// Sends a budget alert if one is due, and keeps the reminders scheduled.
    func update() async {
        await checkBudget()
        await rescheduleReminders()
    }

    private func checkBudget() async {
        guard budgetAlertsEnabled, let latest else { return }
        let date = now()
        let summary = HomeSummary.forMonth(containing: date, expenses: latest.expenses,
                                           monthlyBudget: latest.budget, calendar: calendar)
        let (alert, state) = BudgetAlerts.evaluate(summary: summary, now: date, calendar: calendar, state: loadState())
        saveState(state)
        if let alert {
            await scheduler.schedule(id: "budgetAlert.\(alert.level.rawValue)", title: alert.title, body: alert.body, at: nil)
        }
    }

    private func rescheduleReminders() async {
        await scheduler.cancel(ids: DailyReminders.allIDs)
        guard dailyReminderEnabled else { return }
        let date = now()
        let loggedToday = latest?.expenses.contains { calendar.isDate($0.date, inSameDayAs: date) } ?? false
        let dates = DailyReminders.dates(now: date, hour: reminderHour, minute: reminderMinute,
                                         loggedToday: loggedToday, calendar: calendar)
        for (index, at) in dates.enumerated() {
            await scheduler.schedule(id: DailyReminders.id(index), title: DailyReminders.title,
                                     body: DailyReminders.body, at: at)
        }
    }

    // MARK: - Alert state ("2026-11|nearLimit,overBudget")

    private func loadState() -> BudgetAlerts.SentState? {
        guard let raw = defaults.string(forKey: Key.alertState) else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard let month = parts.first else { return nil }
        let levels = parts.count > 1
            ? Set(parts[1].split(separator: ",").compactMap { BudgetAlerts.Level(rawValue: String($0)) })
            : []
        return BudgetAlerts.SentState(month: String(month), levels: levels)
    }

    private func saveState(_ state: BudgetAlerts.SentState) {
        let levels = state.levels.map(\.rawValue).sorted().joined(separator: ",")
        defaults.set("\(state.month)|\(levels)", forKey: Key.alertState)
    }
}
