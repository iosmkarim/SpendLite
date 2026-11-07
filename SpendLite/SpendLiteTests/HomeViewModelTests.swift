//
//  HomeViewModelTests.swift
//  SpendLiteTests
//

import Testing
import Foundation
import Combine
@testable import SpendLite

@MainActor
struct HomeViewModelTests {

    @Test func doubleTapOnSampleDataAddsOnlyOneExpense() async throws {
        let repo = CoreDataExpenseRepository(stack: CoreDataStack(inMemory: true))
        let budget = UserDefaultsBudgetRepository(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        let vm = HomeViewModel(expenses: repo, budget: budget)

        vm.addSampleData()
        #expect(vm.isAddingSampleData)
        vm.addSampleData() // second tap while the first is still saving

        // Wait for the save to finish.
        for await adding in vm.$isAddingSampleData.values where !adding { break }

        var items: [ExpenseItem] = []
        for await value in repo.expensesPublisher.values { items = value; break }
        #expect(items.count == 1)
        #expect(vm.errorMessage == nil)
    }
}
