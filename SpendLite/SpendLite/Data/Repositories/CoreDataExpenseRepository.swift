//
//  CoreDataExpenseRepository.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/24/25.
//

import Foundation
import CoreData
import Combine

/*
 Responsibility:
 
 Acts as the single source of truth for expense data backed by core data.
 This repository exposes a combine publisher that emits the full list of
 expenses whenever the underlying storage changes.
 
 Key behaviors:
 
 * Persists expense entities using core data
 * Fetches and maps core data objects into domain level expense models
 * Publishes live updates via expensesPublisher after every save
 * Seeds initial values on app launch so UI renders correct state immediately
 * Derives lightweight state from the same data stream (e.g. hasAnyExpense)
 
 
 Why this exists:
 
 * Keeps Core data implementation details out of viewModels.
 * Enables reactive UI updates without manual refresh or app restart
 * Allows viewmodels to stay testable by depending on a protocol
 * Makes it easy to swap in a mock repository for unit tests
 
 Used by:
 
 * HomeViewModel
 * Add Expense flow
 * Future features like History, Insights and Search
 
 Notes:
 
 * All combine publishers are guaranteed to emit on main-thread safe data
 * This repository intentionally stays lightweight (no business logic)
 * Edit/Delete operations must re-fetch and re-emit the updated expense list
 */

final class CoreDataExpenseRepository: ExpenseRepository {
    
    var expensesPublisher: AnyPublisher<[ExpenseItem], Never> {
        expensesSubject.eraseToAnyPublisher()
    }
    
    private let stack: CoreDataStack
    // live publisher storage
    private let expensesSubject = CurrentValueSubject<[ExpenseItem],Never>([])
    
    init(stack: CoreDataStack) {
        self.stack = stack
        //seed initial value (so home shows correct state at launch)
        expensesSubject.send(fetchAllExpenses())
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
                    let latest = self.fetchAllExpenses()
                    self.expensesSubject.send(latest)
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
        expensesPublisher
            .map { !$0.isEmpty }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    private func fetchAllExpenses() -> [ExpenseItem] {
        let context = stack.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Expense")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let objects = try context.fetch(request)
            return objects.compactMap { (obj) -> ExpenseItem? in
                guard
                    let id = obj.value(forKey: "id") as? UUID,
                    let date = obj.value(forKey: "date") as? Date,
                    let title = obj.value(forKey: "title") as? String,
                    let category = obj.value(forKey: "category") as? String
                else {return nil}
                let amount = (obj.value(forKey: "amount") as? Double) ?? 0
                return ExpenseItem(id: id, date: date, title: title, amount: amount, category: category)
                
            }
        }catch{
            return []
        }
    }
}
