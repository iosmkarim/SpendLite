//
//  OnboardingView.swift
//  SpendLite
//

import SwiftUI

/// First-launch welcome: what SpendLite does → set a monthly budget → start.
struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @AppStorage(AppSettings.Key.currencyCode) private var currencyCode: String = ""
    @FocusState private var budgetFocused: Bool
    let onFinish: () -> Void

    init(budget: BudgetRepository, expenses: ExpenseRepository, defaults: UserDefaults, onFinish: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(budget: budget, expenses: expenses, defaults: defaults))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressDots(current: viewModel.step.rawValue, total: OnboardingViewModel.Step.allCases.count)
                .padding(.top, 12)

            Group {
                switch viewModel.step {
                case .welcome: welcome
                case .budget: budgetStep
                case .ready: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))

            buttons
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .animation(.snappy, value: viewModel.step)
        // A container, so this id doesn't replace the buttons' own ids.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding")
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "creditcard.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color.brand)
                .iconTile(.brand, size: 92, cornerRadius: 26)
            VStack(spacing: 8) {
                Text("Welcome to SpendLite")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("A simple way to keep your spending in check.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 18) {
                Feature(icon: "plus.circle.fill", color: .brand, title: "Log spending in seconds",
                        detail: "Type it, scan a receipt, or just ask Siri.")
                Feature(icon: "chart.pie.fill", color: .pink, title: "See where it goes",
                        detail: "Insights by category, day and month.")
                Feature(icon: "target", color: .green, title: "Stay on budget",
                        detail: "Know what's left at a glance, even from your Home Screen.")
            }
            .padding(.horizontal, 8)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var budgetStep: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text("What's your monthly budget?")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("You can change it any time in Settings.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(Currency.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("2000", text: $viewModel.budgetText)
                    .font(.system(size: 44, weight: .bold))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .fixedSize()
                    .focused($budgetFocused)
                    .accessibilityIdentifier("onboarding.budget")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .cardStyle()

            HStack(spacing: 8) {
                ForEach(viewModel.suggestions, id: \.self) { amount in
                    let selected = viewModel.budgetValue == amount
                    Button(amount.formatted(.currency(code: Currency.code).precision(.fractionLength(0)))) {
                        viewModel.pick(amount)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selected ? Color.brand.opacity(0.15) : Color.insetBackground, in: Capsule())
                    .foregroundStyle(selected ? Color.brand : .primary)
                    .buttonStyle(.plain)
                }
            }

            Picker("Currency", selection: $currencyCode) {
                Text("Currency: Automatic (\(Currency.automaticCode))").tag("")
                ForEach(Currency.common, id: \.self) { code in
                    Text("Currency: \(code) · \(Currency.name(for: code))").tag(code)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("onboarding.currency")
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { budgetFocused = true }
    }

    private var ready: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.green)
                .iconTile(.green, size: 92, cornerRadius: 26)
            VStack(spacing: 8) {
                Text("You're all set")
                    .font(.largeTitle.bold())
                if let value = viewModel.budgetValue {
                    Text("Your monthly budget is \(value.asCurrency()).")
                        .foregroundStyle(.secondary)
                }
            }
            Text("Tip: add the SpendLite widget to your Home Screen to see what's left without opening the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Buttons

    private var buttons: some View {
        VStack(spacing: 12) {
            switch viewModel.step {
            case .welcome, .budget:
                Button {
                    budgetFocused = false
                    viewModel.next()
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canContinue)
                .accessibilityIdentifier("onboarding.continue")
            case .ready:
                Button {
                    viewModel.finish(withSampleData: false, completion: onFinish)
                } label: {
                    Text("Start").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding.start")

                Button("Explore with sample data") {
                    viewModel.finish(withSampleData: true, completion: onFinish)
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("onboarding.sample")
            }

            if viewModel.step != .welcome {
                Button("Back") { viewModel.back() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(viewModel.isFinishing)
    }
}

// MARK: - Pieces

private struct Feature: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .iconTile(color, size: 40, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.brand : Color.brand.opacity(0.2))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

#Preview {
    OnboardingView(budget: AppContainer(inMemory: true).budget, expenses: AppContainer(inMemory: true).expenses,
                   defaults: UserDefaults(suiteName: "preview")!) {}
}
