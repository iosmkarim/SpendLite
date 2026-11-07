//
//  TabShellView.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/13/25.
//

import SwiftUI

struct TabShellView: View {
    @StateObject private var nav = NavCoordinator()
    @Environment(\.container) private var container
    var body: some View {
        NavigationStack(path: $nav.path) {
            TabView {
                // Home
                makeTab(
                    title: "Home",
                    systemImage: "house.fill",
                    navTitle: "SpendLite") {
                        HomeScreen(expense: container.expenses)
                    }

                // Add expense
                makeTab(
                    title: "Add",
                    systemImage: "plus.circle.fill",
                    navTitle: "Add Expense") {
                        AddExpenseAmountOnlyView { amount, description, category, date in
                            // TODO: persist the expense via your repository/view model
                        }
                    }

                //Insights
                makeTab(
                    title: "Insights",
                    systemImage: "chart.pie.fill",
                    navTitle: "Insights") {
                        InsightsScreen(expense: container.expenses)
                    }

                //History
                makeTab(
                    title: "History",
                    systemImage: "clock.arrow.circlepath",
                    navTitle: "History") {
                        Text("History")
                            .font(.title)
                    }

                //Settings
                makeTab(
                    title: "Settings",
                    systemImage: "gearshape.fill",
                    navTitle: "Settings") {
                        Text("Settings")
                            .font(.title)
                    }
            }
            .navigationDestination(for: NavCoordinator.Route.self) { route in
                switch route {
                case .insights:
                    Text("Insights")
                        .font(.title)
                        .navigationTitle("Insights")
                case .transactions:
                    Text("All Transactions")
                        .font(.title)
                        .navigationTitle("Transactions")
                }
            }
        }
        .environmentObject(nav)
    }
    
    private func makeTab<Content: View>(
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
    }
}

