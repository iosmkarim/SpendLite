//
//  TransactionsTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct TransactionsTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func item(_ title: String, _ amount: Double, on date: Date, category: String = "Food") -> ExpenseItem {
        ExpenseItem(id: UUID(), date: date, title: title, amount: amount, category: category)
    }

    private func freshRepo() -> CoreDataExpenseRepository {
        CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
    }

    // MARK: - Grouping by month

    @Test func groupsByMonthNewestFirstWithTotals() {
        let items = [
            item("Oct lunch", 12, on: date(2026, 10, 5)),
            item("Nov coffee", 4.5, on: date(2026, 11, 2)),
            item("Nov bus", 2.25, on: date(2026, 11, 20)),
            item("Last Nov", 99, on: date(2025, 11, 20)), // same month, other year: separate section
        ]

        let sections = TransactionSection.byMonth(items, calendar: calendar, locale: Locale(identifier: "en_US"))

        #expect(sections.map(\.title) == ["November 2026", "October 2026", "November 2025"])
        #expect(sections[0].total == 6.75)
        #expect(sections[0].items.map(\.title) == ["Nov bus", "Nov coffee"]) // newest first inside a month
        #expect(sections[1].total == 12)
    }

    @Test func monthBoundariesUseTheCalendar() {
        let items = [
            item("Last second of Oct", 1, on: calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59, second: 59))!),
            item("First second of Nov", 2, on: date(2026, 11, 1, 0)),
        ]
        let sections = TransactionSection.byMonth(items, calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(sections.map(\.total) == [2, 1])
    }

    @Test func noExpensesMeansNoSections() {
        #expect(TransactionSection.byMonth([], calendar: calendar).isEmpty)
    }

    // MARK: - Repository update / delete

    @Test func updateReplacesTheExpenseWithTheSameID() async throws {
        let repo = freshRepo()
        let original = item("Coffee", 4, on: date(2026, 11, 2))
        try await awaitCompletion(repo.addExpense(original))

        let edited = ExpenseItem(id: original.id, date: date(2026, 11, 3), title: "Big coffee", amount: 6.5, category: "Fun")
        try await awaitCompletion(repo.updateExpense(edited))

        #expect(try await firstValue(repo.expensesPublisher) == [edited])
    }

    @Test func updatingAMissingExpenseFails() async throws {
        let repo = freshRepo()
        await #expect(throws: (any Error).self) {
            try await awaitCompletion(repo.updateExpense(item("Ghost", 1, on: .now)))
        }
        #expect(try await firstValue(repo.expensesPublisher).isEmpty) // nothing was inserted
    }

    @Test func deleteRemovesOnlyThatExpense() async throws {
        let repo = freshRepo()
        let keep = item("Keep", 1, on: date(2026, 11, 1))
        let remove = item("Remove", 2, on: date(2026, 11, 2))
        try await awaitCompletion(repo.addExpense(keep))
        try await awaitCompletion(repo.addExpense(remove))

        try await awaitCompletion(repo.deleteExpense(id: remove.id))
        #expect(try await firstValue(repo.expensesPublisher) == [keep])

        // Deleting again is harmless.
        try await awaitCompletion(repo.deleteExpense(id: remove.id))
        #expect(try await firstValue(repo.expensesPublisher) == [keep])
    }

    // MARK: - View model: delete + undo

    @Test func deleteThenUndoRestoresTheSameExpense() async throws {
        let repo = freshRepo()
        let coffee = item("Coffee", 4, on: date(2026, 11, 2))
        try await awaitCompletion(repo.addExpense(coffee))
        let vm = TransactionsViewModel(expenses: repo, calendar: calendar)
        await waitUntil { vm.sections.count == 1 }

        vm.delete(coffee)
        await waitUntil { vm.recentlyDeleted == coffee }
        #expect(vm.isEmpty)

        vm.undoDelete()
        await waitUntil { vm.sections.first?.items == [coffee] }
        #expect(vm.recentlyDeleted == nil)
        #expect(try await firstValue(repo.expensesPublisher) == [coffee])
    }

    // MARK: - Editing through the form's view model

    @Test func editingViewModelUpdatesInsteadOfAdding() async throws {
        let repo = freshRepo()
        let original = item("Coffee", 4, on: date(2026, 11, 2))
        try await awaitCompletion(repo.addExpense(original))

        let vm = AddExpenseViewModel(expenses: repo, editing: original)
        #expect(vm.isEditing)
        await withCheckedContinuation { done in
            vm.save(amount: 5.75, description: "Latte", category: "Food", date: original.date) { done.resume() }
        }

        let all = try await firstValue(repo.expensesPublisher)
        #expect(all.count == 1)
        #expect(all.first?.id == original.id)
        #expect(all.first?.title == "Latte")
        #expect(all.first?.amount == 5.75)
    }

    @Test(arguments: [
        (amount: 5.4, locale: "en_US", text: "5.4"),
        (amount: 12.0, locale: "en_US", text: "12"),
        (amount: 1250.5, locale: "en_US", text: "1250.5"),   // no "1,250.5": the form would misread it
        (amount: 1250.5, locale: "de_DE", text: "1250,5"),
    ])
    func amountTextForEditing(amount: Double, locale: String, text: String) {
        #expect(AddExpenseViewModel.amountText(for: amount, locale: Locale(identifier: locale)) == text)
    }

    @Test func fallbackTitleIsNotPrefilledAsDescription() {
        #expect(AddExpenseViewModel.descriptionText(for: item("Food", 3, on: .now, category: "Food")) == "")
        #expect(AddExpenseViewModel.descriptionText(for: item("Pizza", 3, on: .now, category: "Food")) == "Pizza")
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

    /// Polls until `condition` holds (view models apply updates on the next main-queue turn).
    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "Timed out waiting for condition")
    }
}
