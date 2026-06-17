//
//  AncientsDataDebugView.swift
//  BattleCalc
//
//  Read-only DEBUG screen for confirming Ancients CSV data loads before the
//  game is selectable or wired into combat resolution.
//

import SwiftUI

#if DEBUG
struct AncientsDataDebugView: View {
    private let units = AncientsUnitLibrary.all
    private let terrains = AncientsTerrainLibrary.all
    private let samples = AncientsCombatSampleLibrary.all
    private let sampleReport = AncientsCombatSampleRunner.runAll()

    var body: some View {
        NavigationStack {
            List {
                summarySection
                smokeTestSection
                unitClassSection
                terrainSection
                sampleSection
            }
            .navigationTitle("Ancients Data")
        }
    }

    private var summarySection: some View {
        Section("Loaded CSV Data") {
            LabeledContent("Units", value: "\(units.count)")
            LabeledContent("Terrain", value: "\(terrains.count)")
            LabeledContent("Combat samples", value: "\(samples.count)")
        }
    }

    private var smokeTestSection: some View {
        Section("Draft Smoke Tests") {
            LabeledContent("Passed", value: "\(sampleReport.passed) / \(sampleReport.total)")
            LabeledContent("Failed", value: "\(sampleReport.failed)")

            ForEach(sampleReport.failures.prefix(8)) { failure in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(failure.sample.id): \(failure.sample.name)")
                        .font(.headline)
                    ForEach(failure.messages, id: \.self) { message in
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var unitClassSection: some View {
        Section("Units by Class") {
            ForEach(unitClassCounts, id: \.name) { entry in
                LabeledContent(entry.name, value: "\(entry.count)")
            }
        }
    }

    private var terrainSection: some View {
        Section("Terrain") {
            ForEach(terrains.sorted { $0.name < $1.name }) { terrain in
                VStack(alignment: .leading, spacing: 4) {
                    Text(terrain.name)
                        .font(.headline)
                    Text(terrainDetail(for: terrain))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var sampleSection: some View {
        Section("Combat Samples") {
            ForEach(samples.prefix(12)) { sample in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sample.name)
                        .font(.headline)
                    Text("\(sample.attackerUnitID) → \(sample.defenderUnitID) · expected \(sample.expectedFinalDice) dice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            if samples.count > 12 {
                Text("Showing first 12 of \(samples.count) samples.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unitClassCounts: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: units, by: { $0.unitClass })
        return grouped
            .map { (name: displayName(forUnitClass: $0.key), count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    private func terrainDetail(for terrain: AncientsTerrainDefinition) -> String {
        var parts: [String] = []

        if terrain.blocksLineOfSight {
            parts.append("blocks LOS")
        }
        if terrain.blocksBattleOnEntry {
            parts.append("blocks battle on entry")
        }
        if let meleeMaxDice = terrain.meleeMaxDice {
            parts.append("melee max \(meleeMaxDice)")
        }
        if let rangedMaxDice = terrain.rangedMaxDice {
            parts.append("ranged max \(rangedMaxDice)")
        }

        return parts.isEmpty ? "No terrain limits recorded" : parts.joined(separator: " · ")
    }

    private func displayName(forUnitClass id: String) -> String {
        id
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
#endif
