//
//  InsightsScreen.swift
//  SpendLite
//

import SwiftUI
import Charts

/// The Insights tab: where the money went in a period, built only from real expenses.
/// Total with a comparison to the previous period, a category donut (tap a category to see
/// those transactions), and a daily/weekly spending chart.
struct InsightsScreen: View {
    @StateObject private var viewModel: InsightsViewModel
    @EnvironmentObject private var nav: NavCoordinator

    init(expense: ExpenseRepository) {
        _viewModel = StateObject(wrappedValue: InsightsViewModel(expenses: expense))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Period", selection: $viewModel.period) {
                    ForEach(InsightsPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("insights.period")

                if let summary = viewModel.summary {
                    if summary.isEmpty {
                        emptyState
                    } else {
                        TotalCard(
                            summary: summary,
                            periodLabel: viewModel.periodLabel,
                            comparisonLabel: viewModel.comparisonLabel,
                            averagePerDay: viewModel.averagePerDay
                        )
                        CategoriesCard(summary: summary) { category in
                            nav.goToTransactions(category: category)
                        }
                        TrendCard(summary: summary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.snappy, value: viewModel.period)
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        // Re-reads "now" so "This month" is current after the app has been in the background.
        .onAppear { viewModel.refresh() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No spending yet", systemImage: "chart.pie")
        } description: {
            Text("Nothing was spent in \(viewModel.periodLabel). Add a few expenses to see where your money goes.")
        }
        .padding(.top, 40)
    }
}

// MARK: - Total

private struct TotalCard: View {
    let summary: InsightsSummary
    let periodLabel: String
    let comparisonLabel: String
    let averagePerDay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Total spent")
                    .font(.headline)
                Spacer()
                Text(periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(summary.total.asCurrency())
                .font(.largeTitle.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .accessibilityIdentifier("insights.total")

            ChangeChip(change: summary.changeFromPrevious, comparisonLabel: comparisonLabel)

            Divider().padding(.vertical, 2)

            HStack {
                Stat(title: "Per day", value: averagePerDay.asCurrency())
                Spacer()
                Stat(title: "Transactions", value: "\(summary.transactionCount)")
                Spacer()
                Stat(title: "Top category", value: summary.categories.first?.category.name ?? "–")
            }
        }
        .padding(18)
        .cardStyle()
    }
}

/// "↓ 8% vs Oct 1 – 9". Spending less is good (green); more is a warning (red).
private struct ChangeChip: View {
    let change: Double?
    let comparisonLabel: String

    var body: some View {
        if let change {
            let isUp = change > 0
            let color: Color = abs(change) < 0.005 ? .secondary : (isUp ? .red : .green)
            HStack(spacing: 4) {
                Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                Text(abs(change).formatted(.percent.precision(.fractionLength(0))))
                Text("vs \(comparisonLabel)")
                    .foregroundStyle(.secondary)
                    .fontWeight(.regular)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(isUp ? "Up" : "Down") \(abs(change).formatted(.percent.precision(.fractionLength(0)))) compared with \(comparisonLabel)")
        } else {
            Text("Nothing spent in \(comparisonLabel) to compare with")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct Stat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Categories

private struct CategoriesCard: View {
    let summary: InsightsSummary
    let onSelect: (ExpenseCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("By category")
                .font(.headline)

            Chart(summary.categories) { item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(item.category.color)
            }
            .chartLegend(.hidden)
            .chartBackground { _ in
                VStack(spacing: 2) {
                    Text("\(summary.categories.count)")
                        .font(.title2.bold())
                    Text(summary.categories.count == 1 ? "category" : "categories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 180)
            .accessibilityHidden(true) // the rows below carry the same information

            VStack(spacing: 4) {
                ForEach(summary.categories) { item in
                    Button { onSelect(item.category) } label: {
                        CategoryRow(item: item)
                    }
                    .buttonStyle(.pressableCard)
                    .accessibilityHint("Shows these transactions")
                    .accessibilityIdentifier("insights.category.\(item.category.rawValue)")
                }
            }
        }
        .padding(18)
        .cardStyle()
    }
}

private struct CategoryRow: View {
    let item: InsightsSummary.CategoryShare

    private var percent: String {
        item.share.formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(item.category.color)
                .iconTile(item.category.color, size: 36, cornerRadius: 11)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.category.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(item.total.asCurrency())
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                // Share of the total as a bar.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.insetBackground)
                        Capsule()
                            .fill(item.category.color)
                            .frame(width: max(4, proxy.size.width * item.share))
                    }
                }
                .frame(height: 6)
            }

            Text(percent)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 36, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.category.name), \(item.total.asCurrency()), \(percent) of spending, \(item.count) \(item.count == 1 ? "transaction" : "transactions")")
    }
}

// MARK: - Trend

private struct TrendCard: View {
    let summary: InsightsSummary

    private var isWeekly: Bool { summary.trendUnit == .weekOfYear }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isWeekly ? "Weekly spending" : "Daily spending")
                .font(.headline)

            Chart(summary.trend) { point in
                BarMark(
                    x: .value(isWeekly ? "Week" : "Day", point.start, unit: summary.trendUnit),
                    y: .value("Spent", point.total)
                )
                .cornerRadius(3)
                .foregroundStyle(Color.brand.gradient)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.formatted(.currency(code: Currency.code).precision(.fractionLength(0))))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: summary.trendUnit, count: isWeekly ? 2 : 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 180)
            .accessibilityLabel(isWeekly ? "Weekly spending chart" : "Daily spending chart")
        }
        .padding(18)
        .cardStyle()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InsightsScreen(expense: AppContainer.preview().expenses)
    }
    .environmentObject(NavCoordinator())
}
