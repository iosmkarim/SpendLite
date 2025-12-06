//
//  CoreDataExpenseRepository.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/24/25.
//

import Foundation
import CoreData
import Combine

final class CoreDataExpenseRepository: ExpenseRepository {
    private let stack: CoreDataStack
    
    init(stack: CoreDataStack) {
        self.stack = stack
    }
    
    func hasAnyExpense() -> AnyPublisher<Bool, Never> {
        // keep it simple - run a small fetch on a background queue
        Future<Bool, Never> { [weak stack] promise in
            guard let context = stack?.viewContext else {
                promise(.success(false))
                return
            }
            context.perform {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Expense")
                request.fetchLimit = 1
                
                do {
                    let count = try context.count(for: request)
                    promise(.success(count > 0))
                }catch {
                    promise(.success(false))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
