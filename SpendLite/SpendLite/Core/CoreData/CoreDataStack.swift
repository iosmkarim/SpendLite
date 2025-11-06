//
//  CoreDataStack.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/5/25.
//

import CoreData

final class CoreDataStack {
    let container: NSPersistentContainer
    var viewContext: NSManagedObjectContext { container.viewContext }
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SpendLite")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("CoreData load error: \(error)")}
        }
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
