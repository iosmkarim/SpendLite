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
    
    private var cacellables = Set<AnyCancellable>()
    
    init() {
        simulateFirstLaunch()
    }
    
    // MARK: - Intent
    
    func onAppear() {
        
    }
    
    // MARK: - Private
    
    private func simulateFirstLaunch() {
        hasAnyExpense = false 
    }
}
