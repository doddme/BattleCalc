//
//  CombatEntryDebugView.swift
//  BattleCalc
//
//  Debug-only screen reached from the DEBUG button on the combat-entry screen.
//  It shows the trace for the most recent battle (the engine's applied rules
//  plus the context that produced them) and embeds the existing CSV-backed
//  smoke-test runner. Entire file is compiled only in debug builds.
//

#if DEBUG
import SwiftUI

struct CombatEntryDebugView: View {
    @Environment(\.dismiss) private var dismiss

    let trace: [AppliedRule]
    let context: CombatContext?

    var body: some View {
        NavigationStack {
            List {
                currentBattleSection
                traceSection
                smokeTestSection
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder private var currentBattleSection: some View {
        Section("Current battle input") {
            if let c = context {
                LabeledContent("Mode", value: c.combatMode == .melee ? "Melee" : "Ranged")
                LabeledContent("Target distance", value: c.targetDistance.map(String.init) ?? "—")
                LabeledContent("Moved hexes", value: c.movedHexes.map(String.init) ?? "—")
                LabeledContent("Attacker", value: "\(c.attackerUnitID) · \(c.attackerBlocks) blk · \(c.attackerTerrainID ?? "Clear")")
                LabeledContent("Defender", value: "\(c.defenderUnitID) · \(c.defenderBlocks) blk · \(c.defenderTerrainID ?? "Clear")")

                // Show Napoleonics combined-attack support fields explicitly so we
                // can verify whether the support-unit selections actually made it
                // into the runtime CombatContext. This is especially useful when
                // the trace shows only artillery base + final result, which means
                // the combined-attack branch may have been skipped entirely.
                
                if showsNapoleonicsCombinedAttackDebug {
                    // Show Napoleonics combined-attack support fields explicitly so we
                    // can verify whether the support-unit selections actually made it
                    // into the runtime CombatContext. This is especially useful when
                    // the trace shows only artillery base + final result, which means
                    // the combined-attack branch may have been skipped entirely.
                    LabeledContent("Combined attack", value: c.isCombinedAttack ? "Yes" : "No")
                    LabeledContent("Supporting unit", value: c.supportingUnitID ?? "—")
                    LabeledContent("Supporting blocks", value: c.supportingUnitBlocks.map(String.init) ?? "—")
                    LabeledContent("Supporting terrain", value: c.supportingUnitTerrainID ?? "—")
                    LabeledContent("Supporting Country", value: c.supportingUnitCountryID ?? "—")
                    LabeledContent("Supporting in square", value: c.supportingUnitInSquare ? "Yes" : "No")
                    LabeledContent("Support moved into melee", value: c.supportingUnitMovedIntoMelee ? "Yes" : "No")
                }

            } else {

                Text("No complete battle entered yet.").foregroundStyle(.secondary)
            }
        }
    }

    
    // The extra combined-attack debug rows are Napoleonics-specific for now.
    // Keep the base debug info visible for every game, but only show the
    // support-unit fields when the current context looks like a Napoleonics battle.
    private var showsNapoleonicsCombinedAttackDebug: Bool {
        guard let c = context else { return false }

        return c.isCombinedAttack
            || c.supportingUnitID != nil
            || c.supportingUnitBlocks != nil
            || c.supportingUnitTerrainID != nil
            || c.supportingUnitCountryID != nil
            || c.supportingUnitInSquare
            || c.supportingUnitMovedIntoMelee
    }

    
    
    @ViewBuilder private var traceSection: some View {
        Section("Most-recent battle trace") {
            if trace.isEmpty {
                Text("No battle computed yet.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(trace.enumerated()), id: \.offset) { index, rule in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(index + 1). \(rule.title)")
                        Text(rule.outcome).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder private var smokeTestSection: some View {
        Section("Smoke test — NapoleonicsCombatSamples.csv") {
            // Reuse the existing CSV-backed smoke-test screen unchanged.
            NavigationLink("Run smoke test") {
                NapoleonicsCombatDebugView()
            }
        }
    }
}
#endif
