//
//  SettingsViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Budget, data export and delete-all for the Settings tab.
/// (Currency and appearance are simple preferences, bound directly with @AppStorage.)
final class SettingsViewModel: ObservableObject {

    @Published private(set) var monthlyBudget: Double = 0
    @Published private(set) var expenses: [ExpenseItem] = []
    @Published private(set) var isDeleting = false
    @Published var errorMessage: String?

    var expenseCount: Int { expenses.count }

    private let expenseRepository: ExpenseRepository
    private let budget: BudgetRepository
    private var cancellables = Set<AnyCancellable>()

    init(expenses: ExpenseRepository, budget: BudgetRepository) {
        self.expenseRepository = expenses
        self.budget = budget

        budget.monthlyBudgetPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.monthlyBudget = $0 }
            .store(in: &cancellables)

        expenses.expensesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.expenses = $0 }
            .store(in: &cancellables)
    }

    /// Parses what was typed (locale-aware, ignores currency symbols / grouping).
    /// Returns false if it isn't a valid non-negative amount.
    @discardableResult
    func setMonthlyBudget(from text: String, locale: Locale = .current) -> Bool {
        let decimalSeparator = locale.decimalSeparator ?? "."
        let cleaned = text
            .replacingOccurrences(of: locale.groupingSeparator ?? ",", with: "")
            .filter { $0.isNumber || String($0) == decimalSeparator }
        guard let value = Decimal(string: cleaned, locale: locale), value >= 0 else { return false }
        budget.setMonthlyBudget(NSDecimalNumber(decimal: value).doubleValue)
        return true
    }

    func makeCSV(currencyCode: String = Currency.code) -> ExpensesCSV {
        ExpensesCSV(expenses: expenses, currencyCode: currencyCode)
    }

    func deleteAllExpenses() {
        guard !isDeleting else { return }
        isDeleting = true
        expenseRepository.deleteAllExpenses()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isDeleting = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
}
