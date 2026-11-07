//
//  AddExpenseViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Turns the Add Expense form input into an `ExpenseItem` and saves it through the repository.
final class AddExpenseViewModel: ObservableObject {

    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let expenses: ExpenseRepository
    private var cancellables = Set<AnyCancellable>()

    init(expenses: ExpenseRepository) {
        self.expenses = expenses
    }

    /// Saves the expense. Calls `onSuccess` on the main thread once it is stored.
    func save(
        amount: Decimal,
        description: String,
        category: String?,
        date: Date,
        onSuccess: @escaping () -> Void
    ) {
        guard !isSaving, amount > 0 else { return }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryName = category ?? "Other"

        // Title and category must be non-empty: the repository skips rows missing either.
        let item = ExpenseItem(
            id: UUID(),
            date: date,
            title: trimmed.isEmpty ? categoryName : trimmed,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
            category: categoryName
        )

        isSaving = true
        errorMessage = nil

        expenses
            .addExpense(item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isSaving = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in
                onSuccess()
            }
            .store(in: &cancellables)
    }
}
