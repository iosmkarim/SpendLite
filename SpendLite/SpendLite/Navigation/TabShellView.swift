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
    @AppStorage(AppSettings.Key.hasCompletedOnboarding) private var hasCompletedOnboarding = false

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
        .environmentObject(container.appLock)
        .environmentObject(container.notifications)
        // Lock screen on top of everything while locked; a plain cover in the app switcher.
        .overlay { AppLockGate(appLock: container.appLock, scenePhase: scenePhase) }
        // First launch: welcome → budget → start. Finishing sets the flag, which closes this.
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView(budget: container.budget, expenses: container.expenses, defaults: container.defaults) {
                nav.selectedTab = .home
            }
            .defaultAppStorage(container.defaults)
        }
        .onOpenURL { nav.handle($0) }
        .onChange(of: currencyCode) { _, _ in container.widgetSync?.refresh() }
        // Add any recurring expenses that came due while the app was closed or in the background.
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Lock when leaving for the background (not on .inactive, which is also what the
            // Face ID prompt itself causes). Ask again when coming back.
            if phase == .background { container.appLock.lock() }
            guard phase == .active else { return }
            // Keep reminders current (e.g. skip tonight's if something was logged by Siri).
            Task { await container.notifications.update() }
            if container.appLock.isLocked { Task { await container.appLock.unlock() } }
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
