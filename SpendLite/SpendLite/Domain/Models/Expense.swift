//
//  Expense.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 1/23/26.
//

import Foundation

struct ExpenseItem: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let title: String
    let amount: Double
    let category: String
    /// The recurring expense that created this one, or nil if it was added by hand.
    var recurringID: UUID? = nil

    var isRecurring: Bool { recurringID != nil }
}
