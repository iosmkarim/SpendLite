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

    /// What another screen asked the Transactions tab to show. The Transactions screen
    /// applies it to its own filter and then clears it (so the user can change filters freely).
    enum TransactionsRequest: Equatable {
        case showAll
        case category(ExpenseCategory)
    }
    @Published var transactionsRequest: TransactionsRequest?

    /// Set when the widget's "Add expense" opens the app; Home shows the form and clears it.
    @Published var addExpenseRequested = false

    /// Handles links from the widget: spendlite://add and spendlite://home.
    func handle(_ url: URL) {
        guard url.scheme == "spendlite" else { return }
        selectedTab = .home
        if url.host == "add" {
            addExpenseRequested = true
        }
    }

    // MARK: - Navigation API
    func goToInsights() {
        selectedTab = .insights
    }

    /// Home's "See All" opens the full list.
    func goToTransactions() {
        transactionsRequest = .showAll
        selectedTab = .transactions
    }

    /// Insights → tap a category: open Transactions showing only that category.
    func goToTransactions(category: ExpenseCategory) {
        transactionsRequest = .category(category)
        selectedTab = .transactions
    }
}
