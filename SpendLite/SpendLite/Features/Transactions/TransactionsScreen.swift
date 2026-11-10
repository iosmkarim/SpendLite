//
//  TransactionsScreen.swift
//  SpendLite
//

import SwiftUI

/// The Transactions tab: every expense grouped by month with a monthly total.
/// Search and filter (category, date range); tap a row to edit it, swipe left to delete (with Undo), + to add.
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
                if viewModel.filter.isActive {
                    noMatchesState
                } else {
                    emptyState
                }
            } else {
                list
            }
        }
        .searchable(
            text: $viewModel.filter.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search description, category or amount"
        )
        // Insights ("show Food") and Home ("See All") ask for a view via NavCoordinator;
        // apply the request once, then clear it so the user can change filters freely.
        .onAppear(perform: applyNavigationRequest)
        .onChange(of: nav.transactionsRequest) { _, _ in applyNavigationRequest() }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
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

    private func applyNavigationRequest() {
        guard let request = nav.transactionsRequest else { return }
        withAnimation(.snappy) {
            switch request {
            case .showAll: viewModel.clearAll()
            case .category(let category): viewModel.showOnly(category)
            }
        }
        nav.transactionsRequest = nil
    }

    // MARK: - Filter menu

    private var filterMenu: some View {
        Menu {
            Picker("Date", selection: $viewModel.filter.dateRange) {
                ForEach(TransactionFilter.DateRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.inline)

            Section("Categories") {
                ForEach(ExpenseCategory.allCases) { category in
                    Toggle(isOn: Binding(
                        get: { viewModel.filter.categories.contains(category) },
                        set: { _ in viewModel.toggle(category) }
                    )) {
                        Label(category.name, systemImage: category.systemImage)
                    }
                }
            }

            if viewModel.filter.hasFilters {
                Button("Clear filters", systemImage: "xmark.circle", role: .destructive) {
                    withAnimation(.snappy) { viewModel.clearFilters() }
                }
            }
        } label: {
            Label(
                "Filter",
                systemImage: viewModel.filter.hasFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityIdentifier("transactions.filterMenu")
        .accessibilityValue(viewModel.filter.hasFilters ? "Filters on" : "No filters")
    }

    // MARK: - List

    private var list: some View {
        List {
            if viewModel.filter.isActive {
                ActiveFiltersBar(
                    filter: viewModel.filter,
                    resultCount: viewModel.resultCount,
                    resultTotal: viewModel.resultTotal,
                    onRemoveCategory: { category in withAnimation(.snappy) { viewModel.toggle(category) } },
                    onRemoveDateRange: { withAnimation(.snappy) { viewModel.filter.dateRange = .allTime } },
                    onClearAll: { withAnimation(.snappy) { viewModel.clearAll() } }
                )
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

    private var noMatchesState: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "magnifyingglass")
        } description: {
            Text(noMatchesDescription)
        } actions: {
            Button("Clear search and filters") {
                withAnimation(.snappy) { viewModel.clearAll() }
            }
            .accessibilityIdentifier("transactions.noMatches.clear")
        }
        .frame(maxHeight: .infinity)
    }

    private var noMatchesDescription: String {
        let search = viewModel.filter.searchText.trimmingCharacters(in: .whitespaces)
        return search.isEmpty
            ? "No expenses match these filters."
            : "No expenses match \u{201C}\(search)\u{201D}\(viewModel.filter.hasFilters ? " with these filters" : "")."
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

/// Active filters as removable chips, plus "3 results · $45.20".
private struct ActiveFiltersBar: View {
    let filter: TransactionFilter
    let resultCount: Int
    let resultTotal: Double
    let onRemoveCategory: (ExpenseCategory) -> Void
    let onRemoveDateRange: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if filter.hasFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if filter.dateRange != .allTime {
                            Chip(title: filter.dateRange.title, systemImage: "calendar", color: .brand,
                                 action: onRemoveDateRange)
                                .accessibilityIdentifier("transactions.filter.dateRange")
                        }
                        ForEach(ExpenseCategory.allCases.filter(filter.categories.contains)) { category in
                            Chip(title: category.name, systemImage: category.systemImage, color: category.color) {
                                onRemoveCategory(category)
                            }
                            .accessibilityIdentifier("transactions.filter.category.\(category.rawValue)")
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            HStack {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("transactions.resultSummary")
                Spacer()
                Button("Clear all", action: onClearAll)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.brand)
                    .accessibilityIdentifier("transactions.filter.clear")
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }

    private var summary: String {
        "\(resultCount) \(resultCount == 1 ? "result" : "results") · \(resultTotal.asCurrency())"
    }
}

/// A removable filter chip: "🍴 Food ✕".
private struct Chip: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(color.opacity(0.6))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filter. Remove")
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
