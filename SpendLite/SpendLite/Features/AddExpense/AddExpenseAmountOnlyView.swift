import SwiftUI
import PhotosUI

struct AddExpenseAmountOnlyView: View {
    @StateObject private var viewModel: AddExpenseViewModel
    @EnvironmentObject private var pro: ProStore
    @State private var showingPaywall = false

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var descriptionText: String = ""
    @State private var selectedCategory: ExpenseCategory? = nil
    @State private var selectedDate: Date = .now
    @State private var showDatePicker: Bool = false
    /// nil = doesn't repeat.
    @State private var repeatFrequency: RecurringExpense.Frequency?

    // Receipt scanning
    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isReadingReceipt = false
    @State private var receiptMessage: String?

    /// True when shown in a sheet: adds a Cancel button and closes itself after saving.
    private let isPresentedAsSheet: Bool
    /// Called after a successful save (e.g. the Add tab switches back to Home).
    private let onSaved: (() -> Void)?

    /// Doesn't create its own NavigationStack: the caller provides one
    /// (the tab's stack, or a NavigationStack wrapped around the sheet).
    /// Pass `editing` to edit an existing expense: the form starts filled in and Save updates it.
    init(
        expenses: ExpenseRepository,
        editing: ExpenseItem? = nil,
        recurring: RecurringExpenseRepository? = nil,
        initialRepeat: RecurringExpense.Frequency? = nil,
        isPresentedAsSheet: Bool = false,
        onSaved: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: AddExpenseViewModel(expenses: expenses, editing: editing, recurring: recurring))
        _repeatFrequency = State(initialValue: initialRepeat)
        self.isPresentedAsSheet = isPresentedAsSheet
        self.onSaved = onSaved
        if let editing {
            _amountText = State(initialValue: AddExpenseViewModel.amountText(for: editing.amount))
            _descriptionText = State(initialValue: AddExpenseViewModel.descriptionText(for: editing))
            _selectedCategory = State(initialValue: editing.categoryKind)
            _selectedDate = State(initialValue: editing.date)
        }
    }

    // MARK: - Saving
    private func handleSave() {
        guard let amount, amount > 0 else { return }
        viewModel.save(
            amount: amount,
            description: descriptionText,
            category: selectedCategory?.name,
            date: selectedDate,
            repeats: repeatFrequency
        ) {
            if !viewModel.isEditing { resetForm() }
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
        repeatFrequency = nil
    }
    
    // MARK: - Receipt scanning

    /// UI tests get a "Use Sample Receipt" option (the simulator has no camera).
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(SpendLiteApp.uiTestingArgument)
    }

    private func readReceipt(_ image: UIImage) {
        isReadingReceipt = true
        receiptMessage = nil
        Task {
            defer { isReadingReceipt = false }
            do {
                let lines = try await ReceiptTextRecognizer.lines(in: image)
                apply(ReceiptParser.parse(lines: lines))
            } catch {
                receiptMessage = "Couldn't read this receipt. Try a clearer photo, or fill it in by hand."
            }
        }
    }

    /// Fills in what was found; anything not found keeps what the user already entered.
    private func apply(_ draft: ReceiptDraft) {
        withAnimation(.snappy) {
            if let amount = draft.amount {
                amountText = AddExpenseViewModel.amountText(for: NSDecimalNumber(decimal: amount).doubleValue)
            }
            if let merchant = draft.merchant { descriptionText = merchant }
            if let date = draft.date { selectedDate = date }
            if let category = draft.category, selectedCategory == nil { selectedCategory = category }
        }
        if draft.isEmpty {
            receiptMessage = "Couldn't read this receipt. Try a clearer photo, or fill it in by hand."
        } else if draft.amount == nil {
            receiptMessage = "Couldn't find the total. Please enter the amount."
        } else {
            receiptMessage = "Filled in from your receipt. Check the amount before saving."
        }
    }

    @ViewBuilder
    private var scanSection: some View {
        if pro.isPro {
            unlockedScanSection
        } else {
            // Pro feature: same row, with a badge, opening the upgrade screen.
            Section {
                Button { showingPaywall = true } label: {
                    HStack {
                        Label("Scan a receipt", systemImage: "doc.text.viewfinder")
                        Spacer()
                        ProBadge()
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("addExpense.scanReceipt")
            }
            .listRowBackground(Color.formRowBackground)
        }
    }

    private var unlockedScanSection: some View {
        Section {
            Menu {
                if DocumentScannerView.isSupported {
                    Button("Take Photo", systemImage: "camera") { showingScanner = true }
                }
                Button("Choose from Photos", systemImage: "photo.on.rectangle") { showingPhotoPicker = true }
                if isUITesting {
                    Button("Use Sample Receipt", systemImage: "doc.text") { readReceipt(SampleReceipt.image()) }
                }
            } label: {
                HStack {
                    Label("Scan a receipt", systemImage: "doc.text.viewfinder")
                    Spacer()
                    if isReadingReceipt {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .disabled(isReadingReceipt)
            .accessibilityIdentifier("addExpense.scanReceipt")
        } footer: {
            if let receiptMessage {
                Text(receiptMessage)
                    .accessibilityIdentifier("addExpense.receiptMessage")
            }
        }
        .listRowBackground(Color.formRowBackground)
    }

    /// Shared with Home/Transactions so icons and colours match everywhere.
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
                if !viewModel.isEditing {
                    scanSection
                }
                Section("Amount") {
                    HStack {
                        Text(Currency.symbol)
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
                .listRowBackground(Color.formRowBackground)
                Section("Description") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $descriptionText)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)

                        // TextEditor already insets its text by ~5pt × 8pt; match that so
                        // the placeholder sits exactly where typing starts.
                        if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("What did you spend on?")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    // Same left inset as the Amount field, so typed text doesn't touch the edge.
                    .padding(.horizontal, 15)
                    .padding(.vertical, 6)
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.formRowBackground)
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
                .listRowBackground(Color.formRowBackground)
                
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
                .listRowBackground(Color.formRowBackground)

                if viewModel.canRepeat && pro.recurringLimitReached(currentCount: viewModel.recurringCount) {
                    // Free users have used their recurring expenses: offer Pro instead.
                    Section {
                        Button { showingPaywall = true } label: {
                            HStack {
                                Label("Repeat", systemImage: "arrow.triangle.2.circlepath")
                                Spacer()
                                ProBadge()
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("addExpense.repeatLocked")
                    } header: {
                        Text("Repeat")
                    } footer: {
                        Text("You've used all \(ProStore.freeRecurringLimit) free recurring expenses. SpendLite Pro makes them unlimited.")
                    }
                    .listRowBackground(Color.formRowBackground)
                } else if viewModel.canRepeat {
                    Section {
                        Picker(selection: $repeatFrequency) {
                            Text("Never").tag(RecurringExpense.Frequency?.none)
                            ForEach(RecurringExpense.Frequency.allCases) { frequency in
                                Text(frequency.title).tag(Optional(frequency))
                            }
                        } label: {
                            Label("Repeat", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .accessibilityIdentifier("addExpense.repeat")
                    } header: {
                        Text("Repeat")
                    } footer: {
                        if let repeatFrequency {
                            Text("Added automatically \(repeatFrequency.title.lowercased()) from \(selectedDate.formatted(.dateTime.month(.abbreviated).day())). Manage in Settings → Recurring expenses.")
                        }
                    }
                    .listRowBackground(Color.formRowBackground)
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
        .navigationTitle(viewModel.isEditing ? "Edit Expense" : "Add Expense")
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
            viewModel.isEditing ? "Couldn't update expense" : "Couldn't save expense",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingPaywall) { ProPaywallView(pro: pro) }
        // Bought Pro while the form was open with "Repeat" preset (e.g. from the Recurring list)? Fine.
        .onAppear {
            if pro.recurringLimitReached(currentCount: viewModel.recurringCount) { repeatFrequency = nil }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    readReceipt(image)
                } else {
                    receiptMessage = "Couldn't open that photo."
                }
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            DocumentScannerView { image in
                showingScanner = false
                readReceipt(image)
            } onCancel: {
                showingScanner = false
            }
            .ignoresSafeArea()
        }
        .toolbarBackground(.bar, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        AddExpenseAmountOnlyView(expenses: AppContainer(inMemory: true).expenses, isPresentedAsSheet: true)
    }
    .environmentObject(AppContainer(inMemory: true).pro)
}
