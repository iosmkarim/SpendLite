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
    @StateObject private var viewModel: HomeViewModel
    
    static let creamBackground: Color = Color(red: 0.98, green: 0.96, blue: 0.90) // soft cream
    
    init(expense: ExpenseRepository) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(expenses: expense))
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
                BudgetCardView(summary: viewModel.summary)
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
    
    var body: some View {
        NavigationStack {
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
                        }
                    )
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseAmountOnlyView { amount, description, category, date in
                    // TODO: persist the expense via your repository/view model
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            // Navigation bar appearance: make it non-translucent/solid even at scroll edge
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
    
    /// Empty-state Home Screen - matches the UX idea
private struct EmptyHomeView: View {
    
    let onAddExpense: () -> Void
    let onAddSampleData: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            //Icon placeholder
            
            Image(systemName: "creditCard")
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
                Text("Add sample data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Good Evening, \(name)")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                
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

    // MARK: - Derived values (keep type-checking simple)
    private var budget: Double { summary?.monthlyBudget ?? 0 }
    private var spent: Double { summary?.totalSpent ?? 0 }
    private var remaining: Double { max(0, budget - spent) }

    /// progress for "remaining" ring (0...1)
    private var remainingProgress: Double {
        guard budget > 0 else { return 0 }
        let value = remaining / budget
        return min(1, max(0, value))
    }

    private var remainingLabel: String {
        "\(Int(remainingProgress * 100))%"
    }

    var body: some View {
        VStack(spacing: 14) {

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Monthly Budget")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(remaining.asCurrency())
                        .font(.title.bold())
                        .foregroundStyle(.primary)

                    Text("remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressRingView(progress: remainingProgress, label: remainingLabel)
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
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .foregroundStyle(Color(.systemGray5))
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .foregroundStyle(.green)
            
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
            
            QuickActionCard(
                icon: "chart.bar.xaxis",
                iconBackground: Color.purple.opacity(0.12),
                iconForeground: .purple,
                title: "View Insights",
                subtitle: "Analyze \nspending",
                onTap: onInsights
            )
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
    HomeScreen(expense: AppContainer(inMemory: true).expenses)
}
