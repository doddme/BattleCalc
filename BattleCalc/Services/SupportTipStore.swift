//
//  SupportTipStore.swift
//  DiceCalc
//
//  Created by Mike Dodd on 7/11/26.
//  Lightweight StoreKit scaffolding for optional support tips.
//  This file only loads products and exposes state for the UI.
//  Purchase handling can be added later once the UI is finalized.
//

import Foundation
import Combine // Needed for ObservableObject and @Published.
import StoreKit

@MainActor
final class SupportTipStore: ObservableObject {

    /// UI-facing loading state for the support screen.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Product IDs for the three repeatable consumable tips.
    /// Keep these together so the UI and App Store Connect stay in sync.
    /// TODO: Match the app's real bundle identifier so App Store Connect setup stays consistent.

    enum ProductID {
        static let littleBoost = "com.mikedodd.dicecalc.tip.alittleboost"
        static let sweetSpot = "com.mikedodd.dicecalc.tip.thesweetspot"
        static let legend = "com.mikedodd.dicecalc.tip.thelegend"

        static let all: [String] = [
            littleBoost,
            sweetSpot,
            legend
        ]
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: LoadState = .idle

    /// Lightweight UI feedback shown after a successful tip purchase.
    /// Keep this app-owned so we do not interfere with StoreKit's system dialogs.
    @Published var purchaseMessage: String?

    init() {
        // Start listening as soon as the store object is created.
        // This is the smallest safe fix for the StoreKit warning.
        transactionUpdatesTask = observeTransactionUpdates()
    }

    deinit {
        // Cancel the background listener when the store goes away.
        transactionUpdatesTask?.cancel()
    }

    
    
    /// Background listener for StoreKit transaction updates.
    /// Apple recommends listening at app launch so completed purchases
    /// are not missed if they resolve outside the immediate purchase call.
    private var transactionUpdatesTask: Task<Void, Never>?

    
    /// Listens for StoreKit transaction updates that may complete
    /// outside the direct purchase() result path.
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            for await verificationResult in Transaction.updates {
                switch verificationResult {
                case .verified(let transaction):
                    // Consumable support tips do not unlock app content,
                    // so for now we simply finish the verified transaction
                    // and show the same lightweight thank-you feedback.
                    purchaseMessage = "Thank you for supporting DiceCalc."
                    await transaction.finish()

                case .unverified(_, let error):
                    // Keep unverified transactions out of the happy path.
                    print("SupportTipStore: Unverified transaction update – \(error.localizedDescription)")
                }
            }
        }
    }

    
    /// Loads the support-tip products from StoreKit.
    /// Safe to call more than once; it simply refreshes the cached list.
    func loadProducts() async {
        loadState = .loading

        do {
            let fetchedProducts = try await Product.products(for: ProductID.all)

            // Debug: log the raw products returned so you can see ids and titles.
            print("SupportTipStore: fetched products:", fetchedProducts.map(\.id))

            // Keep the display order stable so the UI matches the designed tip order.
            let orderedProducts = ProductID.all.compactMap { productID in
                fetchedProducts.first(where: { $0.id == productID })
            }

            products = orderedProducts
            loadState = .loaded

        } catch {
            products = []
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Starts a consumable tip purchase for the given product ID.
    /// This keeps StoreKit handling simple and only publishes a lightweight
    /// in-app thank-you message after a successful purchase.
    func purchaseTip(with productID: String) async {
        guard let product = product(for: productID) else {
            // Clear, app-owned fallback if a configured product is missing.
            purchaseMessage = "This support option is not available right now."
            print("SupportTipStore: No product found for id \(productID)")
            return
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                // Keep StoreKit handling explicit and minimal:
                // verified transactions get thanked and finished,
                // unverified transactions stay out of the success path.
                switch verificationResult {
                case .verified(let transaction):
                    print("SupportTipStore: Purchase success for \(product.id)")
                    purchaseMessage = "Thank you for supporting DiceCalc."
                    await transaction.finish()

                case .unverified(_, let error):
                    purchaseMessage = "Purchase could not be verified."
                    print("SupportTipStore: Unverified purchase for \(product.id) – \(error.localizedDescription)")
                }

            case .userCancelled:
                // Do not show an error-style message for a normal cancel path.
                print("SupportTipStore: Purchase cancelled by user for \(product.id)")

            case .pending:
                // Optional mild status feedback for deferred/pending flows.
                purchaseMessage = "Purchase is pending approval."
                print("SupportTipStore: Purchase pending for \(product.id)")

            @unknown default:
                print("SupportTipStore: Unknown purchase result for \(product.id)")
            }
        } catch {
            // Keep failure feedback lightweight and local to the sheet.
            purchaseMessage = "Purchase could not be completed."
            print("SupportTipStore: Purchase failed for \(product.id) – \(error.localizedDescription)")
        }
    }

    /// Convenience lookup for a specific product ID.
    func product(for productID: String) -> Product? {
        products.first(where: { $0.id == productID })
    }
}


