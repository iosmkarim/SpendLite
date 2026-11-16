//
//  CategoryBudgetTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
@testable import SpendLite

@MainActor
struct CategoryBudgetTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private var now: Date { date(2026, 11, 14) }

    private func item(_ amount: Double, _ category: String, on day: Date? = nil) -> ExpenseItem {
        ExpenseItem(id: UUID(), date: day ?? date(2026, 11, 5), title: category, amount: amount, category: category)
    }

    private func freshDefaults() -> UserDefaults { UserDefaults(suiteName: "test.\(UUID().uuidString)")! }

    // MARK: - Storage

    @Test func limitsAreSavedAndRemoved() async {
        let defaults = freshDefaults()
        let repo = UserDefaultsCategoryBudgetRepository(defaults: defaults)
        #expect(await repo.limitsPublisher.firstValue().isEmpty)

        repo.setLimit(400, for: .food)
        repo.setLimit(150, for: .fun)
        #expect(await repo.limitsPublisher.firstValue() == [.food: 400, .fun: 150])

        // Survives a restart.
        let reloaded = UserDefaultsCategoryBudgetRepository(defaults: defaults)
        #expect(await reloaded.limitsPublisher.firstValue() == [.food: 400, .fun: 150])

        repo.setLimit(nil, for: .fun)
        repo.setLimit(0, for: .food)  // zero means "no limit"
        #expect(await repo.limitsPublisher.firstValue().isEmpty)
    }

    @Test func invalidAmountsRemoveTheLimit() async {
        let repo = UserDefaultsCategoryBudgetRepository(defaults: freshDefaults())
        repo.setLimit(400, for: .food)
        repo.setLimit(-5, for: .food)
        #expect(await repo.limitsPublisher.firstValue()[.food] == nil)
        repo.setLimit(.infinity, for: .food)
        #expect(await repo.limitsPublisher.firstValue()[.food] == nil)
    }

    // MARK: - Rows

    @Test func rowsCountOnlyThisMonthAndCompareWithTheLimit() {
        let expenses = [
            item(120, "Food"), item(80, "Food"),
            item(60, "Fun"),
            item(500, "Food", on: date(2026, 10, 20)),   // last month: ignored
            item(30, "Food & Drink"),                     // old name → Food
        ]
        let rows = CategoryBudgetSummary.rows(expenses: expenses, limits: [.food: 400, .fun: 50],
                                              now: now, calendar: calendar)
        let food = rows.first { $0.category == .food }!
        let fun = rows.first { $0.category == .fun }!

        #expect(food.spent == 230)
        #expect(food.remaining == 170)
        #expect(food.status == .onTrack)
        #expect(food.statusLabel == "\(170.0.asCurrency()) left")

        #expect(fun.status == .overBudget)
        #expect(fun.progress == 1)        // capped for the bar
        #expect(fun.statusLabel == "\(10.0.asCurrency()) over")

        #expect(rows.count == ExpenseCategory.allCases.count) // every category listed
    }

    @Test func limitedCategoriesFirstMostUsedFirst() {
        let expenses = [item(45, "Fun"), item(100, "Food"), item(300, "Shopping")]
        let rows = CategoryBudgetSummary.rows(expenses: expenses, limits: [.food: 400, .fun: 50],
                                              now: now, calendar: calendar)
        // Fun is 90% used, Food 25%; then unlimited by spend (Shopping $300 first).
        #expect(rows.prefix(3).map(\.category) == [.fun, .food, .shopping])
        #expect(rows[0].status == .nearLimit)
        #expect(rows[2].limit == nil)
        #expect(rows[2].statusLabel == "No limit")
    }

    @Test func totalOfLimits() {
        #expect(CategoryBudgetSummary.totalOfLimits([.food: 400, .fun: 150, .home: 900]) == 1450)
    }

    // MARK: - View model

    @Test func viewModelParsesAndWarnsWhenLimitsExceedTheBudget() async throws {
        let defaults = freshDefaults()
        let budget = UserDefaultsBudgetRepository(defaults: defaults)
        budget.setMonthlyBudget(1000)
        let limits = UserDefaultsCategoryBudgetRepository(defaults: defaults)
        let vm = CategoryBudgetsViewModel(expenses: CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true)),
                                          budget: budget, categoryBudgets: limits, now: { self.now }, calendar: calendar)

        #expect(vm.setLimit(from: "600", for: .food, locale: Locale(identifier: "en_US")))
        #expect(vm.setLimit(from: "$1,200.50", for: .home, locale: Locale(identifier: "en_US")))
        vm.setLimit(from: "150", for: .fun, locale: Locale(identifier: "en_US"))
        #expect(vm.setLimit(from: "abc", for: .fun, locale: Locale(identifier: "en_US")) == false) // rejected…
        vm.setLimit(from: "", for: .fun)                                                              // …only empty removes

        let deadline = ContinuousClock.now + .seconds(2)
        while vm.limits.count < 2, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(vm.limits == [.food: 600, .home: 1200.5])
        #expect(vm.limitsExceedBudget)

        vm.setLimit(from: "", for: .home) // empty removes it
        while vm.limits.count != 1, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!vm.limitsExceedBudget)
    }

    @Test func insightsShowLimitsOnlyForThisMonth() async throws {
        let limits = UserDefaultsCategoryBudgetRepository(defaults: freshDefaults())
        limits.setLimit(400, for: .food)
        let vm = InsightsViewModel(expenses: CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true)),
                                   categoryBudgets: limits, now: { self.now }, calendar: calendar)
        let deadline = ContinuousClock.now + .seconds(2)
        while vm.categoryLimits.isEmpty, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }

        #expect(vm.limitsForCurrentPeriod == [.food: 400])
        vm.period = .lastMonth
        #expect(vm.limitsForCurrentPeriod.isEmpty)
    }
}
