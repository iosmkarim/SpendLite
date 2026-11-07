//
//  TransactionsScreen.swift
//  SpendLite
//

import SwiftUI

/// The Transactions tab: every expense grouped by month with a monthly total.
/// Tap a row to edit it, swipe left to delete (with Undo), + to add.
struct TransactionsScreen: View {
    @StateObject private var viewModel: TransactionsViewModel
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
        Group {
            if viewModel.isEmpty {
                emptyState
            } else {
                list
            }
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

    // MARK: - Empty state

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
}

#Preview("Empty") {
    NavigationStack {
        TransactionsScreen(expenses: AppContainer(inMemory: true).expenses)
    }
}
