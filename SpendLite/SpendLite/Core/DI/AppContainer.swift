//
//  AppContainer.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/5/25.
//


/// App-wide dependency container. We'll add services/repos here as we build them.
import Foundation
import Combine
import CoreData

final class AppContainer {
    /// The real app's container. Siri / Shortcuts actions can run without the app's UI,
    /// so they use this same instance rather than opening a second copy of the database.
    static let live = AppContainer()

    let coreData: CoreDataStack
    let expenses: ExpenseRepository
    let budget: BudgetRepository
    let recurring: RecurringExpenseRepository
    /// Keeps the Home Screen widget in sync. Nil for in-memory containers (tests, previews)
    /// so they never overwrite what the real widget shows.
    let widgetSync: WidgetSync?
    /// Face ID / passcode lock (Settings → Privacy).
    let appLock: AppLock
    /// Where budget and preferences are stored (a throwaway suite when in-memory).
    let defaults: UserDefaults

    init(inMemory: Bool = false, authenticator: Authenticator = DeviceAuthenticator(), defaults existingDefaults: UserDefaults? = nil) {
        self.coreData = CoreDataStack(inMemory: inMemory)
        self.expenses = CoreDataExpenseRepository(stack: coreData)
        self.recurring = CoreDataRecurringExpenseRepository(stack: coreData)
        // In-memory containers (previews/tests) get a throwaway defaults suite
        // so they never read or overwrite the real budget.
        let defaults = existingDefaults ?? (inMemory
            ? UserDefaults(suiteName: "SpendLite.inMemory.\(UUID().uuidString)") ?? .standard
            : .standard)
        self.defaults = defaults
        self.budget = UserDefaultsBudgetRepository(defaults: defaults)
        self.widgetSync = inMemory ? nil : WidgetSync(expenses: expenses, budget: budget)
        self.appLock = AppLock(store: defaults, authenticator: authenticator)
        // People who used SpendLite before onboarding existed shouldn't see the welcome screens.
        let expenseCount = (try? coreData.viewContext.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Expense"))) ?? 0
        Onboarding.skipForExistingUsers(defaults: defaults, hasExpenses: expenseCount > 0)
        // Later: feature flags, etc.
    }
}

// MARK: - Previews

extension AppContainer {
    /// In-memory container filled with a few realistic expenses, for SwiftUI previews.
    /// Categories match the Add Expense form; amounts are positive (spending).
    static func preview() -> AppContainer {
        let container = AppContainer(inMemory: true)
        for item in SampleExpenses.make() {
            // Fire-and-forget: the repository re-publishes the list after each save.
            _ = container.expenses.addExpense(item).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        }
        return container
    }
}
