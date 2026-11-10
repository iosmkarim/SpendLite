//
//  RecurringListViewModel.swift
//  SpendLite
//

import Foundation
import Combine

/// Recurring expenses for Settings → Recurring expenses: list, monthly total, pause / resume / edit / stop.
final class RecurringListViewModel: ObservableObject {

    /// Active ones first (soonest next date first), then paused ones.
    @Published private(set) var items: [RecurringExpense] = []
    @Published private(set) var hasLoaded = false
    @Published var errorMessage: String?

    let repository: RecurringExpenseRepository
    private let now: () -> Date
    let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    init(recurring: RecurringExpenseRepository, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.repository = recurring
        self.now = now
        self.calendar = calendar

        recurring.recurringPublisher
            .map { list in
                list.sorted { a, b in
                    if a.isPaused != b.isPaused { return !a.isPaused }
                    return a.nextDate(calendar: calendar) < b.nextDate(calendar: calendar)
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.items = $0
                self?.hasLoaded = true
            }
            .store(in: &cancellables)
    }

    var activeCount: Int { items.filter { !$0.isPaused }.count }
    var pausedCount: Int { items.count - activeCount }

    /// Roughly what the active recurring expenses cost per month.
    var monthlyTotal: Double {
        items.filter { !$0.isPaused }.reduce(0) { $0 + $1.monthlyEquivalent }
    }

    func nextDate(of item: RecurringExpense) -> Date {
        item.nextDate(calendar: calendar)
    }

    func setPaused(_ item: RecurringExpense, _ paused: Bool) {
        let updated = paused ? { var copy = item; copy.isPaused = true; return copy }()
                             : item.resumed(now: now(), calendar: calendar)
        save(updated)
    }

    func save(_ item: RecurringExpense) {
        run(repository.update(item))
    }

    func delete(_ item: RecurringExpense) {
        run(repository.delete(id: item.id))
    }

    private func run(_ publisher: AnyPublisher<Void, Error>) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
}
