//
//  UserDefaultsBudgetRepository.swift
//  SpendLite
//

import Foundation
import Combine

/// Stores the monthly budget in UserDefaults. A single number doesn't need Core Data.
final class UserDefaultsBudgetRepository: BudgetRepository {

    static let key = "monthlyBudget"
    static let defaultBudget: Double = 2000

    var monthlyBudgetPublisher: AnyPublisher<Double, Never> {
        subject.eraseToAnyPublisher()
    }

    private let defaults: UserDefaults
    private let subject: CurrentValueSubject<Double, Never>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Self.key) as? Double
        subject = CurrentValueSubject(stored ?? Self.defaultBudget)
    }

    func setMonthlyBudget(_ amount: Double) {
        guard amount >= 0, amount.isFinite else { return }
        defaults.set(amount, forKey: Self.key)
        subject.send(amount)
    }
}
