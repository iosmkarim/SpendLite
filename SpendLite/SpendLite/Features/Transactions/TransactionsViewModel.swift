//
//  TransactionsViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Drives the Transactions tab: expenses grouped by month, narrowed by search and filters,
/// plus delete with undo.
final class TransactionsViewModel: ObservableObject {

    @Published private(set) var sections: [TransactionSection] = []
    /// The expense just deleted, so the screen can offer Undo. Cleared on undo or dismiss.
    @Published private(set) var recentlyDeleted: ExpenseItem?
    @Published var errorMessage: String?
    /// Search text, categories and date range applied to the list.
    @Published var filter = TransactionFilter()
    /// Number and total of the expenses currently shown (for "3 results · $45.20").
    @Published private(set) var resultCount = 0
    @Published private(set) var resultTotal: Double = 0

    /// False until the first list arrives, so the empty state doesn't flash on launch.
    @Published private(set) var hasLoaded = false

    var isEmpty: Bool { hasLoaded && sections.isEmpty }

    private let expenses: ExpenseRepository
    private var cancellables = Set<AnyCancellable>()

    init(expenses: ExpenseRepository, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.expenses = expenses

        expenses.expensesPublisher
            .combineLatest($filter.removeDuplicates())
            .map { items, filter in
                let today = now()
                let shown = filter.isActive
                    ? items.filter { filter.matches($0, now: today, calendar: calendar) }
                    : items
                return (TransactionSection.byMonth(shown, calendar: calendar), shown)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sections, shown in
                self?.sections = sections
                self?.resultCount = shown.count
                self?.resultTotal = shown.reduce(0) { $0 + $1.amount }
                self?.hasLoaded = true
            }
            .store(in: &cancellables)
    }

    // MARK: - Filter actions

    func toggle(_ category: ExpenseCategory) {
        if filter.categories.contains(category) {
            filter.categories.remove(category)
        } else {
            filter.categories.insert(category)
        }
    }

    /// Clears categories and date range (keeps the search text).
    func clearFilters() {
        filter.categories = []
        filter.dateRange = .allTime
    }

    /// Clears everything, including search.
    func clearAll() {
        filter = TransactionFilter()
    }

    /// Insights → tap a category: show only that category, for all time, with no search.
    func showOnly(_ category: ExpenseCategory) {
        filter = TransactionFilter(categories: [category])
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
