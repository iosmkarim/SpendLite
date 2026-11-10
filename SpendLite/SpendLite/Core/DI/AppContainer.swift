//
//  AppContainer.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/5/25.
//


/// App-wide dependency container. We'll add services/repos here as we build them.
import Foundation
import Combine

final class AppContainer {
    let coreData: CoreDataStack
    let expenses: ExpenseRepository
    let budget: BudgetRepository
    /// Where budget and preferences are stored (a throwaway suite when in-memory).
    let defaults: UserDefaults

    init(inMemory: Bool = false) {
        self.coreData = CoreDataStack(inMemory: inMemory)
        self.expenses = CoreDataExpenseRepository(stack: coreData)
        // In-memory containers (previews/tests) get a throwaway defaults suite
        // so they never read or overwrite the real budget.
        let defaults = inMemory
            ? UserDefaults(suiteName: "SpendLite.inMemory.\(UUID().uuidString)") ?? .standard
            : .standard
        self.defaults = defaults
        self.budget = UserDefaultsBudgetRepository(defaults: defaults)
        // Later: feature flags, etc.
    }
}

// MARK: - Previews

extension AppContainer {
    /// In-memory container filled with a few realistic expenses, for SwiftUI previews.
    /// Categories match the Add Expense form; amounts are positive (spending).
    static func preview() -> AppContainer {
        let container = AppContainer(inMemory: true)
        let now = Date()
        let hour: TimeInterval = 3600
        let samples: [(String, Double, String, TimeInterval)] = [
            ("Morning coffee", 4.75, "Food", -2 * hour),
            ("Uber to work", 18.40, "Transport", -26 * hour),
            ("Groceries", 62.15, "Food", -50 * hour),
            ("Movie night", 24.00, "Fun", -74 * hour),
            ("Running shoes", 119.99, "Shopping", -98 * hour),
        ]
        for (title, amount, category, offset) in samples {
            let item = ExpenseItem(
                id: UUID(),
                date: now.addingTimeInterval(offset),
                title: title,
                amount: amount,
                category: category
            )
            // Fire-and-forget: the repository re-publishes the list after each save.
            _ = container.expenses.addExpense(item).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        }
        return container
    }
}
