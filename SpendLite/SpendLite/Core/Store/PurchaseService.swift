//
//  PurchaseService.swift
//  SpendLite
//

import Foundation
import StoreKit

/// SpendLite Pro: a one-time, non-consumable purchase.
enum ProProduct {
    static let id = "com.iosmkarim.SpendLite.pro"
}

enum PurchaseOutcome: Equatable {
    case purchased
    /// Waiting for approval (Ask to Buy) or extra steps (e.g. payment confirmation).
    case pending
    case cancelled
}

/// The App Store, behind a protocol so UI tests and previews can use a fake.
protocol PurchaseService {
    /// The localized price, e.g. "$4.99" or "4,99 €". Nil if the store couldn't be reached.
    func displayPrice() async -> String?
    func purchase() async throws -> PurchaseOutcome
    /// Whether this Apple ID owns Pro right now (refunds and Family Sharing included).
    func ownsPro() async -> Bool
    /// Re-syncs purchases with the App Store ("Restore Purchases").
    func restore() async throws
    /// Called when ownership changes outside a purchase here (another device, Ask to Buy approved, refund).
    func observeChanges(_ handler: @escaping @MainActor (Bool) -> Void) -> Task<Void, Never>
}

/// The real App Store, using StoreKit 2. Only verified transactions count.
struct StoreKitPurchaseService: PurchaseService {

    enum StoreError: LocalizedError {
        case productUnavailable
        case unverified

        var errorDescription: String? {
            switch self {
            case .productUnavailable: "SpendLite Pro isn't available right now. Check your connection and try again."
            case .unverified: "The App Store couldn't verify this purchase."
            }
        }
    }

    private func product() async throws -> Product {
        guard let product = try await Product.products(for: [ProProduct.id]).first else {
            throw StoreError.productUnavailable
        }
        return product
    }

    func displayPrice() async -> String? {
        try? await product().displayPrice
    }

    func purchase() async throws -> PurchaseOutcome {
        switch try await product().purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw StoreError.unverified }
            await transaction.finish()
            return transaction.revocationDate == nil ? .purchased : .cancelled
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func ownsPro() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == ProProduct.id,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func restore() async throws {
        try await AppStore.sync()
    }

    func observeChanges(_ handler: @escaping @MainActor (Bool) -> Void) -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                let owns = await StoreKitPurchaseService().ownsPro()
                await handler(owns)
            }
        }
    }
}

/// For UI tests and previews: instant, no App Store. `owns` sets the starting state.
final class FakePurchaseService: PurchaseService {
    private(set) var owns: Bool
    var outcome: PurchaseOutcome

    init(owns: Bool = false, outcome: PurchaseOutcome = .purchased) {
        self.owns = owns
        self.outcome = outcome
    }

    func displayPrice() async -> String? { "$4.99" }

    func purchase() async throws -> PurchaseOutcome {
        if outcome == .purchased { owns = true }
        return outcome
    }

    func ownsPro() async -> Bool { owns }
    func restore() async throws {}
    func observeChanges(_ handler: @escaping @MainActor (Bool) -> Void) -> Task<Void, Never> { Task {} }
}
