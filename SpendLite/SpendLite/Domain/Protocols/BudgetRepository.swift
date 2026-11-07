//
//  BudgetRepository.swift
//  SpendLite
//

import Foundation
import Combine

protocol BudgetRepository {
    /// Emits the current monthly budget immediately, then again whenever it changes.
    var monthlyBudgetPublisher: AnyPublisher<Double, Never> { get }

    /// Stores a new monthly budget. Values below 0 are ignored.
    func setMonthlyBudget(_ amount: Double)
}
