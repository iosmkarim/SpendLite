//
//  RecurringListScreen.swift
//  SpendLite
//

import SwiftUI

/// Settings → Recurring expenses. Shows what repeats and roughly what it costs per month.
/// Tap to edit, swipe right to pause/resume, swipe left to stop, + to add.
struct RecurringListScreen: View {
    @StateObject private var viewModel: RecurringListViewModel
    @State private var editing: RecurringExpense?
    @State private var showingAdd = false
    @State private var pendingDelete: RecurringExpense?

    private let expenses: ExpenseRepository

    init(recurring: RecurringExpenseRepository, expenses: ExpenseRepository) {
        self.expenses = expenses
        _viewModel = StateObject(wrappedValue: RecurringListViewModel(recurring: recurring))
    }

    var body: some View {
        Group {
            if viewModel.hasLoaded && viewModel.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Recurring")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Label("Add recurring expense", systemImage: "plus")
                }
                .accessibilityIdentifier("recurring.add")
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                AddExpenseAmountOnlyView(
                    expenses: expenses,
                    recurring: viewModel.repository,
                    initialRepeat: .monthly,
                    isPresentedAsSheet: true
                )
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editing) { item in
            NavigationStack {
                RecurringEditView(item: item, nextDate: viewModel.nextDate(of: item)) { updated in
                    if updated.isPaused != item.isPaused {
                        // Pausing/resuming goes through the view model so resume skips missed dates.
                        var edited = updated
                        edited.isPaused = item.isPaused
                        viewModel.setPaused(edited, updated.isPaused)
                    } else {
                        viewModel.save(updated)
                    }
                } onDelete: {
                    pendingDelete = item
                }
            }
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Stop repeating \u{201C}\(pendingDelete?.title ?? "")\u{201D}?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { item in
            Button("Stop Repeating", role: .destructive) {
                editing = nil
                viewModel.delete(item)
            }
        } message: { _ in
            Text("Expenses it already added stay in Transactions.")
        }
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
            SummaryCard(
                monthlyTotal: viewModel.monthlyTotal,
                activeCount: viewModel.activeCount,
                pausedCount: viewModel.pausedCount
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(viewModel.items) { item in
                Button { editing = item } label: {
                    RecurringRow(item: item, nextDate: viewModel.nextDate(of: item))
                }
                .buttonStyle(.pressableCard)
                .accessibilityHint("Double-tap to edit")
                .accessibilityIdentifier("recurring.row.\(item.title)")
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .leading) {
                    Button {
                        viewModel.setPaused(item, !item.isPaused)
                    } label: {
                        Label(item.isPaused ? "Resume" : "Pause",
                              systemImage: item.isPaused ? "play.fill" : "pause.fill")
                    }
                    .tint(item.isPaused ? .green : .orange)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDelete = item
                    } label: {
                        Label("Stop", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(item.isPaused ? "Resume" : "Pause",
                           systemImage: item.isPaused ? "play.fill" : "pause.fill") {
                        viewModel.setPaused(item, !item.isPaused)
                    }
                    Button("Stop repeating", systemImage: "trash", role: .destructive) {
                        pendingDelete = item
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No recurring expenses", systemImage: "arrow.triangle.2.circlepath")
        } description: {
            Text("Add rent, subscriptions or bills once and they're added automatically every week, month or year.")
        } actions: {
            Button("Add Recurring Expense") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Pieces

private struct SummaryCard: View {
    let monthlyTotal: Double
    let activeCount: Int
    let pausedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About per month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(monthlyTotal.asCurrency())
                .font(.largeTitle.bold())
            Text(countsText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recurring.summary")
    }

    private var countsText: String {
        let active = "\(activeCount) active"
        return pausedCount > 0 ? "\(active) · \(pausedCount) paused" : active
    }
}

private struct RecurringRow: View {
    let item: RecurringExpense
    let nextDate: Date

    private var category: ExpenseCategory { item.categoryKind }

    private var schedule: String {
        item.isPaused
            ? "\(item.frequency.title) · Paused"
            : "\(item.frequency.title) · Next \(Self.shortDate(nextDate))"
    }

    /// "Dec 10", or "Nov 10, 2027" when it isn't this year (so a yearly one doesn't look like next week).
    static func shortDate(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        calendar.isDate(date, equalTo: now, toGranularity: .year)
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(category.color)
                .iconTile(category.color)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: item.isPaused ? "pause.circle.fill" : "arrow.triangle.2.circlepath")
                        .foregroundStyle(item.isPaused ? Color.orange : Color.brand)
                    Text(schedule)
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.medium))
            }

            Spacer()

            Text(item.amount.asCurrency())
                .font(.headline)
                .foregroundStyle(item.isPaused ? .secondary : .primary)
        }
        .padding(14)
        .cardStyle()
        .opacity(item.isPaused ? 0.75 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.amount.asCurrency()), \(schedule)")
    }
}

#Preview {
    NavigationStack {
        RecurringListScreen(recurring: AppContainer.preview().recurring, expenses: AppContainer.preview().expenses)
    }
}
