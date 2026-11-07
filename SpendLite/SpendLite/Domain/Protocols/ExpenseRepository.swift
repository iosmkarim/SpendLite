//
//  ExpenseRepository.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/24/25.
//

import Foundation
import Combine

protocol ExpenseRepository {
    /// emit the full list whenever storage changes.
    var expensesPublisher: AnyPublisher<[ExpenseItem], Never> { get }
    
    /// Publishes true if there is at least one expense in storage.
    func hasAnyExpense() -> AnyPublisher<Bool, Never>
    
    /// Saves a new expense to storage, then re-emits the full list via `expensesPublisher`.
    func addExpense(_ expense: ExpenseItem) -> AnyPublisher<Void, Error>

    /// Inserts a small sample expense for development/testing.
    func addSampleExpense() -> AnyPublisher<Void, Error>
}
