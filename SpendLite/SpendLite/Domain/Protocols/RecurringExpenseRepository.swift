//
//  RecurringExpenseRepository.swift
//  SpendLite
//

import Foundation
import Combine

protocol RecurringExpenseRepository {
    /// All recurring expenses, emitted now and after every change.
    var recurringPublisher: AnyPublisher<[RecurringExpense], Never> { get }

    /// Saves a new recurring expense, then adds any occurrences already due
    /// (so one starting today shows up in Transactions straight away).
    func add(_ recurring: RecurringExpense, now: Date) -> AnyPublisher<Void, Error>

    /// Saves changes (title, amount, category, paused). Past expenses are left as they were.
    func update(_ recurring: RecurringExpense) -> AnyPublisher<Void, Error>

    /// Stops repeating. Expenses it already added are kept.
    func delete(id: UUID) -> AnyPublisher<Void, Error>

    /// Adds an expense for every due occurrence that hasn't been added yet, across all
    /// recurring expenses, in a single save. Safe to call any number of times (no duplicates).
    /// Emits how many expenses were added.
    func generateDueExpenses(now: Date) -> AnyPublisher<Int, Error>
}
