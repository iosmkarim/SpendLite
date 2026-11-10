//
//  TransactionsScreen.swift
//  SpendLite
//

import SwiftUI

/// The Transactions tab: every expense grouped by month with a monthly total.
/// Tap a row to edit it, swipe left to delete (with Undo), + to add.
struct TransactionsScreen: View {
    @StateObject private var viewModel: TransactionsViewModel
    @EnvironmentObject private var nav: NavCoordinator
    @State private var activeSheet: Sheet?

    private let expenses: ExpenseRepository

    init(expenses: ExpenseRepository) {
        self.expenses = expenses
        _viewModel = StateObject(wrappedValue: TransactionsViewModel(expenses: expenses))
    }

    /// Add and Edit share one form; which one is open is a single piece of state.
    private enum Sheet: Identifiable {
        case add
        case edit(ExpenseItem)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let item): item.id.uuidString
            }
        }
    }

    var body: some View {
        // The list must stay the root scroll view, or the large "Transactions" title disappears;
        // that's why the filter chip is a row inside the list rather than above it.
        Group {
            if viewModel.isEmpty {
                if let filter = viewModel.categoryFilter {
                    filteredEmptyState(filter)
                } else {
                    emptyState
                }
            } else {
                list
            }
        }
        // The filter lives in NavCoordinator so Insights can set it before switching tabs.
        .onAppear { viewModel.categoryFilter = nav.transactionsFilter }
        .onChange(of: nav.transactionsFilter) { _, newValue in
            withAnimation(.snappy) { viewModel.categoryFilter = newValue }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    activeSheet = .add
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }
                .accessibilityIdentifier("transactions.add")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .add:
                    AddExpenseAmountOnlyView(expenses: expenses, isPresentedAsSheet: true)
                case .edit(let item):
                    AddExpenseAmountOnlyView(expenses: expenses, editing: item, isPresentedAsSheet: true)
                }
            }
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .bottom) {
            if let deleted = viewModel.recentlyDeleted {
                UndoBanner(title: deleted.title, onUndo: viewModel.undoDelete)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // Auto-hide after a few seconds; restarts if another item is deleted.
                    .task(id: deleted.id) {
                        try? await Task.sleep(for: .seconds(4))
                        guard !Task.isCancelled else { return }
                        withAnimation { viewModel.dismissUndo() }
                    }
            }
        }
        .animation(.snappy, value: viewModel.recentlyDeleted)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if let filter = viewModel.categoryFilter {
                FilterBar(category: filter) { nav.transactionsFilter = nil }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        row(for: item)
                    }
                } header: {
                    SectionHeader(section: section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("transactions.list")
    }

    private func row(for item: ExpenseItem) -> some View {
        Button {
            activeSheet = .edit(item)
        } label: {
            TransactionRowView(item: item)
        }
        .buttonStyle(.pressableCard)
        .accessibilityHint("Double-tap to edit")
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        // Same actions for people who don't swipe (long press, VoiceOver actions menu).
        .contextMenu {
            Button {
                activeSheet = .edit(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                viewModel.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityAction(named: "Delete") { viewModel.delete(item) }
    }

    // MARK: - Empty states

    private func filteredEmptyState(_ category: ExpenseCategory) -> some View {
        ContentUnavailableView {
            Label("No \(category.name) expenses", systemImage: category.systemImage)
        } description: {
            Text("Nothing in this category yet.")
        } actions: {
            Button("Show all") { nav.transactionsFilter = nil }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No transactions yet", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Expenses you add will show up here, grouped by month.")
        } actions: {
            Button("Add Expense") { activeSheet = .add }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Pieces

/// "Showing: 🍴 Food ✕" above the list when a category filter is on.
private struct FilterBar: View {
    let category: ExpenseCategory
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Showing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: onClear) {
                HStack(spacing: 6) {
                    Image(systemName: category.systemImage)
                    Text(category.name)
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(category.color.opacity(0.6))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(category.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(category.color.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filtered to \(category.name). Clear filter")
            .accessibilityIdentifier("transactions.filter.clear")
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

private struct SectionHeader: View {
    let section: TransactionSection

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(section.title)
            Spacer()
            Text(section.total.asCurrency())
                .monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(nil)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(section.title), total spent \(section.total.asCurrency())")
        .accessibilityAddTraits(.isHeader)
    }
}

private struct UndoBanner: View {
    let title: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Deleted \u{201C}\(title)\u{201D}")
                .lineLimit(1)
            Spacer()
            Button("Undo", action: onUndo)
                .fontWeight(.semibold)
                .accessibilityIdentifier("transactions.undo")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

#Preview("With expenses") {
    NavigationStack {
        TransactionsScreen(expenses: AppContainer.preview().expenses)
    }
    .environmentObject(NavCoordinator())
}

#Preview("Empty") {
    NavigationStack {
        TransactionsScreen(expenses: AppContainer(inMemory: true).expenses)
    }
    .environmentObject(NavCoordinator())
}
