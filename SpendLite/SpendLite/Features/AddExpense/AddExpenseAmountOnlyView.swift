import SwiftUI

struct AddExpenseAmountOnlyView: View {
    @StateObject private var viewModel: AddExpenseViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var descriptionText: String = ""
    @State private var selectedCategory: ExpenseCategory? = nil
    @State private var selectedDate: Date = .now
    @State private var showDatePicker: Bool = false

    /// True when shown in a sheet: adds a Cancel button and closes itself after saving.
    private let isPresentedAsSheet: Bool
    /// Called after a successful save (e.g. the Add tab switches back to Home).
    private let onSaved: (() -> Void)?

    /// Doesn't create its own NavigationStack: the caller provides one
    /// (the tab's stack, or a NavigationStack wrapped around the sheet).
    init(
        expenses: ExpenseRepository,
        isPresentedAsSheet: Bool = false,
        onSaved: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: AddExpenseViewModel(expenses: expenses))
        self.isPresentedAsSheet = isPresentedAsSheet
        self.onSaved = onSaved
    }

    // MARK: - Saving
    private func handleSave() {
        guard let amount, amount > 0 else { return }
        viewModel.save(
            amount: amount,
            description: descriptionText,
            category: selectedCategory?.name,
            date: selectedDate
        ) {
            resetForm()
            onSaved?()
            if isPresentedAsSheet { dismiss() }
        }
    }

    private func resetForm() {
        amountText = ""
        descriptionText = ""
        selectedCategory = nil
        selectedDate = .now
        showDatePicker = false
    }
    
    /// Shared with Home/History so icons and colours match everywhere.
    private var categories: [ExpenseCategory] { ExpenseCategory.allCases }

    /// Parses the amount using the user's locale, ignoring thousands separators
    /// (so "1,250.50" in the US is 1250.50, not 1).
    private var amount: Decimal? {
        let locale = Locale.current
        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        let cleaned = amountText
            .replacingOccurrences(of: groupingSeparator, with: "")
            .filter { $0.isNumber || String($0) == decimalSeparator }
        return Decimal(string: cleaned, locale: locale)
    }
    private var canSave: Bool { (amount ?? 0) > 0 && !viewModel.isSaving }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section("Amount") {
                    HStack {
                        Text(Locale.current.currencySymbol ?? "$")
                            .foregroundStyle(.secondary)
                        TextField("Enter amount", text: $amountText)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    if amount == nil || (amount ?? 0) <= 0 {
                        Text("Enter a valid amount greater than 0")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Section("Description") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $descriptionText)
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                            .scrollContentBackground(.hidden)

                        if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("What did you spend on?")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 10)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
                Section("Category") {
                    VStack(alignment: .leading, spacing: 12) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(categories) { category in
                                let isSelected = selectedCategory == category
                                Button {
                                    selectedCategory = category
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(category.color.opacity(0.12))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: category.systemImage)
                                                .imageScale(.medium)
                                                .foregroundStyle(category.color)
                                        }
                                        Text(category.name)
                                            .font(.subheadline)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(category.color.opacity(isSelected ? 0.18 : 0.10))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isSelected ? category.color : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                    .foregroundStyle(isSelected ? category.color : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if selectedCategory == nil {
                            Text("Select a category")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Date") {
                    Button {
                        withAnimation(.snappy) {
                            showDatePicker.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.tint)
                            Text(selectedDate, format: .dateTime.month(.abbreviated).day().year())
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if showDatePicker {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .id("datePickerAnchor")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: showDatePicker) { oldValue, newValue in
                if newValue {
                    DispatchQueue.main.async {
                        withAnimation(.snappy) {
                            proxy.scrollTo("datePickerAnchor", anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPresentedAsSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    handleSave()
                }
                .disabled(!canSave)
            }
        }
        .alert(
            "Couldn't save expense",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbarBackground(.bar, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 255/255, green: 250/255, blue: 240/255), // Linen (lighter)
                    Color(red: 255/255, green: 252/255, blue: 245/255)  // Soft Cream (very light)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    NavigationStack {
        AddExpenseAmountOnlyView(expenses: AppContainer(inMemory: true).expenses, isPresentedAsSheet: true)
    }
}
