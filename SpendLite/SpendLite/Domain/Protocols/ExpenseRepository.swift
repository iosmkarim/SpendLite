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
    
    /// Saves a new expense to storage, then re-emits the full list via `expensesPublisher`.
    func addExpense(_ expense: ExpenseItem) -> AnyPublisher<Void, Error>

    /// Replaces the stored expense that has the same `id`, then re-emits the list.
    /// Fails if no expense with that id exists.
    func updateExpense(_ expense: ExpenseItem) -> AnyPublisher<Void, Error>

    /// Deletes the expense with this id (no-op if it's already gone), then re-emits the list.
    func deleteExpense(id: UUID) -> AnyPublisher<Void, Error>

    /// Deletes every expense (Settings → Delete All Expenses), then re-emits the empty list.
    func deleteAllExpenses() -> AnyPublisher<Void, Error>

    /// Inserts a small sample expense for development/testing.
    func addSampleExpense() -> AnyPublisher<Void, Error>
}
