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
                LabeledContent("Attacker", value: "\(c.attackerUnitID) · \(c.attackerBlocks) blk · \(c.attackerTerrainID ?? "clear")")
                LabeledContent("Defender", value: "\(c.defenderUnitID) · \(c.defenderBlocks) blk · \(c.defenderTerrainID ?? "clear")")
            } else {
                Text("No complete battle entered yet.").foregroundStyle(.secondary)
            }
        }
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
        Section("Smoke test — CombatSamples.csv") {
            // Reuse the existing CSV-backed smoke-test screen unchanged.
            NavigationLink("Run smoke test") {
                NapoleonicsCombatDebugView()
            }
        }
    }
}
#endif
