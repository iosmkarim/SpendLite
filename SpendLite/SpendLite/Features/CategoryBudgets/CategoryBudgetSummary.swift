//
//  CategoryBudgetSummary.swift
//  SpendLite
//

import Foundation

/// This month's spending per category against its limit. Pure, unit tested.
struct CategoryBudgetRow: Identifiable, Equatable {
    let category: ExpenseCategory
    let spent: Double
    /// nil when the category has no limit.
    let limit: Double?

    var id: ExpenseCategory { category }

    /// 0...1 (capped) share of the limit used; nil without a limit.
    var progress: Double? {
        guard let limit, limit > 0 else { return nil }
        return min(1, spent / limit)
    }

    var remaining: Double? { limit.map { $0 - spent } }

    /// Same thresholds as the monthly budget: 80% is "near", above the limit is "over".
    var status: HomeSummary.Status? {
        guard let limit else { return nil }
        if spent > limit { return .overBudget }
        return spent / limit >= 0.8 ? .nearLimit : .onTrack
    }

    /// "$120.00 of $400.00", or just "$120.00" without a limit.
    var amountsLabel: String {
        guard let limit else { return spent.asCurrency() }
        return "\(spent.asCurrency()) of \(limit.asCurrency())"
    }

    /// "$280.00 left", "$30.00 over", or "No limit".
    var statusLabel: String {
        guard let remaining else { return "No limit" }
        return remaining >= 0 ? "\(remaining.asCurrency()) left" : "\((-remaining).asCurrency()) over"
    }
}

enum CategoryBudgetSummary {

    /// Every category: ones with a limit first (most used first), then the rest (biggest spend first).
    static func rows(expenses: [ExpenseItem], limits: [ExpenseCategory: Double],
                     now: Date, calendar: Calendar) -> [CategoryBudgetRow] {
        let month = calendar.dateInterval(of: .month, for: now)
        var spent: [ExpenseCategory: Double] = [:]
        for item in expenses where month?.contains(item.date) ?? false {
            spent[item.categoryKind, default: 0] += item.amount
        }
        let rows = ExpenseCategory.allCases.map {
            CategoryBudgetRow(category: $0, spent: spent[$0] ?? 0, limit: limits[$0])
        }
        let limited = rows.filter { $0.limit != nil }
            .sorted { ($0.spent / $0.limit!, $1.category.name) > ($1.spent / $1.limit!, $0.category.name) }
        let unlimited = rows.filter { $0.limit == nil }
            .sorted { ($0.spent, $1.category.name) > ($1.spent, $0.category.name) }
        return limited + unlimited
    }

    /// Sum of all category limits (to compare with the monthly budget).
    static func totalOfLimits(_ limits: [ExpenseCategory: Double]) -> Double {
        limits.values.reduce(0, +)
    }
}
