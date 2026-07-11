//
//  GameSelectionView.swift
//  DiceCalc
//
//  First-run game picker. The selected game controls which ruleset flow opens.
//
//  Support-tip note:
//  This is a UI-first preview only. It adds a separate Help Support entry
//  on the Choose Game screen and shows three tip options in a sheet.
//  StoreKit purchase wiring will be added later.
//

import SwiftUI
import StoreKit // Needed for Product display metadata like displayPrice.


struct GameSelectionView: View {
    @Binding var selectedGameSystemRawValue: String

    /// Controls presentation of the support-tip preview sheet.
    /// This keeps the support flow separate from actual game selection.
    @State private var showSupportTips = false

    #if DEBUG
    @State private var showNapoleonicsDataDebug = false
    @State private var showAncientsDataDebug = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(GameSystem.allCases) { gameSystem in
                        Button {
                            guard gameSystem.isSelectable else { return }
                            selectedGameSystemRawValue = gameSystem.rawValue
                        } label: {
                            GameSelectionRow(gameSystem: gameSystem)
                        }
                        .buttonStyle(.plain)
                        .disabled(!gameSystem.isSelectable)
                    }
                } header: {
                    Text("Choose Game")
                } footer: {
                    Text("DiceCalc uses the selected game to choose the right units, terrain, rules, and explanations.")
                }

                // Separate support entry so it does not get mixed into the ruleset picker.
                Section {
                    Button {
                        showSupportTips = true
                    } label: {
                        SupportEntryRow()
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Help Support")
                } footer: {
                    // Keep the message short and friendly.
                    Text("Optional tips help support future updates.")
                }
            }
            .navigationTitle("DiceCalc")
            .sheet(isPresented: $showSupportTips) {
                SupportTipView()
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Napoleonics Data") { showNapoleonicsDataDebug = true }
                        Button("Ancients Data") { showAncientsDataDebug = true }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showNapoleonicsDataDebug) {
                NapoleonicsDataDebugView()
            }
            .sheet(isPresented: $showAncientsDataDebug) {
                AncientsDataDebugView()
            }
            #endif
        }
    }
}

private struct GameSelectionRow: View {
    let gameSystem: GameSystem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gameSystem.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(gameSystem.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if gameSystem.isSelectable {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Coming Soon")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Row shown on the Choose Game screen that opens the support-tip preview.
private struct SupportEntryRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.pink)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("Support DiceCalc")
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Shorter subtitle so the row feels lighter on iPhone.
                Text("Optional tips to help support future updates.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

/// UI-first preview sheet for future consumable support tips.
/// Buttons do not purchase yet; they are placeholders so the flow can be reviewed.
private struct SupportTipView: View {
    @Environment(\.dismiss) private var dismiss

    // Lightweight StoreKit loader for the support sheet.
    // This only fetches products for now; purchase handling comes later.
    @StateObject private var supportTipStore = SupportTipStore()

    // UI-first metadata for the support-tip rows.
    // productID links each visual row to its StoreKit product when available.
    private let tipOptions: [SupportTipOption] = [
        .init(
            title: "A little boost",
            productID: SupportTipStore.ProductID.littleBoost,
            symbolName: "sparkles",
            tint: .blue,
            detail: "A small thank-you tip."
        ),
        .init(
            title: "The Sweet Spot",
            productID: SupportTipStore.ProductID.sweetSpot,
            symbolName: "heart.fill",
            tint: .pink,
            detail: "A solid way to support updates."
        ),
        .init(
            title: "THE LEGEND",
            productID: SupportTipStore.ProductID.legend,
            symbolName: "crown.fill",
            tint: .orange,
            detail: "The big legendary tip."
        )
    ]


    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Support DiceCalc")
                            .font(.title3.weight(.semibold))

                        // Keep this friendly and open-ended.
                        // Tips are optional and may be given again later.
                        Text("Optional support tips. They do not change gameplay or rules.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if let purchaseMessage = supportTipStore.purchaseMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)

                            Text(purchaseMessage)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    ForEach(tipOptions) { option in
                        Button {
                            // Start the tip purchase flow for this option.
                            // UI stays simple; detailed messaging can be added after behavior is confirmed.
                            Task {
                                await supportTipStore.purchaseTip(with: option.productID)
                            }
                        } label: {
                            SupportTipOptionRow(
                                option: option,
                                priceText: supportTipStore.product(for: option.productID)?.displayPrice
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    // Keep the call to action simple and direct.
                    Text("Support DiceCalc")
                } footer: {
                    // Keep the footer tied to StoreKit load state,
                    // but use simpler player-facing wording now that testing is working.
                    switch supportTipStore.loadState {
                    case .idle, .loading:
                        Text("Loading prices...")
                    case .loaded:
                        // Tips are optional, so the loaded-state message can stay lightweight.
                        Text("Tips are optional and do not affect gameplay.")
                    case .failed:
                        // Keep failure wording plain and temporary rather than technical.
                        Text("Prices are temporarily unavailable.")
                    }
                }
            }
            .navigationTitle("Help Support")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Load StoreKit product metadata when the sheet appears.
                await supportTipStore.loadProducts()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Reusable display row for each support-tip option.
private struct SupportTipOptionRow: View {
    let option: SupportTipOption
    let priceText: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: option.symbolName)
                .font(.title3)
                .foregroundStyle(option.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(option.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Show the real StoreKit display price when available.
            // While products are still loading, use a neutral placeholder
            // instead of preview-style development wording.
            Text(priceText ?? "Loading...")
                .font(.caption.weight(.semibold))
                .foregroundStyle(priceText == nil ? .tertiary : .secondary)
        }
        .padding(.horizontal, 12) // Add a little in-card breathing room.
        .padding(.vertical, 10)   // Make the rows feel more intentional and tappable.
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground)) // Subtle card surface that still feels native.
        )
    }
}


/// Small local model for the support-tip preview rows.
private struct SupportTipOption: Identifiable {
    let id = UUID()
    let title: String
    let productID: String
    let symbolName: String
    let tint: Color
    let detail: String
}

