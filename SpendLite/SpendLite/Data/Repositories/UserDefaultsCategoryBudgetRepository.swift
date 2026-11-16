//
//  UserDefaultsCategoryBudgetRepository.swift
//  SpendLite
//

import Foundation
import Combine

/// Stores category limits as a small dictionary in UserDefaults ("Food" → 400).
final class UserDefaultsCategoryBudgetRepository: CategoryBudgetRepository {

    static let key = "categoryBudgets"

    var limitsPublisher: AnyPublisher<[ExpenseCategory: Double], Never> {
        subject.eraseToAnyPublisher()
    }

    private let defaults: UserDefaults
    private let subject: CurrentValueSubject<[ExpenseCategory: Double], Never>

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: Self.key) as? [String: Double] ?? [:]
        var limits: [ExpenseCategory: Double] = [:]
        for (name, amount) in stored {
            if let category = ExpenseCategory(rawValue: name), amount > 0 { limits[category] = amount }
        }
        subject = CurrentValueSubject(limits)
    }

    func setLimit(_ amount: Double?, for category: ExpenseCategory) {
        var limits = subject.value
        if let amount, amount > 0, amount.isFinite {
            limits[category] = amount
        } else {
            limits[category] = nil
        }
        defaults.set(Dictionary(uniqueKeysWithValues: limits.map { ($0.key.rawValue, $0.value) }), forKey: Self.key)
        subject.send(limits)
    }
}
