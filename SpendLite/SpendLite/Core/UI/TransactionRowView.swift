//
//  TransactionRowView.swift
//  SpendLite
//

import SwiftUI

/// One expense as a card: category icon, title, category pill, date and amount.
/// Shared by Home's Recent Transactions and the Transactions tab so they look the same.
struct TransactionRowView: View {
    let item : ExpenseItem
    
    private var category: ExpenseCategory { item.categoryKind }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(category.color)
                .iconTile(category.color)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(category.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(category.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(category.color.opacity(0.12))
                        .clipShape(Capsule())

                    Text(ExpenseDate.label(for: item.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if item.isRecurring {
                        // Added automatically by a recurring expense.
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.brand)
                    }
                }
            }
            
            Spacer()
            
            // Let the formatter place the minus sign (locale-correct, e.g. "-$5.40").
            Text((-item.amount).asCurrency())
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .cardStyle()
        // One VoiceOver stop per row: "Coffee, Food, Today, 9:41 AM, spent $4.75"
        // (instead of separate stops and "minus 4 dollars 75").
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(item.title), \(category.name), \(ExpenseDate.label(for: item.date)), spent \(item.amount.asCurrency())\(item.isRecurring ? ", recurring" : "")"
        )
    }
}
