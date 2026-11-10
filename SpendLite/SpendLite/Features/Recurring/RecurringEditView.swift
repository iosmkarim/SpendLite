//
//  RecurringEditView.swift
//  SpendLite
//

import SwiftUI

/// Edit a recurring expense's name, amount, category, or pause it.
/// Changes apply to future expenses only; ones already added stay as they were.
struct RecurringEditView: View {
    let item: RecurringExpense
    let nextDate: Date
    let onSave: (RecurringExpense) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var isPaused: Bool

    init(item: RecurringExpense, nextDate: Date,
         onSave: @escaping (RecurringExpense) -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.nextDate = nextDate
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: item.title)
        _amountText = State(initialValue: AddExpenseViewModel.amountText(for: item.amount))
        _category = State(initialValue: item.categoryKind)
        _isPaused = State(initialValue: item.isPaused)
    }

    private var amount: Double? {
        let locale = Locale.current
        let cleaned = amountText
            .replacingOccurrences(of: locale.groupingSeparator ?? ",", with: "")
            .filter { $0.isNumber || String($0) == (locale.decimalSeparator ?? ".") }
        guard let value = Decimal(string: cleaned, locale: locale), value > 0 else { return nil }
        return NSDecimalNumber(decimal: value).doubleValue
    }

    private var canSave: Bool {
        amount != nil && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $title)
                    .accessibilityIdentifier("recurringEdit.title")
                HStack {
                    Text(Currency.symbol).foregroundStyle(.secondary)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("recurringEdit.amount")
                }
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases) { category in
                        Label(category.name, systemImage: category.systemImage).tag(category)
                    }
                }
            }
            .listRowBackground(Color.formRowBackground)

            Section {
                LabeledContent("Repeats", value: item.frequency.title)
                LabeledContent("Started", value: item.startDate.formatted(date: .abbreviated, time: .omitted))
                if !isPaused {
                    LabeledContent("Next", value: nextDate.formatted(date: .abbreviated, time: .omitted))
                }
                Toggle("Paused", isOn: $isPaused)
                    .accessibilityIdentifier("recurringEdit.paused")
            } header: {
                Text("Schedule")
            } footer: {
                Text(isPaused
                     ? "Nothing is added while paused. Resuming continues from the next date."
                     : "Changes apply to future expenses. Ones already added stay as they are.")
            }
            .listRowBackground(Color.formRowBackground)

            Section {
                Button("Stop Repeating", role: .destructive, action: onDelete)
                    .accessibilityIdentifier("recurringEdit.delete")
            }
            .listRowBackground(Color.formRowBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Edit Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let amount else { return }
                    var updated = item
                    updated.title = title.trimmingCharacters(in: .whitespaces)
                    updated.amount = amount
                    updated.category = category.rawValue
                    updated.isPaused = isPaused
                    onSave(updated)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }
}
