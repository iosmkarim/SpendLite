//
//  SampleExpenses.swift
//  SpendLite
//

import Foundation

/// A few realistic expenses from the last few days, for "Explore with sample data" and previews.
enum SampleExpenses {
    static func make(now: Date = .now) -> [ExpenseItem] {
        let hour: TimeInterval = 3600
        let samples: [(String, Double, ExpenseCategory, TimeInterval)] = [
            ("Morning coffee", 4.75, .food, -2 * hour),
            ("Uber to work", 18.40, .transport, -26 * hour),
            ("Groceries", 62.15, .food, -50 * hour),
            ("Movie night", 24.00, .fun, -74 * hour),
            ("Running shoes", 119.99, .shopping, -98 * hour),
        ]
        return samples.map { title, amount, category, offset in
            ExpenseItem(id: UUID(), date: now.addingTimeInterval(offset), title: title,
                        amount: amount, category: category.rawValue)
        }
    }
}
