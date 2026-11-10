//
//  NavCoordinator.swift
//  SpendLite
//

import SwiftUI
import Combine

/// App-wide navigation state. Owns which tab is selected so any screen can
/// jump to another tab (e.g. Home's "View Insights" → Insights tab).
final class NavCoordinator: ObservableObject {
    enum Tab: Hashable {
        case home
        case transactions
        case insights
        case settings
    }

    @Published var selectedTab: Tab = .home

    /// Category the Transactions tab is filtered to (set from Insights), or nil for all.
    @Published var transactionsFilter: ExpenseCategory?

    // MARK: - Navigation API
    func goToInsights() {
        selectedTab = .insights
    }

    /// Home's "See All" opens the full list.
    func goToTransactions() {
        transactionsFilter = nil
        selectedTab = .transactions
    }

    /// Insights → tap a category: open Transactions showing only that category.
    func goToTransactions(category: ExpenseCategory) {
        transactionsFilter = category
        selectedTab = .transactions
    }
}
