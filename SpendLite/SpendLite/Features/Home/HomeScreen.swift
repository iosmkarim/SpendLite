//
//  HomeScreen.swift
//  SpendLite
//
//  Created by Md Rezaul Karim on 11/14/25.
//

import SwiftUI

struct HomeScreen: View {
    
    @EnvironmentObject private var nav: NavCoordinator
    @State private var showingAddExpense = false
    @State private var showingBudgetEditor = false
    @State private var budgetText = ""
    @StateObject private var viewModel: HomeViewModel
    private let expenses: ExpenseRepository
    private let recurring: RecurringExpenseRepository?

    init(expense: ExpenseRepository, budget: BudgetRepository, recurring: RecurringExpenseRepository? = nil) {
        self.expenses = expense
        self.recurring = recurring
        _viewModel = StateObject(wrappedValue: HomeViewModel(expenses: expense, budget: budget))
    }

    private func openAddIfRequested() {
        guard nav.addExpenseRequested else { return }
        nav.addExpenseRequested = false
        showingAddExpense = true
    }

    private func startEditingBudget() {
        let current = viewModel.summary?.monthlyBudget ?? 0
        budgetText = current > 0 ? current.formatted(.number.grouping(.never)) : ""
        showingBudgetEditor = true
    }

    private func saveBudget() {
        let cleaned = budgetText.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        if let value = Double(cleaned), value > 0 {
            viewModel.setMonthlyBudget(value)
        }
    }
    
    private var populatedHome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HeaderSectionView(
                    name: "",
                    subtitle: "Here is a quick look at your spending"
                )
                .padding(.horizontal)

                // Budget card
                BudgetCardView(summary: viewModel.summary, onEdit: startEditingBudget)
                    .padding(.horizontal)

                // Quick actions
                QuickActionsGridView(
                    onAddExpense: { showingAddExpense = true },
                    onInsights: { nav.goToInsights() }
                )
                .padding(.horizontal)

                // Recent transactions
                if !viewModel.recentExpenses.isEmpty {
                    RecentTransactionsSectionView(
                        expenses: viewModel.recentExpenses,
                        onSeeAll: { nav.goToTransactions() }
                    )
                    .padding(.horizontal)
                }

                Spacer(minLength: 12)
            }
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground)
    }
    
    // No NavigationStack here: the Home tab already provides one (TabShellView.makeTab).
    var body: some View {
        Group {
            if viewModel.hasAnyExpense {
                populatedHome
            } else {
                EmptyHomeView(
                    onAddExpense: {
                        showingAddExpense = true
                    },
                    onAddSampleData: {
                        viewModel.addSampleData()
                    },
                    isAddingSampleData: viewModel.isAddingSampleData
                )
            }
        }
        // The widget's "Add expense" button opens the form straight away.
        .onAppear(perform: openAddIfRequested)
        .onChange(of: nav.addExpenseRequested) { _, _ in openAddIfRequested() }
        .sheet(isPresented: $showingAddExpense) {
            // A sheet is a new presentation, so it needs its own stack for the title and toolbar.
            NavigationStack {
                AddExpenseAmountOnlyView(expenses: expenses, recurring: recurring, isPresentedAsSheet: true)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Monthly Budget", isPresented: $showingBudgetEditor) {
            TextField("Amount", text: $budgetText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            Button("Save", action: saveBudget)
        } message: {
            Text("How much do you want to spend each month?")
        }
        .alert(
            "Couldn't add sample data",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        // The greeting header acts as the page title, so hide the (empty) nav bar.
        .toolbar(.hidden, for: .navigationBar)
    }
}
    
    /// Empty-state Home Screen - matches the UX idea
private struct EmptyHomeView: View {
    
    let onAddExpense: () -> Void
    let onAddSampleData: () -> Void
    let isAddingSampleData: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "creditcard")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.blue)
            
            VStack(spacing: 8) {
                Text("No expenses yet")
                    .font(.title2).bold()
                Text("Add your first expense to see insights and track your budget.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: onAddExpense) {
                Text("Add Expense")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.white)
                    .heroCardStyle(cornerRadius: 16)
            }
            .padding(.horizontal, 32)
            
            Button(action: onAddSampleData) {
                HStack(spacing: 8) {
                    if isAddingSampleData {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Add sample data")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            // Blocks double-taps while the save is in flight.
            .disabled(isAddingSampleData)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
    

//HEADER VIEW
private struct HeaderSectionView: View {
    let name: String
    let subtitle: String
    
    /// "Good Morning, Sam" — or just "Good Morning" when there's no name (no dangling comma).
    private func title(at date: Date) -> String {
        let greeting = Greeting.text(for: date)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? greeting : "\(greeting), \(trimmed)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Re-evaluates each minute so the greeting changes while the app stays open.
                TimelineView(.everyMinute) { context in
                    Text(title(at: context.date))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                }
                
                Text("👋")
                    .font(.title)
                    .accessibilityHidden(true) // decorative; VoiceOver would read "waving hand"
            }
            
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
    
//Budget card view
private struct BudgetCardView: View {
    let summary: HomeSummary?
    let onEdit: () -> Void

    // MARK: - Derived values (all budget maths lives in HomeSummary)
    private var spent: Double { summary?.totalSpent ?? 0 }
    private var status: HomeSummary.Status { summary?.status ?? .onTrack }

    /// Share of the budget spent for the ring (0...1). It fills up as you spend; full when over.
    private var spentProgress: Double {
        min(1, max(0, summary?.progress ?? 0))
    }

    private var spentLabel: String {
        summary?.percentSpentLabel ?? "0%"
    }

    private var totalSpentLabel: some View {
        Text("Total Spent")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    /// "$7.25 of $2,000.00" — the budget itself wasn't shown anywhere before.
    private var totalSpentValue: some View {
        HStack(spacing: 4) {
            Text(spent.asCurrency())
                .foregroundStyle(.primary)
            Text("of \((summary?.monthlyBudget ?? 0).asCurrency())")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.semibold))
        .fixedSize()
    }

    /// "November Budget" — makes it clear the numbers reset each month.
    /// Home re-renders when the day changes (HomeViewModel), so this rolls over on the 1st.
    private var title: String {
        "\(Date.now.formatted(.dateTime.month(.wide))) Budget"
    }

    /// Big number: what's left, or how much over budget.
    private var headlineAmount: Double {
        guard let summary else { return 0 }
        return summary.isOverBudget ? summary.amountOver : summary.remainingClamped
    }

    /// Ring colour: brand purple while on track, then orange / red as a warning.
    private var statusColor: Color {
        switch status {
        case .onTrack: return .brand
        case .nearLimit: return .orange
        case .overBudget: return .red
        }
    }

    var body: some View {
        VStack(spacing: 14) {

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Button(action: onEdit) {
                        HStack(spacing: 6) {
                            Text(title)
                            Image(systemName: "pencil")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit monthly budget")
                    .accessibilityIdentifier("home.budget.edit")

                    Text(headlineAmount.asCurrency())
                        .font(.largeTitle.bold())
                        .foregroundStyle(status == .overBudget ? Color.red : Color.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if status == .overBudget {
                        Label("over budget", systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: UIColor(hex: 0xE5484D)), in: Capsule())
                    } else {
                        Text("remaining")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if status == .nearLimit {
                        Label("Close to your limit", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                ProgressRingView(progress: spentProgress, label: spentLabel, caption: "spent", color: statusColor)
                    .frame(width: 76, height: 76)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(spentLabel) of budget spent")
            }

            // Side by side when it fits; stacked at large text sizes instead of truncating.
            ViewThatFits(in: .horizontal) {
                HStack {
                    totalSpentLabel
                    Spacer()
                    totalSpentValue
                }
                VStack(alignment: .leading, spacing: 4) {
                    totalSpentLabel
                    totalSpentValue
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.insetBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(20)
        .cardStyle(cornerRadius: 24)
    }
}

// ProgressRingView
private struct ProgressRingView: View {
    let progress: Double //0...1
    let label: String
    var caption: String? = nil
    var color: Color = .green

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .foregroundStyle(Color.brand.opacity(0.12))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .foregroundStyle(color)

            VStack(spacing: 0) {
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(.horizontal, 10)
            // The ring is a fixed-size graphic, so cap its text size; VoiceOver reads the full value.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
        }
        .animation(.easeInOut(duration: 0.35), value: progress)
    }
}

//QuickActionsGridView

private struct QuickActionsGridView: View {
    let onAddExpense: () -> Void
    let onInsights: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            QuickActionCard(
                icon: "plus",
                iconForeground: .brand,
                title: "Add Expense",
                subtitle: "Record new spending",
                onTap: onAddExpense
            )
            .accessibilityIdentifier("home.quickAction.addExpense")

            QuickActionCard(
                icon: "chart.bar.xaxis",
                iconForeground: .pink,
                title: "View Insights",
                subtitle: "Analyze spending",
                onTap: onInsights
            )
            .accessibilityIdentifier("home.quickAction.insights")
        }
    }
}

//QuickActionCard

private struct QuickActionCard: View {
    let icon: String
    let iconForeground: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconForeground)
                    .iconTile(iconForeground)
                .accessibilityHidden(true) // decorative icon

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Wraps naturally instead of a hand-placed "\n", so it adapts to
                // larger text sizes and other languages.
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .cardStyle()
            // Makes the whole card the tap target (not just the visible content).
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}


//Recent transactions section view

private struct RecentTransactionsSectionView: View {
    let expenses: [ExpenseItem]
    let onSeeAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.title3.bold())
                
                Spacer()
                
                Button("See All", action: onSeeAll)
                    .font(.subheadline.weight(.semibold))
            }
            
            VStack(spacing: 12) {
                ForEach(expenses.prefix(5)) { item in
                    TransactionRowView(item: item)
                }
            }
        }
        .padding(.top, 10)
    }
}

#Preview("With expenses") {
    let container = AppContainer.preview()
    NavigationStack {
        HomeScreen(expense: container.expenses, budget: container.budget)
    }
    .environmentObject(NavCoordinator())
}

#Preview("Empty") {
    let container = AppContainer(inMemory: true)
    NavigationStack {
        HomeScreen(expense: container.expenses, budget: container.budget)
    }
    .environmentObject(NavCoordinator())
}
