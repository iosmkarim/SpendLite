//
//  CoreDataRecurringExpenseRepository.swift
//  SpendLite
//

import Foundation
import CoreData
import Combine

/// Stores recurring expenses in Core Data and turns due occurrences into expenses.
///
/// Generated expenses and the rule's `occurrencesGenerated` counter are written in the
/// same save, so a crash or a second call can never add the same occurrence twice.
final class CoreDataRecurringExpenseRepository: RecurringExpenseRepository {

    var recurringPublisher: AnyPublisher<[RecurringExpense], Never> {
        subject.eraseToAnyPublisher()
    }

    private let stack: CoreDataStack
    private let calendar: Calendar
    private let subject = CurrentValueSubject<[RecurringExpense], Never>([])
    private var cancellables = Set<AnyCancellable>()

    init(stack: CoreDataStack, calendar: Calendar = .current) {
        self.stack = stack
        self.calendar = calendar
        subject.send(fetchAll())

        NotificationCenter.default
            .publisher(for: NSManagedObjectContext.didSaveObjectsNotification, object: stack.viewContext)
            .sink { [weak self] _ in
                guard let self else { return }
                self.subject.send(self.fetchAll())
            }
            .store(in: &cancellables)
    }

    // MARK: - CRUD

    func add(_ recurring: RecurringExpense, now: Date) -> AnyPublisher<Void, Error> {
        perform { context in
            guard let entity = NSEntityDescription.entity(forEntityName: Self.entityName, in: context) else {
                throw RecurringError.missingEntity
            }
            let object = NSManagedObject(entity: entity, insertInto: context)
            Self.apply(recurring, to: object)
            return try self.generate(in: context, now: now, onlyID: recurring.id)
        }
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    func update(_ recurring: RecurringExpense) -> AnyPublisher<Void, Error> {
        perform { context in
            guard let object = try Self.object(withID: recurring.id, in: context) else {
                throw RecurringError.notFound
            }
            Self.apply(recurring, to: object)
            return 0
        }
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    func delete(id: UUID) -> AnyPublisher<Void, Error> {
        perform { context in
            if let object = try Self.object(withID: id, in: context) {
                context.delete(object)
            }
            return 0
        }
        .map { _ in () }
        .eraseToAnyPublisher()
    }

    func generateDueExpenses(now: Date) -> AnyPublisher<Int, Error> {
        perform { context in
            try self.generate(in: context, now: now, onlyID: nil)
        }
    }

    // MARK: - Generation

    /// Inserts an Expense for each due occurrence and advances the counters. Returns how many were added.
    private func generate(in context: NSManagedObjectContext, now: Date, onlyID: UUID?) throws -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        if let onlyID {
            request.predicate = NSPredicate(format: "id == %@", onlyID as CVarArg)
        }
        guard let expenseEntity = NSEntityDescription.entity(forEntityName: "Expense", in: context) else {
            throw RecurringError.missingEntity
        }

        var added = 0
        for object in try context.fetch(request) {
            guard let rule = Self.recurring(from: object) else { continue }
            let due = rule.dueOccurrences(now: now, calendar: calendar)
            guard !due.isEmpty else { continue }

            for date in due {
                let expense = NSManagedObject(entity: expenseEntity, insertInto: context)
                expense.setValue(UUID(), forKey: "id")
                expense.setValue(date, forKey: "date")
                expense.setValue(rule.title, forKey: "title")
                expense.setValue(rule.amount, forKey: "amount")
                expense.setValue(rule.category, forKey: "category")
                expense.setValue(rule.id, forKey: "recurringID")
            }
            object.setValue(Int64(rule.occurrencesGenerated + due.count), forKey: "occurrencesGenerated")
            added += due.count
        }
        return added
    }

    // MARK: - Core Data helpers

    private static let entityName = "RecurringExpense"

    enum RecurringError: LocalizedError {
        case missingEntity
        case notFound

        var errorDescription: String? {
            switch self {
            case .missingEntity: "Missing RecurringExpense entity"
            case .notFound: "This recurring expense no longer exists."
            }
        }
    }

    /// Runs `change` on the view context and saves; rolls back on failure.
    private func perform(_ change: @escaping (NSManagedObjectContext) throws -> Int) -> AnyPublisher<Int, Error> {
        Future<Int, Error> { [weak self] promise in
            guard let self else {
                promise(.failure(RecurringError.notFound))
                return
            }
            let context = self.stack.viewContext
            context.perform {
                do {
                    let result = try change(context)
                    if context.hasChanges { try context.save() }
                    promise(.success(result))
                } catch {
                    context.rollback()
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func fetchAll() -> [RecurringExpense] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        return ((try? stack.viewContext.fetch(request)) ?? []).compactMap(Self.recurring(from:))
    }

    private static func object(withID id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func apply(_ recurring: RecurringExpense, to object: NSManagedObject) {
        object.setValue(recurring.id, forKey: "id")
        object.setValue(recurring.title, forKey: "title")
        object.setValue(recurring.amount, forKey: "amount")
        object.setValue(recurring.category, forKey: "category")
        object.setValue(recurring.frequency.rawValue, forKey: "frequency")
        object.setValue(recurring.startDate, forKey: "startDate")
        object.setValue(Int64(recurring.occurrencesGenerated), forKey: "occurrencesGenerated")
        object.setValue(recurring.isPaused, forKey: "isPaused")
    }

    private static func recurring(from object: NSManagedObject) -> RecurringExpense? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let title = object.value(forKey: "title") as? String,
            let category = object.value(forKey: "category") as? String,
            let frequencyRaw = object.value(forKey: "frequency") as? String,
            let frequency = RecurringExpense.Frequency(rawValue: frequencyRaw),
            let startDate = object.value(forKey: "startDate") as? Date
        else { return nil }
        return RecurringExpense(
            id: id,
            title: title,
            amount: (object.value(forKey: "amount") as? Double) ?? 0,
            category: category,
            frequency: frequency,
            startDate: startDate,
            occurrencesGenerated: Int((object.value(forKey: "occurrencesGenerated") as? Int64) ?? 0),
            isPaused: (object.value(forKey: "isPaused") as? Bool) ?? false
        )
    }
}
