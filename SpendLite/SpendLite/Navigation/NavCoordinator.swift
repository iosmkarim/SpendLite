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
        case add
        case insights
        case history
        case settings
    }

    @Published var selectedTab: Tab = .home

    // MARK: - Navigation API
    func goToInsights() {
        selectedTab = .insights
    }

    /// "See All" transactions lives in the History tab.
    func goToTransactions() {
        selectedTab = .history
    }
}
