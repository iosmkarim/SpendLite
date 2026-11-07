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

    static let creamBackground: Color = Color(red: 0.98, green: 0.96, blue: 0.90) // soft cream

    init(expense: ExpenseRepository, budget: BudgetRepository) {
        self.expenses = expense
        _viewModel = StateObject(wrappedValue: HomeViewModel(expenses: expense, budget: budget))
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
        .background(Self.creamBackground)
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
        .onAppear {
            viewModel.onAppear()
        }
        .sheet(isPresented: $showingAddExpense) {
            // A sheet is a new presentation, so it needs its own stack for the title and toolbar.
            NavigationStack {
                AddExpenseAmountOnlyView(expenses: expenses, isPresentedAsSheet: true)
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
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .background(HomeScreen.creamBackground)
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

    /// Remaining share of the budget for the ring (0...1); empty when over budget.
    private var remainingProgress: Double {
        min(1, max(0, 1 - (summary?.progress ?? 0)))
    }

    private var remainingLabel: String {
        "\(Int(remainingProgress * 100))%"
    }

    /// Big number: what's left, or how much over budget.
    private var headlineAmount: Double {
        guard let summary else { return 0 }
        return summary.isOverBudget ? summary.amountOver : summary.remainingClamped
    }

    private var statusColor: Color {
        switch status {
        case .onTrack: return .green
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
                            Text("Monthly Budget")
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
                        .font(.title.bold())
                        .foregroundStyle(status == .overBudget ? Color.red : Color.primary)

                    Text(status == .overBudget ? "over budget" : "remaining")
                        .font(.subheadline)
                        .foregroundStyle(status == .overBudget ? Color.red : Color.secondary)

                    if status == .nearLimit {
                        Label("Close to your limit", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                ProgressRingView(progress: remainingProgress, label: remainingLabel, color: statusColor)
                    .frame(width: 72, height: 72)
            }

            HStack {
                Text("Total Spent")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(spent.asCurrency())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
    }
}

// ProgressRingView
private struct ProgressRingView: View {
    let progress: Double //0...1
    let label: String
    var color: Color = .green

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .foregroundStyle(Color(.systemGray5))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .foregroundStyle(color)
            
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
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
                iconBackground: Color.blue.opacity(0.12),
                iconForeground: .blue,
                title: "Add Expense",
                subtitle: "Record new\nspending",
                onTap: onAddExpense
            )
            .accessibilityIdentifier("home.quickAction.addExpense")

            QuickActionCard(
                icon: "chart.bar.xaxis",
                iconBackground: Color.purple.opacity(0.12),
                iconForeground: .purple,
                title: "View Insights",
                subtitle: "Analyze \nspending",
                onTap: onInsights
            )
            .accessibilityIdentifier("home.quickAction.insights")
        }
    }
}

//QuickActionCard

private struct QuickActionCard: View {
    let icon: String
    let iconBackground: Color
    let iconForeground: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
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

//Transaction Row View

private struct TransactionRowView: View {
    let item : ExpenseItem
    
    // TEMP: category/icon mapping (later from model)
    private var categoryText: String { "Food & Drink" }
    private var iconName: String { "fork.knife" }
    private var iconBg: Color { Color.orange.opacity(0.12)}
    private var iconFg: Color { .orange }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconFg)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(categoryText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            Text("-\(item.amount.asCurrency())")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 5)
    }
}

// Double extension

private extension Double {
    func asCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "$0"
    }
}

// Decimal extension

private extension Decimal {
    func asCurrencyDecimal() -> String {
        let ns = self as NSDecimalNumber
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: ns) ?? "$0"
    }
}

private struct AddExpensePlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Add Expense")
                    .font(.title2.bold())
                Text("This is a placeholder. We'll add the real form next.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let container = AppContainer(inMemory: true)
    NavigationStack {
        HomeScreen(expense: container.expenses, budget: container.budget)
    }
    .environmentObject(NavCoordinator())
}
