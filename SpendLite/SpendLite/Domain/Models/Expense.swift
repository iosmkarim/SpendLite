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
}
