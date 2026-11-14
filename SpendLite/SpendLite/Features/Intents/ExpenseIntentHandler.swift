//
//  ExpenseIntentHandler.swift
//  SpendLite
//

import Foundation
import Combine

/// The work behind the Siri / Shortcuts actions, kept separate from the App Intents layer
/// so it can be unit tested with an in-memory container.
struct ExpenseIntentHandler {

    enum IntentError: LocalizedError, Equatable {
        case invalidAmount

        var errorDescription: String? {
            switch self {
            case .invalidAmount: "The amount needs to be more than zero."
            }
        }
    }

    /// What Siri says back, plus the numbers behind it.
    struct BudgetReply: Equatable {
        let remaining: Double
        let budget: Double
        let spent: Double
        let status: HomeSummary.Status
        let sentence: String
    }

    let container: AppContainer
    var now: () -> Date = { .now }
    var calendar: Calendar = .current

    // MARK: - Add expense

    /// Saves an expense. A blank description falls back to the category name (same as the Add form).
    @discardableResult
    func addExpense(amount: Double, description: String?, category: ExpenseCategory?) async throws -> ExpenseItem {
        guard amount > 0, amount.isFinite else { throw IntentError.invalidAmount }
        let category = category ?? .other
        let trimmed = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let item = ExpenseItem(
            id: UUID(),
            date: now(),
            title: trimmed.isEmpty ? category.name : trimmed,
            amount: amount,
            category: category.rawValue
        )
        try await container.expenses.addExpense(item).firstValue()
        await updateWidget()
        return item
    }

    /// "Added $5.40 for Coffee to Food. $1,252.00 left this month."
    func confirmation(for item: ExpenseItem) async -> String {
        let reply = await budgetReply()
        let what = item.title == item.categoryKind.name ? "" : " for \(item.title)"
        let added = "Added \(item.amount.asCurrency())\(what) to \(item.categoryKind.name)."
        if reply.status == .overBudget {
            return "\(added) You're \((-reply.remaining).asCurrency()) over budget this month."
        }
        return "\(added) \(reply.remaining.asCurrency()) left this month."
    }

    // MARK: - Budget status

    func budgetReply() async -> BudgetReply {
        // Add any recurring expenses that came due, so the answer is current.
        _ = try? await container.recurring.generateDueExpenses(now: now()).firstValue()

        let expenses = await container.expenses.expensesPublisher.firstValue()
        let budget = await container.budget.monthlyBudgetPublisher.firstValue()
        let summary = HomeSummary.forMonth(containing: now(), expenses: expenses, monthlyBudget: budget, calendar: calendar)

        var month = Date.FormatStyle.dateTime.month(.wide)
        month.calendar = calendar
        month.timeZone = calendar.timeZone
        let monthName = now().formatted(month)

        let sentence: String
        switch summary.status {
        case .overBudget:
            sentence = "You're \(summary.amountOver.asCurrency()) over your \(budget.asCurrency()) \(monthName) budget."
        case .nearLimit:
            sentence = "You have \(summary.remaining.asCurrency()) left of your \(budget.asCurrency()) \(monthName) budget. That's \(summary.percentSpentLabel) spent, so you're close to your limit."
        case .onTrack:
            sentence = "You have \(summary.remaining.asCurrency()) left of your \(budget.asCurrency()) \(monthName) budget."
        }
        return BudgetReply(remaining: summary.remaining, budget: budget, spent: summary.totalSpent,
                           status: summary.status, sentence: sentence)
    }

    // MARK: - Widget

    private func updateWidget() async {
        guard let sync = container.widgetSync else { return }
        let expenses = await container.expenses.expensesPublisher.firstValue()
        let budget = await container.budget.monthlyBudgetPublisher.firstValue()
        sync.writeNow(expenses: expenses, budget: budget)
    }
}

// MARK: - Combine → async helpers

extension Publisher where Failure == Never {
    /// The current / next value (repositories use CurrentValueSubjects, so this returns immediately).
    func firstValue() async -> Output {
        for await value in values { return value }
        fatalError("Publisher finished without a value")
    }
}

extension Publisher {
    /// Waits for the first value, or throws the publisher's error.
    @discardableResult
    func firstValue() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var finished = false
            cancellable = first().sink { completion in
                defer { _ = cancellable }
                guard !finished else { return }
                finished = true
                switch completion {
                case .failure(let error): continuation.resume(throwing: error)
                case .finished: continuation.resume(throwing: CancellationError()) // ended with no value
                }
            } receiveValue: { value in
                guard !finished else { return }
                finished = true
                continuation.resume(returning: value)
            }
        }
    }
}
