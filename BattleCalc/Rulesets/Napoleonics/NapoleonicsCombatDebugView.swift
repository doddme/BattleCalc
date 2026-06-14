//
//  NapoleonicsCombatDebugView.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/11/26.
//

import SwiftUI

/// Temporary debug screen for running CSV-backed smoke tests.
/// When all samples pass, it stays quiet and shows only a summary.
/// When any sample fails, it expands into full diagnostic detail.
struct NapoleonicsCombatDebugView: View {

    private let evaluator = NapoleonicsInfantryCombatEvaluator()

    private var report: NapoleonicsCombatSampleReport {
        NapoleonicsCombatSampleRunner.runAll(using: evaluator)
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection(report: report)

                if !report.allPassed {
                    ForEach(report.failures) { failure in
                        failureSection(failure)
                    }
                }
            }
            .navigationTitle("Combat Debug")
        }
    }

    @ViewBuilder
    private func summarySection(report: NapoleonicsCombatSampleReport) -> some View {
        Section("Smoke Test Summary") {
            LabeledContent("Result", value: report.allPassed ? "Passed" : "Failed")
            LabeledContent("Samples Run", value: String(report.totalCount))
            LabeledContent("Samples Passed", value: String(report.passedCount))
            LabeledContent("Samples Failed", value: String(report.failures.count))

            Text(report.summaryText)
                .foregroundStyle(report.allPassed ? .green : .red)
        }
    }

    @ViewBuilder
    private func failureSection(_ failure: NapoleonicsCombatSampleFailure) -> some View {
        let sample = failure.sample
        let context = sample.context
        let result = failure.result

        Section("\(sample.id): \(sample.name)") {
            Group {
                Text("Mismatches")
                    .font(.headline)

                ForEach(failure.mismatches, id: \.self) { mismatch in
                    Text("• \(mismatch)")
                }
            }

            Group {
                Text("Input")
                    .font(.headline)

                LabeledContent(
                    "Combat Mode",
                    value: context.combatMode == .melee ? "Melee" : "Ranged"
                )

                LabeledContent(
                    "Moved Hexes",
                    value: context.movedHexes.map(String.init) ?? "—"
                )

                LabeledContent(
                    "Target Distance",
                    value: context.targetDistance.map(String.init) ?? "—"
                )

                LabeledContent(
                    "Attacker Unit ID",
                    value: context.attackerUnitID
                )

                LabeledContent(
                    "Defender Unit ID",
                    value: context.defenderUnitID
                )

                LabeledContent(
                    "Attacker Blocks",
                    value: String(context.attackerBlocks)
                )

                LabeledContent(
                    "Defender Blocks",
                    value: String(context.defenderBlocks)
                )

                LabeledContent(
                    "Attacker Terrain",
                    value: context.attackerTerrainID ?? "clear"
                )

                LabeledContent(
                    "Defender Terrain",
                    value: context.defenderTerrainID ?? "clear"
                )
            }

            Group {
                Text("Expected")
                    .font(.headline)

                LabeledContent(
                    "Allowed",
                    value: sample.expectedAllowed ? "Yes" : "No"
                )

                LabeledContent(
                    "Final Dice",
                    value: sample.expectedFinalDice.map(String.init) ?? "—"
                )
            }

            Group {
                Text("Actual")
                    .font(.headline)

                LabeledContent(
                    "Allowed",
                    value: result.validation.isAllowed ? "Yes" : "No"
                )

                LabeledContent(
                    "Base Dice",
                    value: result.baseDice.map(String.init) ?? "—"
                )

                LabeledContent(
                    "Modifier Total",
                    value: String(result.modifierTotal)
                )

                LabeledContent(
                    "Final Dice",
                    value: result.finalDice.map(String.init) ?? "—"
                )
            }

            if !result.validation.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reasons")
                        .font(.headline)

                    ForEach(result.validation.reasons, id: \.self) { reason in
                        Text("• \(reason)")
                    }
                }
            }

            if !result.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.headline)

                    ForEach(result.notes, id: \.self) { note in
                        Text("• \(note)")
                    }
                }
            }

            if !result.modifiers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Modifiers")
                        .font(.headline)

                    ForEach(result.modifiers) { modifier in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(modifier.label): \(modifier.value)")

                            if let detail = modifier.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !result.appliedRules.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Applied Rules")
                        .font(.headline)

                    ForEach(result.appliedRules) { rule in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.title)

                            Text(rule.outcome)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
