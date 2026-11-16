//
//  CategoryBudgetRepository.swift
//  SpendLite
//

import Foundation
import Combine

/// Optional monthly limits per category (e.g. Food $400). Categories without a limit aren't capped.
protocol CategoryBudgetRepository {
    /// Current limits, emitted now and after every change.
    var limitsPublisher: AnyPublisher<[ExpenseCategory: Double], Never> { get }

    /// Sets a limit, or removes it when `amount` is nil. Zero, negative or invalid amounts remove it too.
    func setLimit(_ amount: Double?, for category: ExpenseCategory)
}
