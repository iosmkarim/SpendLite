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
    
    private let expenses: ExpenseRepository
    private var cacellables = Set<AnyCancellable>()
    
    init(expenses: ExpenseRepository) {
        self.expenses = expenses
        observeHasAnyExpense()
    }
    
    // MARK: - Intent
    
    func onAppear() {
        
    }
    
    // MARK: - Private
    
    private func observeHasAnyExpense() {
        expenses
            .hasAnyExpense()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasAny in
                self?.hasAnyExpense = hasAny
                
            }
            .store(in: &cacellables)
    }
}
