//
//  HomeSummaryTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct HomeSummaryTests {

    /// Fixed calendar + time zone so results don't depend on the machine running the tests.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func expense(_ amount: Double, on date: Date) -> ExpenseItem {
        ExpenseItem(id: UUID(), date: date, title: "x", amount: amount, category: "Other")
    }

    // MARK: - HomeSummary.forMonth

    @Test func countsOnlyExpensesInCurrentMonth() {
        let now = date(2026, 11, 15)
        let items = [
            expense(10, on: date(2026, 11, 1, 0, 0, 0)),     // first second of the month ✅
            expense(20, on: date(2026, 11, 30, 23, 59, 59)), // last second of the month ✅
            expense(5,  on: date(2026, 11, 7)),              // ✅
            expense(100, on: date(2026, 10, 31, 23, 59, 59)),// last month ❌
            expense(200, on: date(2026, 12, 1, 0, 0, 0)),    // next month ❌
            expense(300, on: date(2025, 11, 15)),            // same month, last year ❌
        ]

        let summary = HomeSummary.forMonth(containing: now, expenses: items, monthlyBudget: 2000, calendar: calendar)

        #expect(summary.totalSpent == 35)
        #expect(summary.monthlyBudget == 2000)
        #expect(summary.remaining == 1965)
    }

    @Test func noExpensesThisMonthMeansNothingSpent() {
        let now = date(2026, 11, 15)
        let items = [expense(50, on: date(2026, 10, 15))]

        let summary = HomeSummary.forMonth(containing: now, expenses: items, monthlyBudget: 2000, calendar: calendar)

        #expect(summary.totalSpent == 0)
        #expect(summary.remaining == 2000)
    }

    // MARK: - Status (F6)

    @Test(arguments: [
        (spent: 0.0,    status: HomeSummary.Status.onTrack),
        (spent: 799.99, status: .onTrack),
        (spent: 800.0,  status: .nearLimit),   // exactly 80%
        (spent: 1000.0, status: .nearLimit),   // exactly at budget is not "over"
        (spent: 1000.01, status: .overBudget),
    ])
    func statusThresholds(spent: Double, status: HomeSummary.Status) {
        #expect(HomeSummary(monthlyBudget: 1000, totalSpent: spent).status == status)
    }

    @Test func overBudgetAmounts() {
        let summary = HomeSummary(monthlyBudget: 1000, totalSpent: 1250)
        #expect(summary.isOverBudget)
        #expect(summary.amountOver == 250)
        #expect(summary.remaining == -250)
        #expect(summary.remainingClamped == 0)
        #expect(summary.progress == 1.25)
    }

    @Test func withinBudgetHasNothingOver() {
        let summary = HomeSummary(monthlyBudget: 1000, totalSpent: 400)
        #expect(!summary.isOverBudget)
        #expect(summary.amountOver == 0)
        #expect(summary.remainingClamped == 600)
    }

    @Test func zeroBudgetWithSpendingCountsAsOver() {
        let summary = HomeSummary(monthlyBudget: 0, totalSpent: 5)
        #expect(summary.status == .overBudget)
        #expect(summary.progress == 1)
        #expect(HomeSummary(monthlyBudget: 0, totalSpent: 0).status == .onTrack)
    }

    // MARK: - HomeViewModel

    @Test func homeViewModelSummaryIgnoresOlderMonths() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        try await save(expense(40, on: date(2026, 11, 3)), to: repo)
        try await save(expense(999, on: date(2026, 10, 20)), to: repo)

        let vm = HomeViewModel(expenses: repo, budget: freshBudget(), now: { self.date(2026, 11, 15) }, calendar: calendar)

        // The view model applies values on the main queue; wait until the summary arrives.
        let summary = try #require(await firstNonNil(vm.$summary))
        #expect(summary.totalSpent == 40)
        #expect(vm.hasAnyExpense)
        #expect(vm.recentExpenses.count == 2) // recent list is all-time, not just this month
    }

    // MARK: - Budget (F5)

    @Test func budgetDefaultsTo2000AndPersists() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let repo = UserDefaultsBudgetRepository(defaults: defaults)
        var latest: Double?
        let c = repo.monthlyBudgetPublisher.sink { latest = $0 }
        #expect(latest == 2000)

        repo.setMonthlyBudget(3500)
        #expect(latest == 3500)
        // A new repository on the same storage sees the saved value (survives app restarts).
        var reloaded: Double?
        let c2 = UserDefaultsBudgetRepository(defaults: defaults).monthlyBudgetPublisher.sink { reloaded = $0 }
        #expect(reloaded == 3500)

        repo.setMonthlyBudget(-10) // ignored
        #expect(latest == 3500)
        _ = (c, c2)
    }

    @Test func changingBudgetUpdatesHomeSummary() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        try await save(expense(100, on: date(2026, 11, 3)), to: repo)
        let budget = freshBudget()
        let vm = HomeViewModel(expenses: repo, budget: budget, now: { self.date(2026, 11, 15) }, calendar: calendar)

        vm.setMonthlyBudget(500)

        var updated: HomeSummary?
        for await value in vm.$summary.values where value?.monthlyBudget == 500 {
            updated = value
            break
        }
        #expect(updated?.remaining == 400)
    }

    private func freshBudget() -> BudgetRepository {
        UserDefaultsBudgetRepository(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    // MARK: - Helpers

    private func save(_ item: ExpenseItem, to repo: ExpenseRepository) async throws {
        var cancellable: AnyCancellable?
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            cancellable = repo.addExpense(item).sink { completion in
                if case .failure(let error) = completion { cont.resume(throwing: error) }
            } receiveValue: { cont.resume() }
        }
        cancellable?.cancel()
    }

    private func firstNonNil<T>(_ publisher: Published<T?>.Publisher) async -> T? {
        for await value in publisher.values {
            if let value { return value }
        }
        return nil
    }
}
