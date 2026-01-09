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
    // live publisher storage
    private let hasAnyExpenseSubject = CurrentValueSubject<Bool,Never>(false)
    
    init(stack: CoreDataStack) {
        self.stack = stack
        //seed initial value (so home shows correct state at launch)
        hasAnyExpenseSubject.send(checkHasAnyExpense())
    }
    
    func addSampleExpense() -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak stack] promise in
            guard let context = stack?.viewContext else {
                promise(.failure(NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing context"])))
                return
            }
            context.perform {
                guard let entity = NSEntityDescription.entity(forEntityName: "Expense", in: context) else {
                    promise(.failure(NSError(domain: "CoreData", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing Expense entity"])))
                    return
                }
                
                let obj = NSManagedObject(entity: entity,
                                          insertInto: context)
                obj.setValue(UUID(), forKey: "id")
                obj.setValue(Date(), forKey: "date")
                obj.setValue("Sample Coffee", forKey: "title")
                obj.setValue(5.40, forKey: "amount")
                obj.setValue("Food & Drink", forKey: "category")
                
                do {
                    try context.save()
                    //push updated value to combine stream
                    let hasAny = self.checkHasAnyExpense()
                    self.hasAnyExpenseSubject.send(hasAny)
                    promise(.success(()))
                }catch{
                    promise(.failure(error))
                }
                
            }
        }
        .eraseToAnyPublisher()
    }
    
    func hasAnyExpense() -> AnyPublisher<Bool, Never> {
        // keep it simple - run a small fetch on a background queue
        hasAnyExpenseSubject.eraseToAnyPublisher()
        
    }
    
    private func checkHasAnyExpense() -> Bool {
        let context  = stack.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Expense")
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        }catch {
            return false
        }
    }
    
}
