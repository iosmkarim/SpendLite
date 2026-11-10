//
//  AddExpenseViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Turns the expense form input into an `ExpenseItem` and saves it through the repository.
/// Used for both adding a new expense and editing an existing one (`editing` is non-nil).
final class AddExpenseViewModel: ObservableObject {

    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    /// The expense being edited, or nil when adding a new one.
    let editing: ExpenseItem?
    var isEditing: Bool { editing != nil }

    private let expenses: ExpenseRepository
    /// Needed to create repeating expenses; nil hides the Repeat option.
    let recurring: RecurringExpenseRepository?
    private var cancellables = Set<AnyCancellable>()

    /// Repeating is offered only when adding (an edit changes just that one expense).
    var canRepeat: Bool { recurring != nil && !isEditing }

    init(expenses: ExpenseRepository, editing: ExpenseItem? = nil, recurring: RecurringExpenseRepository? = nil) {
        self.expenses = expenses
        self.editing = editing
        self.recurring = recurring
    }

    /// Saves the expense (adds, or updates `editing`). Calls `onSuccess` on the main thread once stored.
    /// With `repeats`, it creates a recurring expense starting on `date` instead; that adds this
    /// first expense itself (if the date has arrived) and future ones automatically.
    func save(
        amount: Decimal,
        description: String,
        category: String?,
        date: Date,
        repeats: RecurringExpense.Frequency? = nil,
        now: Date = .now,
        onSuccess: @escaping () -> Void
    ) {
        guard !isSaving, amount > 0 else { return }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryName = category ?? "Other"

        // Title and category must be non-empty: the repository skips rows missing either.
        let item = ExpenseItem(
            id: editing?.id ?? UUID(),
            date: date,
            title: trimmed.isEmpty ? categoryName : trimmed,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
            category: categoryName
        )

        isSaving = true
        errorMessage = nil

        let operation: AnyPublisher<Void, Error>
        if let repeats, canRepeat, let recurring {
            operation = recurring.add(
                RecurringExpense(
                    title: item.title,
                    amount: item.amount,
                    category: item.category,
                    frequency: repeats,
                    startDate: date
                ),
                now: now
            )
        } else if isEditing {
            operation = expenses.updateExpense(item)
        } else {
            operation = expenses.addExpense(item)
        }
        operation
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

    // MARK: - Pre-filling the form when editing

    /// The amount as the user would type it in their locale, without grouping ("1250.5", not "1,250.50").
    static func amountText(for amount: Double, locale: Locale = .current) -> String {
        amount.formatted(.number.grouping(.never).precision(.fractionLength(0...2)).locale(locale))
    }

    /// The description to show. Empty when the title was just the category fallback,
    /// so the user sees the placeholder instead of e.g. "Food" typed in.
    static func descriptionText(for item: ExpenseItem) -> String {
        item.title == item.category ? "" : item.title
    }
}
