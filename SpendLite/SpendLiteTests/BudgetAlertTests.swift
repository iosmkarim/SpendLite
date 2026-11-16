//
//  BudgetAlertTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct BudgetAlertTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private var now: Date { date(2026, 11, 14, 15) }

    private func evaluate(spent: Double, state: BudgetAlerts.SentState? = nil, at when: Date? = nil)
        -> (alert: BudgetAlerts.Alert?, state: BudgetAlerts.SentState) {
        BudgetAlerts.evaluate(summary: HomeSummary(monthlyBudget: 1000, totalSpent: spent),
                              now: when ?? now, calendar: calendar, state: state)
    }

    // MARK: - Budget alert rules

    @Test func nothingWhileOnTrack() {
        let result = evaluate(spent: 500)
        #expect(result.alert == nil)
        #expect(result.state == .init(month: "2026-11", levels: []))
    }

    @Test func alertsAt80Percent() {
        let result = evaluate(spent: 820)
        #expect(result.alert?.level == .nearLimit)
        #expect(result.alert?.title == "82% of your November budget used")
        #expect(result.alert?.body == "You have \(180.0.asCurrency()) left of \(1000.0.asCurrency()).")
    }

    @Test func nearLimitOnlyOncePerMonth() {
        let first = evaluate(spent: 820)
        let second = evaluate(spent: 900, state: first.state)
        #expect(second.alert == nil)
    }

    @Test func thenOverBudget() {
        let near = evaluate(spent: 820)
        let over = evaluate(spent: 1080, state: near.state)
        #expect(over.alert?.level == .overBudget)
        #expect(over.alert?.title == "You're over your November budget")
        #expect(over.alert?.body == "\(80.0.asCurrency()) over your \(1000.0.asCurrency()) budget.")
        #expect(evaluate(spent: 1200, state: over.state).alert == nil)
    }

    @Test func jumpingStraightOverSendsOnlyTheOverAlert() {
        let result = evaluate(spent: 1500)
        #expect(result.alert?.level == .overBudget)
        #expect(result.state.levels == [.nearLimit, .overBudget]) // no "80%" alert afterwards
        #expect(evaluate(spent: 1500, state: result.state).alert == nil)
    }

    @Test func droppingBelowTheLineAllowsAnotherAlert() {
        let near = evaluate(spent: 850)
        let back = evaluate(spent: 600, state: near.state) // budget raised / expense deleted
        #expect(back.alert == nil)
        #expect(back.state.levels.isEmpty)
        #expect(evaluate(spent: 850, state: back.state).alert?.level == .nearLimit)
    }

    @Test func newMonthStartsFresh() {
        let october = BudgetAlerts.SentState(month: "2026-10", levels: [.nearLimit, .overBudget])
        #expect(evaluate(spent: 850, state: october).alert?.level == .nearLimit)
    }

    // MARK: - Daily reminders

    @Test func remindersForTheNextSevenEvenings() {
        let dates = DailyReminders.dates(now: date(2026, 11, 14, 15), hour: 20, minute: 0, loggedToday: false, calendar: calendar)
        #expect(dates.count == 7)
        #expect(dates.first == date(2026, 11, 14, 20))   // tonight
        #expect(dates.last == date(2026, 11, 20, 20))
    }

    @Test func skipsTonightIfAlreadyLogged() {
        let dates = DailyReminders.dates(now: date(2026, 11, 14, 15), hour: 20, minute: 0, loggedToday: true, calendar: calendar)
        #expect(dates.count == 7)
        #expect(dates.first == date(2026, 11, 15, 20))
    }

    @Test func skipsTonightIfTheTimeHasPassed() {
        let dates = DailyReminders.dates(now: date(2026, 11, 14, 21), hour: 20, minute: 30, loggedToday: false, calendar: calendar)
        #expect(dates.first == date(2026, 11, 15, 20, 30))
    }

    // MARK: - Manager

    private func makeManager(budget: Double = 1000, granted: Bool = true)
        -> (NotificationManager, FakeNotificationScheduler, CoreDataExpenseRepository, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let expenses = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        let budgetRepo = UserDefaultsBudgetRepository(defaults: defaults)
        budgetRepo.setMonthlyBudget(budget)
        let scheduler = FakeNotificationScheduler(grantsPermission: granted)
        let manager = NotificationManager(expenses: expenses, budget: budgetRepo, defaults: defaults,
                                          scheduler: scheduler, now: { self.now }, calendar: calendar,
                                          debounce: .milliseconds(1))
        return (manager, scheduler, expenses, defaults)
    }

    private func add(_ amount: Double, to repo: CoreDataExpenseRepository, on day: Date? = nil) async throws {
        let item = ExpenseItem(id: UUID(), date: day ?? date(2026, 11, 10), title: "x", amount: amount, category: "Food")
        try await repo.addExpense(item).firstValue()
    }

    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(condition(), "Timed out waiting for condition")
    }

    @Test func offByDefault() async throws {
        let (manager, scheduler, expenses, _) = makeManager()
        #expect(!manager.budgetAlertsEnabled)
        #expect(!manager.dailyReminderEnabled)
        try await add(950, to: expenses)
        try await Task.sleep(for: .milliseconds(100))
        #expect(scheduler.sent.isEmpty)
        #expect(scheduler.pending.isEmpty)
    }

    @Test func alertFiresWhenAnExpenseCrossesTheLine() async throws {
        let (manager, scheduler, expenses, _) = makeManager()
        #expect(await manager.setBudgetAlerts(true))

        try await add(500, to: expenses)
        try await Task.sleep(for: .milliseconds(100))
        #expect(scheduler.sent.isEmpty)

        try await add(350, to: expenses) // 85%
        await waitUntil { scheduler.sent.count == 1 }
        #expect(scheduler.sent.first?.id == "budgetAlert.nearLimit")

        try await add(200, to: expenses) // 105%
        await waitUntil { scheduler.sent.count == 2 }
        #expect(scheduler.sent.last?.id == "budgetAlert.overBudget")
    }

    @Test func turningAlertsOffAndOnStartsFresh() async throws {
        let (manager, scheduler, expenses, _) = makeManager()
        await manager.setBudgetAlerts(true)
        try await add(850, to: expenses)
        await waitUntil { scheduler.sent.count == 1 }

        await manager.setBudgetAlerts(false)
        await manager.setBudgetAlerts(true) // still at 85%: tell them again
        await waitUntil { scheduler.sent.count == 2 }
        #expect(scheduler.sent.last?.id == "budgetAlert.nearLimit")
    }

    @Test func deniedPermissionKeepsItOff() async {
        let (manager, _, _, defaults) = makeManager(granted: false)
        #expect(await manager.setBudgetAlerts(true) == false)
        #expect(!manager.budgetAlertsEnabled)
        #expect(manager.permissionDenied)
        #expect(defaults.bool(forKey: NotificationManager.Key.budgetAlerts) == false)
    }

    @Test func reminderScheduledAndSkipsTodayAfterLogging() async throws {
        let (manager, scheduler, expenses, _) = makeManager()
        #expect(await manager.setDailyReminder(true))
        #expect(scheduler.pending.count == 7)
        #expect(scheduler.pending[DailyReminders.id(0)]?.date == date(2026, 11, 14, 20))

        try await add(5, to: expenses, on: date(2026, 11, 14, 9)) // logged today
        await waitUntil { scheduler.pending[DailyReminders.id(0)]?.date == date(2026, 11, 15, 20) }

        await manager.setReminderTime(hour: 21, minute: 15)
        #expect(scheduler.pending[DailyReminders.id(0)]?.date == date(2026, 11, 15, 21, 15))

        await manager.setDailyReminder(false)
        #expect(scheduler.pending.isEmpty)
    }

    @Test func settingsAreRemembered() async {
        let (manager, _, _, defaults) = makeManager()
        await manager.setBudgetAlerts(true)
        await manager.setReminderTime(hour: 7, minute: 30)

        let reloaded = NotificationManager(expenses: CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true)),
                                           budget: UserDefaultsBudgetRepository(defaults: defaults), defaults: defaults,
                                           scheduler: FakeNotificationScheduler())
        #expect(reloaded.budgetAlertsEnabled)
        #expect(reloaded.reminderHour == 7)
        #expect(reloaded.reminderMinute == 30)
    }
}
