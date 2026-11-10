//
//  BudgetWidget.swift
//  SpendLiteWidget
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct BudgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// True before the app has written any data (shows the sample in the gallery / an "open app" hint).
    let isPlaceholder: Bool
}

struct BudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: .now, snapshot: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(entry(at: .now, preview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        // The app reloads the widget whenever data changes; refresh at midnight too so a
        // new month starts fresh even if the app isn't opened.
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry(at: .now, preview: false)], policy: .after(tomorrow)))
    }

    private func entry(at date: Date, preview: Bool) -> BudgetEntry {
        if let snapshot = WidgetSnapshotStore.load() {
            return BudgetEntry(date: date, snapshot: snapshot, isPlaceholder: false)
        }
        return BudgetEntry(date: date, snapshot: .placeholder, isPlaceholder: true)
    }
}

// MARK: - Widget

struct BudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotStore.widgetKind, provider: BudgetProvider()) { entry in
            BudgetWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.background }
        }
        .configurationDisplayName("Monthly Budget")
        .description("See how much of this month's budget is left, and add an expense in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Views

struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BudgetEntry

    var body: some View {
        switch family {
        case .systemMedium: MediumView(entry: entry)
        case .accessoryCircular: CircularView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryInline: InlineView(entry: entry)
        default: SmallView(entry: entry)
        }
    }
}

/// Shared numbers for one entry.
private struct Figures {
    let entry: BudgetEntry

    var snapshot: WidgetSnapshot { entry.snapshot }
    var remaining: Double { snapshot.remaining(asOf: entry.date) }
    var progress: Double { snapshot.progress(asOf: entry.date) }
    var status: WidgetSnapshot.Status { snapshot.status(asOf: entry.date) }
    var isOver: Bool { status == .overBudget }

    var month: String { entry.date.formatted(.dateTime.month(.wide)) }
    var monthShort: String { entry.date.formatted(.dateTime.month(.abbreviated)) }

    func money(_ value: Double, cents: Bool = false) -> String {
        value.formatted(.currency(code: snapshot.currencyCode).precision(.fractionLength(cents ? 2 : 0)))
    }

    /// "$1,257" or "$80 over"
    var headline: String { isOver ? money(-remaining) : money(remaining) }
    var caption: String { isOver ? "over budget" : "left" }

    var ringColor: Color {
        switch status {
        case .onTrack: WidgetPalette.brand
        case .nearLimit: .orange
        case .overBudget: .red
        }
    }

    var percentLabel: String { (snapshot.spent(asOf: entry.date) / max(snapshot.monthlyBudget, 0.01)).formatted(.percent.precision(.fractionLength(0))) }
}

private struct SmallView: View {
    let entry: BudgetEntry
    private var f: Figures { Figures(entry: entry) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(f.month)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Ring(progress: f.progress, color: f.ringColor, lineWidth: 5)
                    .frame(width: 26, height: 26)
            }
            Spacer(minLength: 0)
            Text(f.headline)
                .font(.title.bold())
                .foregroundStyle(f.isOver ? .red : .primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(f.caption)
                .font(.subheadline)
                .foregroundStyle(f.isOver ? .red : .secondary)
            Text("of \(f.money(f.snapshot.monthlyBudget))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .widgetURL(WidgetSnapshotStore.homeURL)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(f.month) budget: \(f.headline) \(f.caption) of \(f.money(f.snapshot.monthlyBudget))")
    }
}

private struct MediumView: View {
    let entry: BudgetEntry
    private var f: Figures { Figures(entry: entry) }

    var body: some View {
        HStack(spacing: 16) {
            // Left: the budget.
            VStack(alignment: .leading, spacing: 6) {
                Text("\(f.month) Budget")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Ring(progress: f.progress, color: f.ringColor, lineWidth: 7)
                        .overlay(
                            Text(f.percentLabel)
                                .font(.system(size: 11, weight: .bold))
                                .minimumScaleFactor(0.6)
                        )
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(f.headline)
                            .font(.title2.bold())
                            .foregroundStyle(f.isOver ? .red : .primary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(f.caption)
                            .font(.caption)
                            .foregroundStyle(f.isOver ? .red : .secondary)
                    }
                }
                Spacer(minLength: 0)
                Link(destination: WidgetSnapshotStore.addExpenseURL) {
                    Label("Add expense", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(WidgetPalette.brand, in: Capsule())
                }
            }

            // Right: recent expenses.
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if f.snapshot.recent.isEmpty {
                    Text("No expenses yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(f.snapshot.recent.prefix(3)) { expense in
                        HStack {
                            Text(expense.title)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(f.money(expense.amount, cents: true))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .widgetURL(WidgetSnapshotStore.homeURL)
    }
}

private struct CircularView: View {
    let entry: BudgetEntry
    private var f: Figures { Figures(entry: entry) }

    var body: some View {
        Gauge(value: f.progress) {
            Image(systemName: "creditcard")
        } currentValueLabel: {
            Text(f.percentLabel)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetURL(WidgetSnapshotStore.homeURL)
        .accessibilityLabel("\(f.percentLabel) of budget spent")
    }
}

private struct RectangularView: View {
    let entry: BudgetEntry
    private var f: Figures { Figures(entry: entry) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(f.month) budget")
                .font(.caption)
                .widgetAccentable()
            Text("\(f.headline) \(f.caption)")
                .font(.headline)
                .minimumScaleFactor(0.6)
            Gauge(value: f.progress) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
        }
        .widgetURL(WidgetSnapshotStore.homeURL)
    }
}

private struct InlineView: View {
    let entry: BudgetEntry
    private var f: Figures { Figures(entry: entry) }

    var body: some View {
        Text("\(f.headline) \(f.caption) in \(f.monthShort)")
    }
}

/// The app's budget ring, drawn for the widget.
private struct Ring: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

enum WidgetPalette {
    static let brand = Color(red: 0x5B / 255, green: 0x4F / 255, blue: 0xE9 / 255)
    static let background = Color(uiColor: .systemBackground)
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    BudgetWidget()
} timeline: {
    BudgetEntry(date: .now, snapshot: .placeholder, isPlaceholder: false)
}

#Preview("Medium", as: .systemMedium) {
    BudgetWidget()
} timeline: {
    BudgetEntry(date: .now, snapshot: .placeholder, isPlaceholder: false)
}
