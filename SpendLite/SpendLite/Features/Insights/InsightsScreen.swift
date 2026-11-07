import SwiftUI
import Combine

struct InsightsScreen: View {
    @StateObject private var viewModel: InsightsViewModel

    init(expense: ExpenseRepository) {
        _viewModel = StateObject(wrappedValue: InsightsViewModel(expenses: expense))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Spending Insights")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)

                // Range picker
                RangePicker(selection: $viewModel.range)
                    .padding(.horizontal)

                // Total spending card
                TotalSpendingCard(totalText: viewModel.totalFormatted, deltaText: viewModel.deltaText)
                    .padding(.horizontal)

                // Categories card
                CategoriesCard(items: viewModel.categoryBreakdown)
                    .padding(.horizontal)

                Spacer(minLength: 12)
            }
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(HomeScreen.creamBackground)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.onAppear() }
    }
}

// MARK: - ViewModel (scoped placeholder)
@MainActor
final class InsightsViewModel: SwiftUI.ObservableObject {
    enum Range: Equatable { case last7Days, thisMonth }

    @Published var range: Range = .thisMonth { didSet { refresh() } }
    @Published private(set) var total: Decimal = 0
    @Published private(set) var categoryBreakdown: [(name: String, amount: Decimal)] = []

    private let expenses: ExpenseRepository

    init(expenses: ExpenseRepository) {
        self.expenses = expenses
    }

    func onAppear() { refresh() }

    func refresh() {
        // TODO: Query repository by date range. For now, placeholder values so UI can be tested.
        switch range {
        case .last7Days:
            total = 684
            categoryBreakdown = [("Food & Dining", 220), ("Transport", 95), ("Shopping", 160), ("Entertainment", 80)]
        case .thisMonth:
            total = 2847
            categoryBreakdown = [("Food & Dining", 987), ("Transportation", 365), ("Entertainment", 420), ("Shopping", 267)]
        }
    }

    var totalFormatted: String { total.asCurrency() }
    var deltaText: String { range == .thisMonth ? "↑ 12%" : "↑ 4%" }
}

// MARK: - RangePicker
private struct RangePicker: View {
    @Binding var selection: InsightsViewModel.Range

    var body: some View {
        HStack(spacing: 8) {
            SegmentedButton("Last 7 days", isSelected: selection == .last7Days) {
                selection = .last7Days
            }
            SegmentedButton("This month", isSelected: selection == .thisMonth) {
                selection = .thisMonth
            }
        }
    }
}

private struct SegmentedButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .blue : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cards
private struct TotalSpendingCard: View {
    let totalText: String
    let deltaText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Total Spending")
                    .font(.headline)
                Spacer()
                Text(deltaText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Text(totalText)
                .font(.title.bold())

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 160)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
    }
}

private struct CategoriesCard: View {
    let items: [(name: String, amount: Decimal)]

    var body: some View {
        // Break complex builder into smaller constants to help type-checker
        let header = HStack {
            Text("Categories")
                .font(.headline)
            Spacer()
            Button(action: {}) {
                Text("View all categories")
                    .font(.subheadline.weight(.semibold))
            }
        }

        let list = VStack(spacing: 10) {
            ForEach(items.prefix(5), id: \.name) { item in
                CategoryRow(name: item.name, amount: item.amount)
            }
        }

        return VStack(alignment: .leading, spacing: 12) {
            header
            list
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
    }
}

private struct CategoryRow: View {
    let name: String
    let amount: Decimal

    var body: some View {
        // Extracted row to reduce complexity inside ForEach
        HStack {
            Text(name)
            Spacer()
            Text(amount.asCurrency())
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    InsightsScreen(expense: AppContainer(inMemory: true).expenses)
}
