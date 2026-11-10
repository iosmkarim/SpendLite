//
//  SettingsScreen.swift
//  SpendLite
//

import SwiftUI

/// The Settings tab: budget, currency, appearance, export / delete data, about.
struct SettingsScreen: View {
    @StateObject private var viewModel: SettingsViewModel

    /// "" means Automatic (follow the device region).
    @AppStorage(AppSettings.Key.currencyCode) private var currencyCode: String = ""
    @AppStorage(AppSettings.Key.appearance) private var appearance: Appearance = .system

    @State private var showingBudgetEditor = false
    @State private var budgetText = ""
    @State private var showingDeleteConfirmation = false

    private let expenses: ExpenseRepository
    private let recurring: RecurringExpenseRepository?

    init(expenses: ExpenseRepository, budget: BudgetRepository, recurring: RecurringExpenseRepository? = nil) {
        self.expenses = expenses
        self.recurring = recurring
        _viewModel = StateObject(wrappedValue: SettingsViewModel(expenses: expenses, budget: budget))
    }

    var body: some View {
        Form {
            budgetSection
            preferencesSection
            dataSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Monthly Budget", isPresented: $showingBudgetEditor) {
            TextField("Amount", text: $budgetText)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            Button("Save") { viewModel.setMonthlyBudget(from: budgetText) }
        } message: {
            Text("How much do you want to spend each month?")
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Expenses", role: .destructive) {
                viewModel.deleteAllExpenses()
            }
        } message: {
            Text("This can't be undone. Export a CSV first if you want to keep a copy.")
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

    private var deleteTitle: String {
        viewModel.expenseCount == 1
            ? "Delete 1 expense?"
            : "Delete all \(viewModel.expenseCount) expenses?"
    }

    // MARK: - Sections

    private var budgetSection: some View {
        Section {
            Button {
                // Pre-fill without grouping so editing "2000" doesn't fight a "2,000.00".
                budgetText = viewModel.monthlyBudget.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
                showingBudgetEditor = true
            } label: {
                SettingsRow(icon: "target", color: .brand, title: "Monthly budget") {
                    Text(viewModel.monthlyBudget.asCurrency())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.budget")

            if let recurring {
                NavigationLink {
                    RecurringListScreen(recurring: recurring, expenses: expenses)
                } label: {
                    SettingsRow(icon: "arrow.triangle.2.circlepath", color: .orange, title: "Recurring expenses") {
                        EmptyView()
                    }
                }
                .accessibilityIdentifier("settings.recurring")
            }
        } header: {
            Text("Budget")
        } footer: {
            Text("Home shows how much of your budget is left each month. Recurring expenses (rent, subscriptions) are added automatically.")
        }
        .listRowBackground(Color.formRowBackground)
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker(selection: $currencyCode) {
                Text("Automatic (\(Currency.automaticCode))").tag("")
                ForEach(Currency.common, id: \.self) { code in
                    Text(Self.currencyLabel(for: code)).tag(code)
                }
            } label: {
                SettingsRow(icon: "banknote", color: .green, title: "Currency") { EmptyView() }
            }
            .pickerStyle(.navigationLink)
            .accessibilityIdentifier("settings.currency")

            Picker(selection: $appearance) {
                ForEach(Appearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            } label: {
                SettingsRow(icon: "circle.lefthalf.filled", color: .indigo, title: "Appearance") { EmptyView() }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("settings.appearance")
        }
        .listRowBackground(Color.formRowBackground)
    }

    private var dataSection: some View {
        Section {
            let csv = viewModel.makeCSV()
            ShareLink(item: csv, preview: SharePreview(csv.fileName, image: Image(systemName: "tablecells"))) {
                SettingsRow(icon: "square.and.arrow.up", color: .blue, title: "Export expenses (CSV)") {
                    Text("\(viewModel.expenseCount)")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.expenseCount == 0)
            .accessibilityIdentifier("settings.export")

            Button {
                showingDeleteConfirmation = true
            } label: {
                SettingsRow(icon: "trash", color: .red, title: "Delete all expenses", titleColor: .red) {
                    if viewModel.isDeleting { ProgressView() }
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.expenseCount == 0 || viewModel.isDeleting)
            .accessibilityIdentifier("settings.deleteAll")
        } header: {
            Text("Data")
        } footer: {
            Text("Your expenses are stored only on this iPhone.")
        }
        .listRowBackground(Color.formRowBackground)
    }

    private var aboutSection: some View {
        Section("About") {
            SettingsRow(icon: "info.circle", color: .gray, title: "Version") {
                Text(Self.versionText)
                    .foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://github.com/iosmkarim/SpendLite")!) {
                SettingsRow(icon: "chevron.left.forwardslash.chevron.right", color: .black, title: "Source code") {
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color.formRowBackground)
    }

    /// "€  EUR · Euro", or "BDT · Bangladeshi Taka" when the symbol is just the code again.
    static func currencyLabel(for code: String) -> String {
        let symbol = Currency.symbol(for: code)
        let name = "\(code) · \(Currency.name(for: code))"
        return symbol == code ? name : "\(symbol)  \(name)"
    }

    /// "1.0 (1)"
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Row

/// Icon tile + title + trailing content, like the system Settings app.
private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let color: Color
    let title: String
    var titleColor: Color = .primary
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(titleColor)
            Spacer()
            trailing()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SettingsScreen(expenses: AppContainer.preview().expenses, budget: AppContainer.preview().budget)
    }
}
