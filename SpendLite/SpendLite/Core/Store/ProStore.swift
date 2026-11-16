//
//  ProStore.swift
//  SpendLite
//

import Foundation
import Combine

/// Whether this user has SpendLite Pro, and buying / restoring it.
///
/// Pro unlocks: receipt scan, more than `freeRecurringLimit` recurring expenses,
/// and the medium + Lock Screen widgets. Everything else is free.
final class ProStore: ObservableObject {

    /// Free users can have this many recurring expenses.
    static let freeRecurringLimit = 3
    /// Remembered so Pro features don't flash "locked" at launch while StoreKit answers.
    static let cachedKey = "pro.isPro"

    @Published private(set) var isPro: Bool
    @Published private(set) var price: String?
    @Published private(set) var isWorking = false
    /// A message to show after buy/restore (e.g. "Waiting for approval", or an error).
    @Published var message: String?

    /// Called whenever `isPro` changes (e.g. to update the widget).
    var onChange: ((Bool) -> Void)?

    private let service: PurchaseService
    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?

    init(service: PurchaseService, defaults: UserDefaults) {
        self.service = service
        self.defaults = defaults
        isPro = defaults.bool(forKey: Self.cachedKey)
        updatesTask = service.observeChanges { [weak self] owns in self?.set(owns) }
    }

    deinit { updatesTask?.cancel() }

    /// Checks ownership with the App Store and loads the localized price.
    func refresh() async {
        set(await service.ownsPro())
        if price == nil { price = await service.displayPrice() }
    }

    func buy() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await service.purchase() {
            case .purchased:
                set(true)
                message = nil
            case .pending:
                message = "Your purchase is waiting for approval. Pro unlocks as soon as it's approved."
            case .cancelled:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.restore()
            let owns = await service.ownsPro()
            set(owns)
            message = owns ? nil : "No SpendLite Pro purchase was found for this Apple Account."
        } catch {
            message = error.localizedDescription
        }
    }

    // MARK: - Limits

    /// True when a free user has used up their recurring expenses.
    func recurringLimitReached(currentCount: Int) -> Bool {
        !isPro && currentCount >= Self.freeRecurringLimit
    }

    private func set(_ owns: Bool) {
        guard owns != isPro || defaults.object(forKey: Self.cachedKey) == nil else { return }
        isPro = owns
        defaults.set(owns, forKey: Self.cachedKey)
        onChange?(owns)
    }
}
