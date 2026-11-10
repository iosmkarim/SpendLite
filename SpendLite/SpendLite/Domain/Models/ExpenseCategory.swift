//
//  ExpenseCategory.swift
//  SpendLite
//

import Foundation

/// The fixed set of spending categories. The raw value is what's stored in Core Data
/// (`ExpenseItem.category`) and shown to the user.
enum ExpenseCategory: String, CaseIterable, Identifiable, Hashable {
    case food = "Food"
    case transport = "Transport"
    case fun = "Fun"
    case shopping = "Shopping"
    case home = "Home"
    case health = "Health"
    case education = "Education"
    case other = "Other"

    var id: String { rawValue }
    var name: String { rawValue }

    /// Maps a stored category string to a category. Handles names saved by older
    /// builds (e.g. "Food & Drink") and falls back to `.other` for anything unknown.
    init(storedName: String) {
        if let exact = ExpenseCategory(rawValue: storedName) {
            self = exact
            return
        }
        switch storedName.lowercased() {
        case "food & drink", "food & dining", "food and drink": self = .food
        case "transportation": self = .transport
        case "entertainment": self = .fun
        default: self = .other
        }
    }
}

extension ExpenseItem {
    /// The item's category as a typed value (for icons/colours).
    var categoryKind: ExpenseCategory { ExpenseCategory(storedName: category) }
}
