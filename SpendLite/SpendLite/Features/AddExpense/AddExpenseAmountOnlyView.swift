import SwiftUI

struct AddExpenseAmountOnlyView: View {
    // Callback to deliver the saved values to a parent if needed
    var onSave: ((Decimal, String, String?, Date) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var descriptionText: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var selectedDate: Date = .now
    @State private var showDatePicker: Bool = false
    
    // MARK: - Saving
    private func handleSave() {
        guard let amount, amount > 0 else { return }
        // Use selectedCategory name if available; otherwise nil
        let categoryName = selectedCategory?.name
        onSave?(amount, descriptionText.trimmingCharacters(in: .whitespacesAndNewlines), categoryName, selectedDate)
        dismiss()
    }
    
    private struct Category: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let systemImage: String
        let color: Color
    }
    
    private let categories: [Category] = [
        Category(name: "Food", systemImage: "fork.knife", color: Color.green),
        Category(name: "Transport", systemImage: "car.fill", color: Color.blue),
        Category(name: "Fun", systemImage: "gamecontroller.fill", color: Color.pink),
        Category(name: "Shopping", systemImage: "bag.fill", color: Color.orange),
        Category(name: "Home", systemImage: "house.fill", color: Color.purple),
        Category(name: "Health", systemImage: "heart.fill", color: Color.red),
        Category(name: "Education", systemImage: "book.fill", color: Color.indigo),
        Category(name: "Other", systemImage: "plus.circle", color: Color.gray)
    ]
    
    private var amount: Decimal? { Decimal(string: amountText.filter { "0123456789.,".contains($0) }) }
    private var canSave: Bool { amount != nil && amount! > 0 }

    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        handleSave()
                    }
                    .disabled(!canSave)
                }
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
}

#Preview {
    AddExpenseAmountOnlyView { amount, description, category, date in
        print("Saved amount: ", amount as NSDecimalNumber)
        print("Description: \(description)")
        print("Category: \(category ?? "none")")
        print("Date: \(date)")
    }
}
