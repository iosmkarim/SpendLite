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
 * TransactionsViewModel (list, edit, delete)
 * Future features like Insights and Search
 
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
    private var cancellables = Set<AnyCancellable>()
    
    init(stack: CoreDataStack) {
        self.stack = stack
        //seed initial value (so home shows correct state at launch)
        expensesSubject.send(fetchAllExpenses())

        // Re-emit after *any* save to the context, including ones made elsewhere
        // (e.g. the recurring-expense generator adding this month's rent).
        NotificationCenter.default
            .publisher(for: NSManagedObjectContext.didSaveObjectsNotification, object: stack.viewContext)
            .sink { [weak self] _ in
                guard let self else { return }
                self.expensesSubject.send(self.fetchAllExpenses())
            }
            .store(in: &cancellables)
    }
    
    func addExpense(_ expense: ExpenseItem) -> AnyPublisher<Void, Error> {
        performChange { context in
            guard let entity = NSEntityDescription.entity(forEntityName: "Expense", in: context) else {
                throw RepositoryError.missingEntity
            }
            let obj = NSManagedObject(entity: entity, insertInto: context)
            Self.apply(expense, to: obj)
        }
    }

    func updateExpense(_ expense: ExpenseItem) -> AnyPublisher<Void, Error> {
        performChange { context in
            guard let obj = try Self.object(withID: expense.id, in: context) else {
                throw RepositoryError.notFound
            }
            Self.apply(expense, to: obj)
        }
    }

    func deleteExpense(id: UUID) -> AnyPublisher<Void, Error> {
        performChange { context in
            if let obj = try Self.object(withID: id, in: context) {
                context.delete(obj)
            }
        }
    }

    func deleteAllExpenses() -> AnyPublisher<Void, Error> {
        performChange { context in
            // Fetch-and-delete (not a batch delete) so the view context stays in sync.
            let request = NSFetchRequest<NSManagedObject>(entityName: "Expense")
            request.includesPropertyValues = false
            for object in try context.fetch(request) {
                context.delete(object)
            }
        }
    }

    // MARK: - Helpers

    enum RepositoryError: LocalizedError {
        case missingEntity
        case notFound

        var errorDescription: String? {
            switch self {
            case .missingEntity: "Missing Expense entity"
            case .notFound: "This expense no longer exists."
            }
        }
    }

    /// Runs `change` on the view context and saves (the save notification re-emits the list).
    /// On failure the context is rolled back so a half-made change can't be saved later.
    private func performChange(_ change: @escaping (NSManagedObjectContext) throws -> Void) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [weak self] promise in
            guard let self else {
                promise(.failure(NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing context"])))
                return
            }
            let context = self.stack.viewContext
            context.perform {
                do {
                    try change(context)
                    if context.hasChanges { try context.save() }
                    promise(.success(()))
                } catch {
                    context.rollback()
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private static func apply(_ expense: ExpenseItem, to obj: NSManagedObject) {
        obj.setValue(expense.id, forKey: "id")
        obj.setValue(expense.date, forKey: "date")
        obj.setValue(expense.title, forKey: "title")
        obj.setValue(expense.amount, forKey: "amount")
        obj.setValue(expense.category, forKey: "category")
        obj.setValue(expense.recurringID, forKey: "recurringID")
    }

    private static func object(withID id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Expense")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func addSampleExpense() -> AnyPublisher<Void, Error> {
        addExpense(
            ExpenseItem(
                id: UUID(),
                date: Date(),
                title: "Sample Coffee",
                amount: 5.40,
                category: ExpenseCategory.food.rawValue
            )
        )
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
                return ExpenseItem(
                    id: id, date: date, title: title, amount: amount, category: category,
                    recurringID: obj.value(forKey: "recurringID") as? UUID
                )
                
            }
        }catch{
            return []
        }
    }
}
