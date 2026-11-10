//
//  SettingsTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct SettingsTests {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: - Currency preference

    @Test func automaticFollowsTheRegion() {
        let store = freshDefaults()
        #expect(Currency.code(in: store, locale: Locale(identifier: "en_GB")) == "GBP")
        store.set("", forKey: AppSettings.Key.currencyCode) // "" is how the picker stores Automatic
        #expect(Currency.code(in: store, locale: Locale(identifier: "de_DE")) == "EUR")
    }

    @Test func chosenCurrencyWinsOverTheRegion() {
        let store = freshDefaults()
        store.set("BDT", forKey: AppSettings.Key.currencyCode)
        #expect(Currency.code(in: store, locale: Locale(identifier: "en_US")) == "BDT")
    }

    @Test func currencySymbols() {
        let en = Locale(identifier: "en_US")
        #expect(Currency.symbol(for: "USD", locale: en) == "$")
        #expect(Currency.symbol(for: "EUR", locale: en) == "€")
        #expect(Currency.name(for: "GBP", locale: en) == "British Pound")
    }

    @Test func commonListIncludesTheDeviceCurrency() {
        #expect(Currency.common.contains(Currency.automaticCode))
        #expect(Set(Currency.common).count == Currency.common.count) // no duplicates
    }

    // MARK: - CSV export

    @Test func csvHasHeaderAndOneRowPerExpenseOldestFirst() {
        let csv = ExpensesCSV(
            expenses: [
                ExpenseItem(id: UUID(), date: date(2026, 11, 9, 14, 5), title: "Lunch", amount: 12.5, category: "Food"),
                ExpenseItem(id: UUID(), date: date(2026, 11, 2, 8, 30), title: "Bus", amount: 2, category: "Transport"),
            ],
            currencyCode: "USD"
        )
        let lines = csv.text.split(separator: "\n").map(String.init)
        #expect(lines == [
            "Date,Description,Category,Amount,Currency",
            "2026-11-02 08:30,Bus,Transport,2.00,USD",
            "2026-11-09 14:05,Lunch,Food,12.50,USD",
        ])
    }

    @Test func csvAmountsAreSpreadsheetFriendly() {
        let csv = ExpensesCSV(
            expenses: [ExpenseItem(id: UUID(), date: date(2026, 11, 2), title: "Laptop", amount: 1250.5, category: "Shopping")],
            currencyCode: "EUR"
        )
        #expect(csv.text.contains(",1250.50,EUR")) // no "1,250.50" that would split the column
    }

    @Test(arguments: [
        ("Coffee", "Coffee"),
        ("Coffee, large", "\"Coffee, large\""),
        ("The \"best\" pizza", "\"The \"\"best\"\" pizza\""),
        ("Two\nlines", "\"Two\nlines\""),
    ])
    func csvEscaping(input: String, expected: String) {
        #expect(ExpensesCSV.escape(input) == expected)
    }

    @Test func csvFileNameHasTheDate() {
        let csv = ExpensesCSV(expenses: [], currencyCode: "USD", now: date(2026, 11, 9))
        #expect(csv.fileName == "SpendLite-expenses-2026-11-09.csv")
        #expect(csv.text == "Date,Description,Category,Amount,Currency\n")
    }

    @Test func legacyCategoryNamesExportAsCurrentNames() {
        let csv = ExpensesCSV(
            expenses: [ExpenseItem(id: UUID(), date: date(2026, 11, 2), title: "Dinner", amount: 30, category: "Food & Drink")],
            currencyCode: "USD"
        )
        #expect(csv.text.contains(",Dinner,Food,"))
    }

    // MARK: - Delete all

    @Test func deleteAllRemovesEveryExpense() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        for i in 1...3 {
            try await awaitCompletion(repo.addExpense(
                ExpenseItem(id: UUID(), date: .now, title: "Item \(i)", amount: Double(i), category: "Other")
            ))
        }
        #expect(try await firstValue(repo.expensesPublisher).count == 3)

        try await awaitCompletion(repo.deleteAllExpenses())
        #expect(try await firstValue(repo.expensesPublisher).isEmpty)
    }

    @Test func viewModelDeleteAll() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        try await awaitCompletion(repo.addExpense(ExpenseItem(id: UUID(), date: .now, title: "A", amount: 1, category: "Food")))
        let vm = SettingsViewModel(expenses: repo, budget: UserDefaultsBudgetRepository(defaults: freshDefaults()))
        await waitUntil { vm.expenseCount == 1 }

        vm.deleteAllExpenses()
        await waitUntil { vm.expenseCount == 0 && !vm.isDeleting }
    }

    // MARK: - Budget

    @Test(arguments: [
        ("2500", true, 2500.0),
        ("1,250.50", true, 1250.5),
        ("$3,000", true, 3000.0),
        ("0", true, 0.0),
        ("abc", false, 2000.0),   // rejected: keeps the default
        ("", false, 2000.0),
    ])
    func budgetParsing(text: String, accepted: Bool, expected: Double) async {
        let budget = UserDefaultsBudgetRepository(defaults: freshDefaults())
        let vm = SettingsViewModel(expenses: CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true)), budget: budget)

        #expect(vm.setMonthlyBudget(from: text, locale: Locale(identifier: "en_US")) == accepted)
        await waitUntil { vm.monthlyBudget == expected }
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

    private func firstValue<T>(_ publisher: AnyPublisher<T, Never>) async throws -> T {
        for await value in publisher.values { return value }
        throw CancellationError()
    }

    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "Timed out waiting for condition")
    }
}
