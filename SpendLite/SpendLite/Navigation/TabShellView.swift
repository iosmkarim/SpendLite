//
//  TabShellView.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/13/25.
//

import SwiftUI

/// Root tab bar. Each tab owns exactly one NavigationStack (created in `makeTab`);
/// screens inside a tab must not create their own.
struct TabShellView: View {
    @StateObject private var nav = NavCoordinator()
    @Environment(\.container) private var container

    var body: some View {
        TabView(selection: $nav.selectedTab) {
            // Home
            makeTab(.home, title: "Home", systemImage: "house.fill", navTitle: "Home") {
                HomeScreen(expense: container.expenses)
            }

            // Add expense
            makeTab(.add, title: "Add", systemImage: "plus.circle.fill", navTitle: "Add Expense") {
                AddExpenseAmountOnlyView(expenses: container.expenses) {
                    // After saving from the tab, go back Home to see it in Recent Transactions.
                    nav.selectedTab = .home
                }
            }

            // Insights
            makeTab(.insights, title: "Insights", systemImage: "chart.pie.fill", navTitle: "Insights") {
                InsightsScreen(expense: container.expenses)
            }

            // History
            makeTab(.history, title: "History", systemImage: "clock.arrow.circlepath", navTitle: "History") {
                Text("History")
                    .font(.title)
            }

            // Settings
            makeTab(.settings, title: "Settings", systemImage: "gearshape.fill", navTitle: "Settings") {
                Text("Settings")
                    .font(.title)
            }
        }
        .environmentObject(nav)
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
