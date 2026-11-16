//
//  OnboardingViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Whether to show the welcome screens, and the rules for skipping them.
enum Onboarding {
    static var key: String { AppSettings.Key.hasCompletedOnboarding }

    static func hasCompleted(defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: key)
    }

    /// Anyone who already set a budget or added expenses was using SpendLite before
    /// onboarding existed, so they skip it.
    static func skipForExistingUsers(defaults: UserDefaults, hasExpenses: Bool) {
        guard defaults.object(forKey: key) == nil else { return }
        let hasBudget = defaults.object(forKey: UserDefaultsBudgetRepository.key) != nil
        if hasExpenses || hasBudget {
            defaults.set(true, forKey: key)
        }
    }
}

/// The three welcome screens: welcome, budget (+ currency), ready.
final class OnboardingViewModel: ObservableObject {

    enum Step: Int, CaseIterable { case welcome, budget, ready }

    @Published var step: Step = .welcome
    @Published var budgetText: String
    @Published private(set) var isFinishing = false

    /// Quick picks under the budget field.
    let suggestions: [Double] = [1000, 2000, 3000, 5000]

    private let budget: BudgetRepository
    private let expenses: ExpenseRepository
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    init(budget: BudgetRepository, expenses: ExpenseRepository, defaults: UserDefaults) {
        self.budget = budget
        self.expenses = expenses
        self.defaults = defaults
        budgetText = AddExpenseViewModel.amountText(for: UserDefaultsBudgetRepository.defaultBudget)
    }

    /// The typed budget, if it's a valid amount above zero.
    var budgetValue: Double? {
        let locale = Locale.current
        let cleaned = budgetText
            .replacingOccurrences(of: locale.groupingSeparator ?? ",", with: "")
            .filter { $0.isNumber || String($0) == (locale.decimalSeparator ?? ".") }
        guard let value = Decimal(string: cleaned, locale: locale), value > 0 else { return nil }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    var canContinue: Bool { step != .budget || budgetValue != nil }

    func pick(_ amount: Double) {
        budgetText = AddExpenseViewModel.amountText(for: amount)
    }

    func next() {
        guard canContinue, let following = Step(rawValue: step.rawValue + 1) else { return }
        step = following
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    /// Saves the budget, optionally adds sample expenses, and marks onboarding done.
    func finish(withSampleData: Bool, completion: @escaping () -> Void) {
        guard !isFinishing else { return }
        isFinishing = true
        if let value = budgetValue { budget.setMonthlyBudget(value) }

        let done = { [weak self] in
            self?.defaults.set(true, forKey: Onboarding.key)
            self?.isFinishing = false
            completion()
        }
        guard withSampleData else { return done() }

        Publishers.MergeMany(SampleExpenses.make().map(expenses.addExpense))
            .collect()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in done() }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}
