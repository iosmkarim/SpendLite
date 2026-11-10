//
//  RecurringExpenseTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct RecurringExpenseTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func rule(_ frequency: RecurringExpense.Frequency = .monthly, start: Date, generated: Int = 0,
                      paused: Bool = false, amount: Double = 1200, title: String = "Rent") -> RecurringExpense {
        RecurringExpense(title: title, amount: amount, category: "Home", frequency: frequency,
                         startDate: start, occurrencesGenerated: generated, isPaused: paused)
    }

    private func freshRepos() -> (CoreDataExpenseRepository, CoreDataRecurringExpenseRepository) {
        let stack = CoreDataStack(inMemory: true)
        return (CoreDataExpenseRepository(stack: stack), CoreDataRecurringExpenseRepository(stack: stack, calendar: calendar))
    }

    // MARK: - Schedule maths

    @Test func monthlyFromThe31stDoesNotDrift() {
        let r = rule(start: date(2026, 1, 31))
        let dates = (0..<4).map { r.date(ofOccurrence: $0, calendar: calendar) }
        #expect(dates == [date(2026, 1, 31), date(2026, 2, 28), date(2026, 3, 31), date(2026, 4, 30)])
    }

    @Test func weeklyAndYearly() {
        let weekly = rule(.weekly, start: date(2026, 11, 3))
        #expect(weekly.date(ofOccurrence: 2, calendar: calendar) == date(2026, 11, 17))

        let leapDay = rule(.yearly, start: date(2028, 2, 29))
        #expect(leapDay.date(ofOccurrence: 1, calendar: calendar) == date(2029, 2, 28))
        #expect(leapDay.date(ofOccurrence: 4, calendar: calendar) == date(2032, 2, 29))
    }

    @Test func dueOccurrencesCatchUpEverythingMissed() {
        let r = rule(start: date(2026, 8, 10))
        let due = r.dueOccurrences(now: date(2026, 11, 10, 12), calendar: calendar)
        #expect(due == [date(2026, 8, 10), date(2026, 9, 10), date(2026, 10, 10), date(2026, 11, 10)])
    }

    @Test func nothingDueBeforeTheStartDateOrAlreadyAdded() {
        #expect(rule(start: date(2026, 12, 1)).dueOccurrences(now: date(2026, 11, 10), calendar: calendar).isEmpty)
        #expect(rule(start: date(2026, 10, 10), generated: 2).dueOccurrences(now: date(2026, 11, 10, 12), calendar: calendar).isEmpty)
    }

    @Test func pausedHasNothingDue() {
        #expect(rule(start: date(2026, 1, 1), paused: true).dueOccurrences(now: date(2026, 11, 10), calendar: calendar).isEmpty)
    }

    @Test func catchUpIsCapped() {
        let r = rule(.weekly, start: date(2000, 1, 1))
        #expect(r.dueOccurrences(now: date(2026, 11, 10), calendar: calendar, limit: 50).count == 50)
    }

    @Test func resumingSkipsWhatFellInsideThePause() {
        // Paused after the Aug 10 payment; resumed on Nov 5 → next is Nov 10, not Sep 10.
        let paused = rule(start: date(2026, 8, 10), generated: 1, paused: true)
        let resumed = paused.resumed(now: date(2026, 11, 5), calendar: calendar)
        #expect(!resumed.isPaused)
        #expect(resumed.nextDate(calendar: calendar) == date(2026, 11, 10))
        #expect(resumed.dueOccurrences(now: date(2026, 11, 6), calendar: calendar).isEmpty)
    }

    @Test func resumingOnThePaymentDayStillCountsToday() {
        let paused = rule(start: date(2026, 8, 10), generated: 1, paused: true)
        let resumed = paused.resumed(now: date(2026, 11, 10, 15), calendar: calendar)
        #expect(resumed.nextDate(calendar: calendar) == date(2026, 11, 10))
    }

    @Test(arguments: [
        (RecurringExpense.Frequency.weekly, 10.0, 43.33),
        (.monthly, 15.0, 15.0),
        (.yearly, 120.0, 10.0),
    ])
    func monthlyEquivalent(frequency: RecurringExpense.Frequency, amount: Double, expected: Double) {
        let r = rule(frequency, start: date(2026, 1, 1), amount: amount)
        #expect(abs(r.monthlyEquivalent - expected) < 0.01)
    }

    // MARK: - Repository

    @Test func addingAddsTheFirstExpenseWhenItsDue() async throws {
        let (expenses, recurring) = freshRepos()
        let rent = rule(start: date(2026, 11, 10))
        try await awaitVoid(recurring.add(rent, now: date(2026, 11, 10, 12)))

        let added = try await firstValue(expenses.expensesPublisher)
        #expect(added.count == 1)
        #expect(added.first?.title == "Rent")
        #expect(added.first?.amount == 1200)
        #expect(added.first?.recurringID == rent.id)
        #expect(added.first?.date == date(2026, 11, 10))
        #expect(try await firstValue(recurring.recurringPublisher).first?.occurrencesGenerated == 1)
    }

    @Test func futureStartAddsNothingYet() async throws {
        let (expenses, recurring) = freshRepos()
        try await awaitVoid(recurring.add(rule(start: date(2026, 12, 1)), now: date(2026, 11, 10)))
        #expect(try await firstValue(expenses.expensesPublisher).isEmpty)
        #expect(try await firstValue(recurring.recurringPublisher).count == 1)
    }

    @Test func generatingTwiceNeverDuplicates() async throws {
        let (expenses, recurring) = freshRepos()
        try await awaitVoid(recurring.add(rule(start: date(2026, 9, 10)), now: date(2026, 9, 10, 12)))
        #expect(try await firstValue(expenses.expensesPublisher).count == 1)

        // Two months later the app opens: two more (Oct 10, Nov 10)…
        #expect(try await awaitValue(recurring.generateDueExpenses(now: date(2026, 11, 10, 12))) == 2)
        // …and opening it again the same day adds nothing.
        #expect(try await awaitValue(recurring.generateDueExpenses(now: date(2026, 11, 10, 18))) == 0)

        let all = try await firstValue(expenses.expensesPublisher)
        #expect(all.map(\.date) == [date(2026, 11, 10), date(2026, 10, 10), date(2026, 9, 10)])
    }

    @Test func pausedRulesAddNothing() async throws {
        let (expenses, recurring) = freshRepos()
        try await awaitVoid(recurring.add(rule(start: date(2026, 12, 1), paused: true), now: date(2026, 11, 10)))
        #expect(try await awaitValue(recurring.generateDueExpenses(now: date(2027, 3, 1))) == 0)
        #expect(try await firstValue(expenses.expensesPublisher).isEmpty)
    }

    @Test func stoppingKeepsExpensesAlreadyAdded() async throws {
        let (expenses, recurring) = freshRepos()
        let netflix = rule(start: date(2026, 10, 1), amount: 15, title: "Netflix")
        try await awaitVoid(recurring.add(netflix, now: date(2026, 11, 10)))
        #expect(try await firstValue(expenses.expensesPublisher).count == 2)

        try await awaitVoid(recurring.delete(id: netflix.id))
        #expect(try await firstValue(recurring.recurringPublisher).isEmpty)
        #expect(try await firstValue(expenses.expensesPublisher).count == 2)
        #expect(try await awaitValue(recurring.generateDueExpenses(now: date(2027, 1, 1))) == 0)
    }

    @Test func editingChangesFutureExpensesOnly() async throws {
        let (expenses, recurring) = freshRepos()
        var gym = rule(start: date(2026, 10, 5), amount: 40, title: "Gym")
        try await awaitVoid(recurring.add(gym, now: date(2026, 10, 5, 12)))

        gym = try #require(try await firstValue(recurring.recurringPublisher).first)
        gym.amount = 45
        try await awaitVoid(recurring.update(gym))
        _ = try await awaitValue(recurring.generateDueExpenses(now: date(2026, 11, 5, 12)))

        let amounts = try await firstValue(expenses.expensesPublisher).map(\.amount)
        #expect(amounts == [45, 40]) // November at the new price, October unchanged
    }

    // MARK: - Add form with Repeat

    @Test func addFormWithRepeatCreatesARecurringExpense() async throws {
        let (expenses, recurring) = freshRepos()
        let vm = AddExpenseViewModel(expenses: expenses, recurring: recurring)
        #expect(vm.canRepeat)

        await withCheckedContinuation { done in
            vm.save(amount: 9.99, description: "Spotify", category: "Fun", date: date(2026, 11, 10),
                    repeats: .monthly, now: date(2026, 11, 10, 12)) { done.resume() }
        }

        let rules = try await firstValue(recurring.recurringPublisher)
        #expect(rules.count == 1)
        #expect(rules.first?.frequency == .monthly)
        let added = try await firstValue(expenses.expensesPublisher)
        #expect(added.count == 1) // the first one, not a second hand-added copy
        #expect(added.first?.isRecurring == true)
    }

    @Test func editingAnExpenseNeverOffersRepeat() {
        let (expenses, recurring) = freshRepos()
        let item = ExpenseItem(id: UUID(), date: .now, title: "x", amount: 1, category: "Food")
        #expect(!AddExpenseViewModel(expenses: expenses, editing: item, recurring: recurring).canRepeat)
        #expect(!AddExpenseViewModel(expenses: expenses).canRepeat) // no repository → no option
    }

    // MARK: - List view model

    @Test func listShowsActiveFirstAndMonthlyTotal() async throws {
        let (_, recurring) = freshRepos()
        let now = date(2026, 11, 10)
        try await awaitVoid(recurring.add(rule(.monthly, start: date(2026, 12, 1), amount: 1200, title: "Rent"), now: now))
        try await awaitVoid(recurring.add(rule(.yearly, start: date(2026, 11, 20), amount: 120, title: "Domain"), now: now))
        try await awaitVoid(recurring.add(rule(.monthly, start: date(2026, 11, 15), paused: true, amount: 50, title: "Gym"), now: now))

        let vm = RecurringListViewModel(recurring: recurring, now: { now }, calendar: calendar)
        await waitUntil { vm.items.count == 3 }

        #expect(vm.items.map(\.title) == ["Domain", "Rent", "Gym"]) // soonest active first, paused last
        #expect(vm.activeCount == 2)
        #expect(vm.pausedCount == 1)
        #expect(abs(vm.monthlyTotal - 1210) < 0.001) // 1200 + 120/12; paused gym not counted
    }

    // MARK: - Helpers

    private func awaitVoid(_ publisher: AnyPublisher<Void, Error>) async throws {
        _ = try await awaitValue(publisher)
    }

    private func awaitValue<T>(_ publisher: AnyPublisher<T, Error>) async throws -> T {
        var cancellable: AnyCancellable?
        let value: T = try await withCheckedThrowingContinuation { cont in
            cancellable = publisher.sink { completion in
                if case .failure(let error) = completion { cont.resume(throwing: error) }
            } receiveValue: { cont.resume(returning: $0) }
        }
        cancellable?.cancel()
        return value
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
