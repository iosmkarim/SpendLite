//
//  TransactionsViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Drives the Transactions tab: every expense grouped by month, plus delete with undo.
final class TransactionsViewModel: ObservableObject {

    @Published private(set) var sections: [TransactionSection] = []
    /// The expense just deleted, so the screen can offer Undo. Cleared on undo or dismiss.
    @Published private(set) var recentlyDeleted: ExpenseItem?
    @Published var errorMessage: String?

    /// False until the first list arrives, so the empty state doesn't flash on launch.
    @Published private(set) var hasLoaded = false

    var isEmpty: Bool { hasLoaded && sections.isEmpty }

    private let expenses: ExpenseRepository
    private var cancellables = Set<AnyCancellable>()

    init(expenses: ExpenseRepository, calendar: Calendar = .current) {
        self.expenses = expenses

        expenses.expensesPublisher
            .map { TransactionSection.byMonth($0, calendar: calendar) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.sections = $0
                self?.hasLoaded = true
            }
            .store(in: &cancellables)
    }

    func delete(_ item: ExpenseItem) {
        expenses.deleteExpense(id: item.id)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] in
                self?.recentlyDeleted = item
            }
            .store(in: &cancellables)
    }

    /// Puts the last deleted expense back (same id, date and details).
    func undoDelete() {
        guard let item = recentlyDeleted else { return }
        recentlyDeleted = nil
        expenses.addExpense(item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    /// Hides the Undo banner (after a timeout or when another action starts).
    func dismissUndo() {
        recentlyDeleted = nil
    }
}
