//
//  CategoryBudgetsViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Settings → Category budgets: this month's spending per category against its limit.
final class CategoryBudgetsViewModel: ObservableObject {

    @Published private(set) var rows: [CategoryBudgetRow] = []
    @Published private(set) var monthlyBudget: Double = 0
    @Published private(set) var limits: [ExpenseCategory: Double] = [:]

    private let repository: CategoryBudgetRepository
    private var cancellables = Set<AnyCancellable>()

    init(expenses: ExpenseRepository, budget: BudgetRepository, categoryBudgets: CategoryBudgetRepository,
         now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.repository = categoryBudgets

        expenses.expensesPublisher
            .combineLatest(categoryBudgets.limitsPublisher, budget.monthlyBudgetPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items, limits, monthly in
                self?.limits = limits
                self?.monthlyBudget = monthly
                self?.rows = CategoryBudgetSummary.rows(expenses: items, limits: limits, now: now(), calendar: calendar)
            }
            .store(in: &cancellables)
    }

    var totalOfLimits: Double { CategoryBudgetSummary.totalOfLimits(limits) }

    /// Category limits that add up to more than the whole monthly budget can't all be met.
    var limitsExceedBudget: Bool { monthlyBudget > 0 && totalOfLimits > monthlyBudget }

    /// Parses what was typed (locale-aware). An empty field or zero removes the limit.
    /// Anything that isn't a number ("abc") is rejected and leaves the limit as it was.
    @discardableResult
    func setLimit(from text: String, for category: ExpenseCategory, locale: Locale = .current) -> Bool {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            repository.setLimit(nil, for: category)
            return true
        }
        let cleaned = text
            .replacingOccurrences(of: locale.groupingSeparator ?? ",", with: "")
            .filter { $0.isNumber || String($0) == (locale.decimalSeparator ?? ".") }
        guard cleaned.contains(where: \.isNumber),
              let value = Decimal(string: cleaned, locale: locale), value >= 0 else { return false }
        repository.setLimit(NSDecimalNumber(decimal: value).doubleValue, for: category)
        return true
    }

    func removeLimit(for category: ExpenseCategory) {
        repository.setLimit(nil, for: category)
    }
}
