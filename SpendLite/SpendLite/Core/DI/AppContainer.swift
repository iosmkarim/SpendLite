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
    
    init(inMemory: Bool = false) {
        self.coreData = CoreDataStack(inMemory: inMemory)
        self.expenses = CoreDataExpenseRepository(stack: coreData)
        // Later: expenses repo, budget service, feature flags, etc.
    }
}
