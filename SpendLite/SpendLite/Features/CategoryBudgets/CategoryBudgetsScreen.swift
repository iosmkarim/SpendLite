//
//  CategoryBudgetsScreen.swift
//  SpendLite
//

import SwiftUI

/// Settings → Category budgets. Tap a category to set, change or remove its monthly limit.
struct CategoryBudgetsScreen: View {
    @StateObject private var viewModel: CategoryBudgetsViewModel
    @State private var editing: ExpenseCategory?
    @State private var limitText = ""

    init(expenses: ExpenseRepository, budget: BudgetRepository, categoryBudgets: CategoryBudgetRepository) {
        _viewModel = StateObject(wrappedValue: CategoryBudgetsViewModel(
            expenses: expenses, budget: budget, categoryBudgets: categoryBudgets))
    }

    var body: some View {
        List {
            SummaryCard(total: viewModel.totalOfLimits, monthlyBudget: viewModel.monthlyBudget,
                        exceeds: viewModel.limitsExceedBudget, hasLimits: !viewModel.limits.isEmpty)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            ForEach(viewModel.rows) { row in
                Button {
                    limitText = row.limit.map { AddExpenseViewModel.amountText(for: $0) } ?? ""
                    editing = row.category
                } label: {
                    CategoryBudgetRowView(row: row)
                }
                .buttonStyle(.pressableCard)
                .accessibilityHint(row.limit == nil ? "Double-tap to set a limit" : "Double-tap to change the limit")
                .accessibilityIdentifier("categoryBudget.\(row.category.rawValue)")
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Category budgets")
        .navigationBarTitleDisplayMode(.large)
        .alert(
            editing.map { "\($0.name) limit" } ?? "",
            isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } }),
            presenting: editing
        ) { category in
            TextField("Monthly limit", text: $limitText)
                .keyboardType(.decimalPad)
            Button("Save") { viewModel.setLimit(from: limitText, for: category) }
            if viewModel.limits[category] != nil {
                Button("Remove Limit", role: .destructive) { viewModel.removeLimit(for: category) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { category in
            Text("How much do you want to spend on \(category.name.lowercased()) each month? Leave empty for no limit.")
        }
    }
}

// MARK: - Pieces

private struct SummaryCard: View {
    let total: Double
    let monthlyBudget: Double
    let exceeds: Bool
    let hasLimits: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if hasLimits {
                Text("Limits add up to")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(total.asCurrency())
                    .font(.largeTitle.bold())
                Text("of your \(monthlyBudget.asCurrency()) monthly budget")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if exceeds {
                    Label("More than your monthly budget, so they can't all be met.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                }
            } else {
                Text("Set a limit for any category")
                    .font(.headline)
                Text("For example, $400 a month for food. Tap a category below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("categoryBudgets.summary")
    }
}

private struct CategoryBudgetRowView: View {
    let row: CategoryBudgetRow

    private var statusColor: Color {
        switch row.status {
        case .overBudget: .red
        case .nearLimit: .orange
        case .onTrack: .green
        case nil: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.category.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(row.category.color)
                .iconTile(row.category.color)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(row.category.name)
                        .font(.headline)
                    Spacer()
                    Text(row.statusLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(row.limit == nil ? Color.secondary : statusColor)
                }
                if let progress = row.progress {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.insetBackground)
                            Capsule()
                                .fill(statusColor)
                                .frame(width: max(6, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 6)
                }
                Text(row.amountsLabel + " this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.category.name), \(row.amountsLabel) this month, \(row.statusLabel)")
    }
}
