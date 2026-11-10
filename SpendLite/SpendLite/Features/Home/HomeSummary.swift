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

    enum Status: Equatable {
        case onTrack     // under 80% of budget used
        case nearLimit   // 80–100% used
        case overBudget  // spent more than the budget
    }

    /// Share of the budget used at which we start warning the user.
    static let nearLimitThreshold = 0.8

    /// Budget minus spending. Negative when over budget.
    var remaining: Double {
        monthlyBudget - totalSpent
    }

    /// What's left to spend, never below 0.
    var remainingClamped: Double {
        max(0, remaining)
    }

    /// How much spending is over the budget (0 when within budget).
    var amountOver: Double {
        max(0, -remaining)
    }

    var isOverBudget: Bool {
        totalSpent > monthlyBudget
    }

    /// Share of the budget spent. Can go above 1 when over budget.
    var progress: Double {
        guard monthlyBudget > 0 else { return totalSpent > 0 ? 1 : 0 }
        return totalSpent / monthlyBudget
    }

    /// Share of the budget spent, as shown in the ring: "0%", "<1%", "42%", "125%".
    /// Rounded (not truncated) so it agrees with the amounts shown next to it.
    var percentSpentLabel: String {
        let percent = progress * 100
        if percent > 0 && percent < 1 { return "<1%" }
        return "\(Int(percent.rounded()))%"
    }

    var status: Status {
        if isOverBudget { return .overBudget }
        if progress >= Self.nearLimitThreshold { return .nearLimit }
        return .onTrack
    }
}
