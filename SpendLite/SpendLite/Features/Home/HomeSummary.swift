//
//  HomeSummary.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 1/9/26.
//

import Foundation

struct HomeSummary: Equatable {
    let monthlyBudget: Double
    let totalSpent: Double

    /// Builds the summary for the calendar month containing `date`,
    /// counting only expenses dated in that month.
    static func forMonth(
        containing date: Date,
        expenses: [ExpenseItem],
        monthlyBudget: Double,
        calendar: Calendar = .current
    ) -> HomeSummary {
        let spentThisMonth = expenses
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
        return HomeSummary(monthlyBudget: monthlyBudget, totalSpent: spentThisMonth)
    }

    var remaining: Double {
        monthlyBudget - totalSpent
    }
    
    var progress: Double {
        guard monthlyBudget > 0 else { return 0 }
        return totalSpent / monthlyBudget 
    }
}
