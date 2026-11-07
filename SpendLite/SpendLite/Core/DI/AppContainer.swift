//
//  AppContainer.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/5/25.
//


/// App-wide dependency container. We'll add services/repos here as we build them.
import Foundation

final class AppContainer {
    let coreData: CoreDataStack
    let expenses: ExpenseRepository
    let budget: BudgetRepository

    init(inMemory: Bool = false) {
        self.coreData = CoreDataStack(inMemory: inMemory)
        self.expenses = CoreDataExpenseRepository(stack: coreData)
        // In-memory containers (previews/tests) get a throwaway defaults suite
        // so they never read or overwrite the real budget.
        let defaults = inMemory
            ? UserDefaults(suiteName: "SpendLite.inMemory.\(UUID().uuidString)") ?? .standard
            : .standard
        self.budget = UserDefaultsBudgetRepository(defaults: defaults)
        // Later: feature flags, etc.
    }
}
