//
//  TransactionFilterTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct TransactionFilterTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private var now: Date { date(2026, 11, 9, 15) }

    private func item(_ title: String, _ amount: Double, _ category: String = "Food", on day: Date? = nil) -> ExpenseItem {
        ExpenseItem(id: UUID(), date: day ?? date(2026, 11, 5), title: title, amount: amount, category: category)
    }

    private func matches(_ filter: TransactionFilter, _ item: ExpenseItem) -> Bool {
        filter.matches(item, now: now, calendar: calendar)
    }

    // MARK: - Search

    @Test(arguments: [
        ("coffee", true),          // case-insensitive
        ("COF", true),             // partial word
        ("cafe", true),            // accents ignored: matches "Café"
        ("morning coffee", true),  // every word must match…
        ("morning tea", false),    // …so one missing word fails
        ("food", true),            // category name
        ("transport", false),
        ("", true),                // empty search shows everything
        ("   ", true),
    ])
    func searchText(query: String, expected: Bool) {
        let coffee = item("Morning coffee at Café Nero", 5.4)
        #expect(matches(TransactionFilter(searchText: query), coffee) == expected)
    }

    @Test(arguments: [
        ("5.40", true),
        ("5.4", true),       // trailing zero optional
        ("5,40", true),      // comma decimal separator
        ("$5.40", true),     // currency symbol ignored
        ("5", true),         // whole-number part
        ("54", false),       // not "54"
        ("5.41", false),
    ])
    func searchAmount(query: String, expected: Bool) {
        #expect(matches(TransactionFilter(searchText: query), item("Coffee", 5.4)) == expected)
    }

    @Test func wholeNumberSearchDoesNotMatchLongerAmounts() {
        let filter = TransactionFilter(searchText: "12")
        #expect(matches(filter, item("A", 12.5)))
        #expect(!matches(filter, item("B", 125)))   // "12" shouldn't find $125
        #expect(!matches(filter, item("C", 112)))
    }

    // MARK: - Categories

    @Test func categoriesMatchAnySelected() {
        let filter = TransactionFilter(categories: [.food, .fun])
        #expect(matches(filter, item("Lunch", 10, "Food")))
        #expect(matches(filter, item("Movie", 12, "Fun")))
        #expect(!matches(filter, item("Bus", 2, "Transport")))
        #expect(matches(filter, item("Old dinner", 30, "Food & Drink"))) // legacy name → Food
    }

    // MARK: - Date ranges

    @Test(arguments: [
        (TransactionFilter.DateRange.thisMonth, [true, false, false, false]),
        (.lastMonth, [false, true, false, false]),
        (.last3Months, [true, true, true, false]),
        (.thisYear, [true, true, true, false]),
        (.allTime, [true, true, true, true]),
    ])
    func dateRanges(range: TransactionFilter.DateRange, expected: [Bool]) {
        let days = [date(2026, 11, 1, 0), date(2026, 10, 31, 23), date(2026, 9, 1, 0), date(2025, 12, 31)]
        let filter = TransactionFilter(dateRange: range)
        #expect(days.map { matches(filter, item("x", 1, on: $0)) } == expected)
    }

    @Test func thisMonthIncludesLaterDaysThisMonth() {
        // Future-dated expenses this month still count as "this month".
        #expect(matches(TransactionFilter(dateRange: .thisMonth), item("Rent", 900, on: date(2026, 11, 28))))
    }

    @Test func everythingCombines() {
        let filter = TransactionFilter(searchText: "lunch", categories: [.food], dateRange: .thisMonth)
        #expect(matches(filter, item("Lunch", 12)))
        #expect(!matches(filter, item("Lunch", 12, "Fun")))                         // wrong category
        #expect(!matches(filter, item("Lunch", 12, on: date(2026, 10, 3))))         // wrong month
        #expect(!matches(filter, item("Dinner", 12)))                               // wrong text
    }

    @Test func activeFlags() {
        #expect(!TransactionFilter().isActive)
        #expect(TransactionFilter(searchText: "x").isActive)
        #expect(!TransactionFilter(searchText: "x").hasFilters)  // search alone isn't a "filter" chip
        #expect(TransactionFilter(categories: [.food]).hasFilters)
        #expect(TransactionFilter(dateRange: .lastMonth).hasFilters)
    }

    // MARK: - View model

    @Test func viewModelFiltersAndSummarises() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        for expense in [item("Lunch", 12.5), item("Dinner", 30), item("Taxi", 18, "Transport"),
                        item("Lunch", 9, on: date(2026, 10, 2))] {
            try await awaitCompletion(repo.addExpense(expense))
        }
        let vm = TransactionsViewModel(expenses: repo, now: { self.now }, calendar: calendar)
        await waitUntil { vm.resultCount == 4 }

        vm.filter.searchText = "lunch"
        await waitUntil { vm.resultCount == 2 }
        #expect(vm.resultTotal == 21.5)
        #expect(vm.sections.count == 2) // November and October

        vm.filter.dateRange = .thisMonth
        await waitUntil { vm.resultCount == 1 }

        vm.clearFilters()       // keeps the search
        await waitUntil { vm.resultCount == 2 }
        #expect(vm.filter.searchText == "lunch")

        vm.filter.searchText = "nothing like this"
        await waitUntil { vm.isEmpty }

        vm.clearAll()
        await waitUntil { vm.resultCount == 4 }
        #expect(!vm.filter.isActive)
    }

    @Test func showOnlyReplacesTheWholeFilter() {
        let vm = TransactionsViewModel(expenses: CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true)))
        vm.filter = TransactionFilter(searchText: "x", categories: [.fun], dateRange: .lastMonth)
        vm.showOnly(.food)
        #expect(vm.filter == TransactionFilter(categories: [.food]))
    }

    @Test func toggleAddsAndRemovesCategories() {
        let vm = TransactionsViewModel(expenses: CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true)))
        vm.toggle(.food)
        vm.toggle(.fun)
        #expect(vm.filter.categories == [.food, .fun])
        vm.toggle(.food)
        #expect(vm.filter.categories == [.fun])
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
