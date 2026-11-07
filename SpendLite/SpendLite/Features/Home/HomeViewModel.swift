//
//  HomeViewModel.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/14/25.
//

import Foundation
import Combine

final class HomeViewModel: ObservableObject {

    // MARK: - Published State
    
    @Published var hasAnyExpense: Bool = false
    @Published var recentExpenses: [ExpenseItem] = []
    @Published var summary: HomeSummary? = nil
    
    private let expenses: ExpenseRepository
    private let now: () -> Date
    private let calendar: Calendar
    private var cacellables = Set<AnyCancellable>()
    @Published var isAddingSampleData = false
    @Published var errorMessage: String?

    /// `now` and `calendar` are injectable so tests can pin the current month.
    init(
        expenses: ExpenseRepository,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.expenses = expenses
        self.now = now
        self.calendar = calendar
        observeExpense()
    }
    
    // MARK: - Intent
    
    func onAppear() {
        
    }
    
    // MARK: - Method
    
    private func observeExpense() {
        // Re-run when the day changes too, so the monthly total resets on the 1st
        // even if the app stays open over midnight.
        let dayChanged = NotificationCenter.default
            .publisher(for: .NSCalendarDayChanged)
            .map { _ in () }
            .prepend(())

        expenses
            .expensesPublisher
            .combineLatest(dayChanged)
            .map { items, _ in items }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }

                self.hasAnyExpense = !items.isEmpty
                // Recent list stays all-time: it's "latest activity", not "this month".
                self.recentExpenses = Array(items.prefix(5))

                let monthlyBudget = 2000.0 // TEMP: hardcode for now (F5)
                self.summary = HomeSummary.forMonth(
                    containing: self.now(),
                    expenses: items,
                    monthlyBudget: monthlyBudget,
                    calendar: self.calendar
                )
            }
            .store(in: &cacellables)
    }
    
    func addSampleData() {
        isAddingSampleData = true
        errorMessage = nil
        
        expenses
            .addSampleExpense()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isAddingSampleData = false
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in
                print("success")
            }
            .store(in: &cacellables)
    }
}
