//
//  TabShellView.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/13/25.
//

import SwiftUI
import Combine

/// Root tab bar. Each tab owns exactly one NavigationStack (created in `makeTab`);
/// screens inside a tab must not create their own.
struct TabShellView: View {
    @StateObject private var nav = NavCoordinator()
    @Environment(\.container) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var generation: AnyCancellable?
    /// Amounts are formatted with `Currency.code`; rebuilding the tabs when it changes
    /// updates every amount on screen. The selected tab lives in `nav`, so it's kept.
    @AppStorage(AppSettings.Key.currencyCode) private var currencyCode: String = ""

    var body: some View {
        TabView(selection: $nav.selectedTab) {
            // Home
            makeTab(.home, title: "Home", systemImage: "house.fill", navTitle: "Home") {
                HomeScreen(expense: container.expenses, budget: container.budget, recurring: container.recurring)
            }

            // Transactions (adding lives on Home's card and the + here, so there's no Add tab)
            makeTab(.transactions, title: "Transactions", systemImage: "list.bullet.rectangle.fill", navTitle: "Transactions") {
                TransactionsScreen(expenses: container.expenses, recurring: container.recurring)
            }

            // Insights
            makeTab(.insights, title: "Insights", systemImage: "chart.pie.fill", navTitle: "Insights") {
                InsightsScreen(expense: container.expenses)
            }

            // Settings
            makeTab(.settings, title: "Settings", systemImage: "gearshape.fill", navTitle: "Settings") {
                SettingsScreen(expenses: container.expenses, budget: container.budget, recurring: container.recurring)
            }
        }
        .id(currencyCode)
        .environmentObject(nav)
        // Add any recurring expenses that came due while the app was closed or in the background.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            generation = container.recurring.generateDueExpenses(now: .now)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        }
    }

    private func makeTab<Content: View>(
        _ tab: NavCoordinator.Tab,
        title: String,
        systemImage: String,
        navTitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationTitle(navTitle)
        }
        .tabItem {
            Label(title, systemImage: systemImage)
        }
        .tag(tab)
    }
}
