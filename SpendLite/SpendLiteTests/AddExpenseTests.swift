//
//  AddExpenseTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct AddExpenseTests {

    // MARK: - Repository

    @Test func addExpenseSavesAndPublishesNewList() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        let item = ExpenseItem(id: UUID(), date: .now, title: "Lunch", amount: 12.5, category: "Food")

        try await awaitCompletion(repo.addExpense(item))

        let latest = try await firstValue(repo.expensesPublisher)
        #expect(latest == [item])
    }

    @Test func newestExpenseComesFirst() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        let older = ExpenseItem(id: UUID(), date: .now.addingTimeInterval(-3600), title: "Bus", amount: 2, category: "Transport")
        let newer = ExpenseItem(id: UUID(), date: .now, title: "Coffee", amount: 4, category: "Food")

        try await awaitCompletion(repo.addExpense(older))
        try await awaitCompletion(repo.addExpense(newer))

        let latest = try await firstValue(repo.expensesPublisher)
        #expect(latest.map(\.title) == ["Coffee", "Bus"])
    }

    // MARK: - View model

    @Test func viewModelSavesFormInput() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        let vm = AddExpenseViewModel(expenses: repo)

        await withCheckedContinuation { done in
            vm.save(amount: Decimal(string: "1250.50")!, description: "  New shoes  ", category: "Shopping", date: .now) {
                done.resume()
            }
        }

        let saved = try #require(try await firstValue(repo.expensesPublisher).first)
        #expect(saved.title == "New shoes")
        #expect(saved.amount == 1250.50)
        #expect(saved.category == "Shopping")
        #expect(vm.isSaving == false)
        #expect(vm.errorMessage == nil)
    }

    @Test func blankDescriptionAndNoCategoryStillSave() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        let vm = AddExpenseViewModel(expenses: repo)

        await withCheckedContinuation { done in
            vm.save(amount: 3, description: "   ", category: nil, date: .now) { done.resume() }
        }

        let saved = try #require(try await firstValue(repo.expensesPublisher).first)
        #expect(saved.title == "Other")
        #expect(saved.category == "Other")
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
}
