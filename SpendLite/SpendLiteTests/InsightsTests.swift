//
//  InsightsTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct InsightsTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 1
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func item(_ amount: Double, _ category: String, on date: Date) -> ExpenseItem {
        ExpenseItem(id: UUID(), date: date, title: category, amount: amount, category: category)
    }

    /// "Now" for most tests: Nov 9, 2026, 3pm.
    private var now: Date { date(2026, 11, 9, 15) }

    // MARK: - Periods

    @Test func thisMonthRunsFromThe1stToNow() {
        let interval = InsightsPeriod.thisMonth.interval(now: now, calendar: calendar)
        #expect(interval.start == date(2026, 11, 1, 0))
        #expect(interval.end == now)
    }

    @Test func thisMonthComparesWithTheSameDaysLastMonth() {
        let previous = InsightsPeriod.thisMonth.previousInterval(now: now, calendar: calendar)
        #expect(previous.start == date(2026, 10, 1, 0))
        #expect(previous.end == date(2026, 10, 9, 15)) // not the whole of October
    }

    @Test func lastMonthIsTheWholePreviousMonth() {
        let interval = InsightsPeriod.lastMonth.interval(now: now, calendar: calendar)
        #expect(interval.start == date(2026, 10, 1, 0))
        #expect(interval.end == date(2026, 11, 1, 0))
        let previous = InsightsPeriod.lastMonth.previousInterval(now: now, calendar: calendar)
        #expect(previous.start == date(2026, 9, 1, 0))
        #expect(previous.end == date(2026, 10, 1, 0))
    }

    @Test func threeMonthsIncludesThisMonthAndTheTwoBefore() {
        let interval = InsightsPeriod.last3Months.interval(now: now, calendar: calendar)
        #expect(interval.start == date(2026, 9, 1, 0))
        #expect(interval.end == now)
    }

    // MARK: - Totals & comparison

    @Test func totalsOnlyCountThePeriodAndCompareWithPrevious() {
        let items = [
            item(30, "Food", on: date(2026, 11, 2)),
            item(10, "Transport", on: date(2026, 11, 8)),
            item(100, "Food", on: date(2026, 11, 20)),     // after "now": ignored
            item(50, "Food", on: date(2026, 10, 5)),       // previous period (Oct 1–9)
            item(999, "Food", on: date(2026, 10, 25)),     // October, but after Oct 9: not compared
        ]
        let summary = InsightsSummary.make(period: .thisMonth, expenses: items, now: now, calendar: calendar)

        #expect(summary.total == 40)
        #expect(summary.transactionCount == 2)
        #expect(summary.previousTotal == 50)
        #expect(summary.changeFromPrevious == -0.2) // 20% less
    }

    @Test func noPreviousSpendingMeansNoComparison() {
        let summary = InsightsSummary.make(period: .thisMonth, expenses: [item(5, "Food", on: date(2026, 11, 3))],
                                           now: now, calendar: calendar)
        #expect(summary.changeFromPrevious == nil)
    }

    @Test func emptyPeriodIsEmpty() {
        let summary = InsightsSummary.make(period: .thisMonth, expenses: [item(5, "Food", on: date(2026, 9, 3))],
                                           now: now, calendar: calendar)
        #expect(summary.isEmpty)
        #expect(summary.categories.isEmpty)
        #expect(summary.total == 0)
    }

    // MARK: - Categories

    @Test func categoriesAreSortedBiggestFirstWithShares() {
        let items = [
            item(20, "Transport", on: date(2026, 11, 2)),
            item(50, "Food", on: date(2026, 11, 3)),
            item(25, "Food & Drink", on: date(2026, 11, 4)), // old name → Food
            item(5, "Fun", on: date(2026, 11, 5)),
        ]
        let summary = InsightsSummary.make(period: .thisMonth, expenses: items, now: now, calendar: calendar)

        #expect(summary.categories.map(\.category) == [.food, .transport, .fun])
        #expect(summary.categories[0].total == 75)
        #expect(summary.categories[0].count == 2)
        #expect(summary.categories[0].share == 0.75)
        #expect(abs(summary.categories.map(\.share).reduce(0, +) - 1) < 0.0001)
    }

    // MARK: - Trend

    @Test func dailyTrendHasEveryDayIncludingEmptyOnes() {
        let items = [
            item(10, "Food", on: date(2026, 11, 2, 9)),
            item(5, "Food", on: date(2026, 11, 2, 18)),
            item(7, "Food", on: date(2026, 11, 9, 10)),
        ]
        let summary = InsightsSummary.make(period: .thisMonth, expenses: items, now: now, calendar: calendar)

        #expect(summary.trendUnit == .day)
        #expect(summary.trend.count == 9) // Nov 1 … Nov 9
        #expect(summary.trend.first?.start == date(2026, 11, 1, 0))
        #expect(summary.trend[1].total == 15) // two expenses on Nov 2 add up
        #expect(summary.trend[0].total == 0)
        #expect(summary.trend.last?.total == 7)
        #expect(summary.trend.reduce(0) { $0 + $1.total } == summary.total)
    }

    @Test func threeMonthTrendIsWeekly() {
        let summary = InsightsSummary.make(period: .last3Months, expenses: [item(10, "Food", on: date(2026, 10, 14))],
                                           now: now, calendar: calendar)
        #expect(summary.trendUnit == .weekOfYear)
        // Weeks starting Sunday: Aug 30 (contains Sep 1) … Nov 8 (contains Nov 9) = 11 bars.
        #expect(summary.trend.count == 11)
        #expect(summary.trend.reduce(0) { $0 + $1.total } == 10)
    }

    // MARK: - Average & labels

    @Test func averagePerDayCountsTodayForAnOngoingPeriod() {
        let summary = InsightsSummary.make(period: .thisMonth, expenses: [item(90, "Food", on: date(2026, 11, 3))],
                                           now: now, calendar: calendar)
        #expect(summary.averagePerDay(calendar: calendar) == 10) // $90 over Nov 1–9
    }

    @Test func averagePerDayForAWholeMonth() {
        let summary = InsightsSummary.make(period: .lastMonth, expenses: [item(310, "Food", on: date(2026, 10, 3))],
                                           now: now, calendar: calendar)
        #expect(summary.averagePerDay(calendar: calendar) == 10) // $310 over 31 days
    }

    @Test func labels() {
        let en = Locale(identifier: "en_US")
        let thisMonth = InsightsPeriod.thisMonth.interval(now: now, calendar: calendar)
        let lastMonth = InsightsPeriod.lastMonth.interval(now: now, calendar: calendar)
        // Date ranges use thin spaces around the dash; normalise them for comparison.
        let normalised = InsightsViewModel.label(for: thisMonth, period: .thisMonth, calendar: calendar, locale: en)
            .replacingOccurrences(of: "\u{2009}", with: " ")
        #expect(normalised == "Nov 1 – 9")
        #expect(InsightsViewModel.label(for: lastMonth, period: .lastMonth, calendar: calendar, locale: en) == "October")
    }

    // MARK: - View model

    @Test func viewModelUpdatesWhenPeriodChanges() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        try await awaitCompletion(repo.addExpense(item(40, "Food", on: date(2026, 11, 3))))
        try await awaitCompletion(repo.addExpense(item(25, "Fun", on: date(2026, 10, 12))))

        let vm = InsightsViewModel(expenses: repo, now: { self.now }, calendar: calendar)
        await waitUntil { vm.summary?.total == 40 }

        vm.period = .lastMonth
        await waitUntil { vm.summary?.total == 25 }
        #expect(vm.summary?.categories.first?.category == .fun)
    }

    // MARK: - Transactions filter (Insights → tap a category)

    @Test func transactionsFilterShowsOnlyThatCategory() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        try await awaitCompletion(repo.addExpense(item(40, "Food", on: date(2026, 11, 3))))
        try await awaitCompletion(repo.addExpense(item(25, "Fun", on: date(2026, 11, 4))))
        try await awaitCompletion(repo.addExpense(item(5, "Food & Drink", on: date(2026, 10, 4))))

        let vm = TransactionsViewModel(expenses: repo, calendar: calendar)
        await waitUntil { vm.sections.flatMap(\.items).count == 3 }

        vm.categoryFilter = .food
        await waitUntil { vm.sections.flatMap(\.items).count == 2 }
        #expect(vm.sections.flatMap(\.items).allSatisfy { $0.categoryKind == .food })

        vm.categoryFilter = nil
        await waitUntil { vm.sections.flatMap(\.items).count == 3 }
    }

    @Test func navCoordinatorSetsAndClearsTheFilter() {
        let nav = NavCoordinator()
        nav.goToTransactions(category: .food)
        #expect(nav.selectedTab == .transactions)
        #expect(nav.transactionsFilter == .food)

        nav.goToTransactions() // "See All" from Home shows everything
        #expect(nav.transactionsFilter == nil)
    }

    // MARK: - Helpers

    private func awaitCompletion(_ publisher: AnyPublisher<Void, Error>) async throws {
        var cancellable: AnyCancellable?
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            cancellable = publisher.sink { completion in
                if case .failure(let error) = completion { cont.resume(throwing: error) }
            } receiveValue: { cont.resume() }
        }
        cancellable?.cancel()
    }

    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "Timed out waiting for condition")
    }
}
