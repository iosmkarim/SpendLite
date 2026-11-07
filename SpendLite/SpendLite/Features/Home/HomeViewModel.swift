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
    private var cacellables = Set<AnyCancellable>()
    @Published var isAddingSampleData = false
    @Published var errorMessage: String?
    
    init(expenses: ExpenseRepository) {
        self.expenses = expenses
        observeExpense()
    }
    
    // MARK: - Intent
    
    func onAppear() {
        
    }
    
    // MARK: - Method
    
    private func observeExpense() {
        expenses
            .expensesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                
                self.hasAnyExpense = !items.isEmpty
                self.recentExpenses = Array(items.prefix(5))
                
                let monthlyBudget = 2000.0 // TEMP: hardcode for now
                let totalSpent = items.reduce(0) { $0 + $1.amount }
                self.summary = HomeSummary(monthlyBudget: monthlyBudget, totalSpent: totalSpent)
                
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
