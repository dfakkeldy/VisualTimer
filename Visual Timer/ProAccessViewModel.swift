import Foundation
import Combine
import StoreKit

@MainActor
final class ProAccessViewModel: ObservableObject {

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case purchased
        case pending
        case failed(String)
    }

    @Published private(set) var product: Product?
    @Published private(set) var isProUnlocked = false
    @Published private(set) var purchaseState: PurchaseState = .idle

    private var transactionTask: Task<Void, Never>?

    var displayPrice: String {
        product?.displayPrice ?? ProProduct.fallbackDisplayPrice
    }

    init(automaticallyStartsStoreKitTasks: Bool = true) {
        guard automaticallyStartsStoreKitTasks else { return }
        transactionTask = observeTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionTask?.cancel()
    }

    func loadProducts() async {
        purchaseState = .loading
        do {
            let products = try await Product.products(for: Array(ProProduct.unlockIDs))
            product = products.first { $0.id == ProProduct.unlockID }
            purchaseState = isProUnlocked ? .purchased : .idle
        } catch {
            purchaseState = .failed("Unable to load Pro purchase.")
        }
    }

    func purchasePro() async {
        if product == nil {
            await loadProducts()
        }

        guard let product else {
            purchaseState = .failed("Unable to load Pro purchase.")
            return
        }

        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = verifiedTransaction(from: verification) else {
                    purchaseState = .failed("The purchase could not be verified.")
                    return
                }
                await grantEntitlement(for: transaction)
                await transaction.finish()
                purchaseState = .purchased
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = isProUnlocked ? .purchased : .idle
            @unknown default:
                purchaseState = .failed("The purchase could not be completed.")
            }
        } catch {
            purchaseState = .failed("The purchase could not be completed.")
        }
    }

    func restorePurchases() async {
        purchaseState = .loading
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = isProUnlocked ? .purchased : .idle
        } catch {
            purchaseState = .failed("Restore failed. Please try again.")
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result),
                  ProProduct.unlockIDs.contains(transaction.productID),
                  transaction.revocationDate == nil
            else { continue }
            unlocked = true
        }
        applyEntitlementRefreshResult(isUnlocked: unlocked)
    }

    func applyEntitlementRefreshResult(isUnlocked unlocked: Bool) {
        isProUnlocked = unlocked
        purchaseState = unlocked ? .purchased : .idle
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard let transaction = verifiedTransaction(from: transactionResult) else { return }
        if ProProduct.unlockIDs.contains(transaction.productID), transaction.revocationDate == nil {
            await grantEntitlement(for: transaction)
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func grantEntitlement(for transaction: Transaction) async {
        if ProProduct.unlockIDs.contains(transaction.productID), transaction.revocationDate == nil {
            isProUnlocked = true
        }
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }
}
