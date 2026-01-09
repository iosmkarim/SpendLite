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
    @Published var isAddingSampleData = false
    @Published var errorMessage: String?
    
    init(expenses: ExpenseRepository) {
        self.expenses = expenses
        observeHasAnyExpense()
    }
    
    // MARK: - Intent
    
    func onAppear() {
        
    }
    
    // MARK: - Method
    
    private func observeHasAnyExpense() {
        expenses
            .hasAnyExpense()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasAny in
                self?.hasAnyExpense = hasAny
                
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
