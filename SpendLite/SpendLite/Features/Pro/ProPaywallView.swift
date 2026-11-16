//
//  ProPaywallView.swift
//  SpendLite
//

import SwiftUI

/// The SpendLite Pro screen: what Pro includes, the price, Buy and Restore.
struct ProPaywallView: View {
    @ObservedObject var pro: ProStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(LinearGradient.brand, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.brandEnd.opacity(0.35), radius: 14, y: 8)
                    Text("SpendLite Pro")
                        .font(.largeTitle.bold())
                    Text(pro.isPro ? "Thanks for your support!" : "One-time purchase. Yours forever.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 18) {
                    Perk(icon: "doc.text.viewfinder", color: .brand, title: "Receipt scan",
                         detail: "Snap a receipt and the amount, store and date fill themselves in.")
                    Perk(icon: "arrow.triangle.2.circlepath", color: .orange, title: "Unlimited recurring expenses",
                         detail: "Free includes \(ProStore.freeRecurringLimit). Add every bill and subscription you have.")
                    Perk(icon: "rectangle.3.group.fill", color: .pink, title: "More widgets",
                         detail: "Medium Home Screen widget with recent spending, plus Lock Screen widgets.")
                    Perk(icon: "heart.fill", color: .red, title: "Support an indie app",
                         detail: "No ads, no subscription, no tracking. Ever.")
                }
                .padding(20)
                .cardStyle()

                if let message = pro.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("pro.message")
                }
            }
            .padding(.horizontal, 20)
        }
        .safeAreaInset(edge: .bottom) { buttons }
        .background(Color.appBackground.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.insetBackground, in: Circle())
            }
            .padding(16)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("pro.close")
        }
        .task { await pro.refresh() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.paywall")
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if pro.isPro {
                Label("Pro unlocked", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .accessibilityIdentifier("pro.unlocked")
            } else {
                Button {
                    Task { await pro.buy() }
                } label: {
                    Group {
                        if pro.isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Text(pro.price.map { "Unlock Pro for \($0)" } ?? "Unlock Pro")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(pro.isWorking)
                .accessibilityIdentifier("pro.buy")

                Button("Restore Purchases") {
                    Task { await pro.restore() }
                }
                .font(.subheadline.weight(.semibold))
                .disabled(pro.isWorking)
                .accessibilityIdentifier("pro.restore")
            }
            Text("Payment is charged to your Apple Account. Family Sharing included.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

private struct Perk: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .iconTile(color, size: 38, cornerRadius: 11)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A small "PRO" tag shown next to locked features.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(LinearGradient.brand, in: Capsule())
            .accessibilityLabel("Pro feature")
    }
}

#Preview {
    ProPaywallView(pro: ProStore(service: FakePurchaseService(), defaults: UserDefaults(suiteName: "preview")!))
}
