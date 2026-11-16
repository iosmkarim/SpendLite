//
//  SpendLiteIntents.swift
//  SpendLite
//

import AppIntents

// MARK: - Category for Siri / Shortcuts

nonisolated extension ExpenseCategory: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Category")

    static let caseDisplayRepresentations: [ExpenseCategory: DisplayRepresentation] = [
        .food: DisplayRepresentation(title: "Food", image: .init(systemName: "fork.knife")),
        .transport: DisplayRepresentation(title: "Transport", image: .init(systemName: "car.fill")),
        .fun: DisplayRepresentation(title: "Fun", image: .init(systemName: "gamecontroller.fill")),
        .shopping: DisplayRepresentation(title: "Shopping", image: .init(systemName: "bag.fill")),
        .home: DisplayRepresentation(title: "Home", image: .init(systemName: "house.fill")),
        .health: DisplayRepresentation(title: "Health", image: .init(systemName: "heart.fill")),
        .education: DisplayRepresentation(title: "Education", image: .init(systemName: "book.fill")),
        .other: DisplayRepresentation(title: "Other", image: .init(systemName: "square.grid.2x2.fill")),
    ]
}

// MARK: - Add expense

/// "Hey Siri, add an expense in SpendLite" → asks for the amount, saves it, says what's left.
struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense"
    static let description = IntentDescription("Log a new expense in SpendLite.")
    /// Your spending is private: Siri asks you to unlock the iPhone first.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(
        title: "Amount",
        requestValueDialog: IntentDialog("How much did you spend?")
    )
    var amount: Double

    @Parameter(title: "Description", requestValueDialog: IntentDialog("What was it for?"))
    var note: String?

    @Parameter(title: "Category")
    var category: ExpenseCategory?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) in \(\.$category)") {
            \.$note
        }
    }

    init() {}

    init(amount: Double, note: String? = nil, category: ExpenseCategory? = nil) {
        self.amount = amount
        self.note = note
        self.category = category
    }

    // The app's data lives on the main actor.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let handler = ExpenseIntentHandler(container: .live)
        let item = try await handler.addExpense(amount: amount, description: note, category: category)
        let message = await handler.confirmation(for: item)
        return .result(value: item.amount, dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Budget left

/// "Hey Siri, how much is left in SpendLite" → "You have $1,257 left of your $2,000 November budget."
struct BudgetStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Budget"
    static let description = IntentDescription("Hear how much of this month's budget is left.")
    /// Your spending is private: Siri asks you to unlock the iPhone first.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let reply = await ExpenseIntentHandler(container: .live).budgetReply()
        return .result(value: reply.remaining, dialog: IntentDialog(stringLiteral: reply.sentence))
    }
}

// MARK: - Siri phrases

/// Available as soon as the app is installed: Siri, Spotlight, the Shortcuts app and the Action button.
nonisolated struct SpendLiteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Add a \(\.$category) expense in \(.applicationName)",
                "Log spending in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: BudgetStatusIntent(),
            phrases: [
                "How much is left in \(.applicationName)",
                "Check my budget in \(.applicationName)",
                "What's my \(.applicationName) budget",
            ],
            shortTitle: "Budget Left",
            systemImageName: "chart.pie.fill"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .purple
}
