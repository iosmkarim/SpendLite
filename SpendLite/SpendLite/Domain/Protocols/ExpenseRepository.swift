//
//  ExpenseRepository.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/24/25.
//

import Foundation
import Combine

protocol ExpenseRepository {
    /// Publishes true if there is at least one expense in storage. 
    func hasAnyExpense() -> AnyPublisher<Bool, Never>
    
    /// Inserts a small sample expense for development/testing.
    func addSampleExpense() -> AnyPublisher<Void, Error>
}
