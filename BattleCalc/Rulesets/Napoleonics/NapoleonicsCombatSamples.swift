//
//   NapoleonicsCombatSamples.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/13/26.
//

//
//  NapoleonicsCombatSamples.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/13/26.
//

import Foundation

private struct CombatSampleCSVRow {
    let id: String
    let name: String
    let movedHexes: String
    let targetDistance: String
    let attackerUnitID: String
    let attackerBlocks: String
    let attackerTerrainID: String
    let defenderUnitID: String
    let defenderBlocks: String
    let defenderTerrainID: String
    let expectedAllowed: String
    let expectedFinalDice: String
}

struct NapoleonicsCombatSample: Identifiable, Hashable {
    let id: String
    let name: String
    let context: CombatContext
    let expectedAllowed: Bool
    let expectedFinalDice: Int?
}

enum CombatSampleLoadError: Error, LocalizedError {
    case fileNotFound(String)
    case unreadableFile(String)
    case invalidRow(String)
    case invalidValue(field: String, value: String, sampleID: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Could not find \(fileName) in the app bundle."
        case .unreadableFile(let fileName):
            return "Could not read \(fileName) from the app bundle."
        case .invalidRow(let row):
            return "Invalid combat sample CSV row: \(row)"
        case .invalidValue(let field, let value, let sampleID):
            return "Invalid value '\(value)' for field '\(field)' in combat sample '\(sampleID)'."
        }
    }
}

enum NapoleonicsCombatSampleLoader {

    static func loadSamples() throws -> [NapoleonicsCombatSample] {
        let fileName = "NapoleonicsCombatSamples"
        let fileExtension = "csv"

        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            throw CombatSampleLoadError.fileNotFound("\(fileName).\(fileExtension)")
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CombatSampleLoadError.unreadableFile("\(fileName).\(fileExtension)")
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else { return [] }

        let dataLines = lines.dropFirst()
        var samples: [NapoleonicsCombatSample] = []

        for line in dataLines {
            let columns = line
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            guard columns.count >= 12 else {
                throw CombatSampleLoadError.invalidRow(line)
            }

            let row = CombatSampleCSVRow(
                id: columns[0],
                name: columns[1],
                movedHexes: columns[2],
                targetDistance: columns[3],
                attackerUnitID: columns[4],
                attackerBlocks: columns[5],
                attackerTerrainID: columns[6],
                defenderUnitID: columns[7],
                defenderBlocks: columns[8],
                defenderTerrainID: columns[9],
                expectedAllowed: columns[10],
                expectedFinalDice: columns[11]
            )

            samples.append(try makeSample(from: row))
        }

        return samples
    }

    private static func makeSample(from row: CombatSampleCSVRow) throws -> NapoleonicsCombatSample {
        let movedHexes = try parseInt(row.movedHexes, field: "movedHexes", sampleID: row.id)
        let targetDistance = try parseOptionalInt(row.targetDistance, field: "targetDistance", sampleID: row.id)
        let attackerTerrainID = normalizeOptionalString(row.attackerTerrainID)
        let defenderTerrainID = normalizeOptionalString(row.defenderTerrainID)

        let combatMode: CombatMode = (targetDistance == 1) ? .melee : .ranged

        guard let attackerUnit = NapoleonicsUnitLibrary.unit(for: row.attackerUnitID) else {
            throw CombatSampleLoadError.invalidValue(
                field: "attackerUnitID",
                value: row.attackerUnitID,
                sampleID: row.id
            )
        }

        guard let defenderUnit = NapoleonicsUnitLibrary.unit(for: row.defenderUnitID) else {
            throw CombatSampleLoadError.invalidValue(
                field: "defenderUnitID",
                value: row.defenderUnitID,
                sampleID: row.id
            )
        }

        let context = CombatContext(
            combatMode: combatMode,
            movedHexes: movedHexes,
            targetDistance: targetDistance,
            attackerCountryID: attackerUnit.countryID,
            attackerUnitID: row.attackerUnitID,
            attackerBlocks: try parseInt(row.attackerBlocks, field: "attackerBlocks", sampleID: row.id),
            attackerTerrainID: attackerTerrainID,
            defenderCountryID: defenderUnit.countryID,
            defenderUnitID: row.defenderUnitID,
            defenderBlocks: try parseInt(row.defenderBlocks, field: "defenderBlocks", sampleID: row.id),
            defenderTerrainID: defenderTerrainID,
            attackDirection: .flat
        )

        return NapoleonicsCombatSample(
            id: row.id,
            name: row.name,
            context: context,
            expectedAllowed: try parseBool(row.expectedAllowed, field: "expectedAllowed", sampleID: row.id),
            expectedFinalDice: try parseOptionalInt(row.expectedFinalDice, field: "expectedFinalDice", sampleID: row.id)
        )
    }


    private static func normalizeOptionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.lowercased() == "clear" { return nil }
        return trimmed
    }

    private static func parseBool(_ value: String, field: String, sampleID: String) throws -> Bool {
        switch value.uppercased() {
        case "TRUE": return true
        case "FALSE": return false
        default:
            throw CombatSampleLoadError.invalidValue(field: field, value: value, sampleID: sampleID)
        }
    }

    private static func parseInt(_ value: String, field: String, sampleID: String) throws -> Int {
        guard let intValue = Int(value) else {
            throw CombatSampleLoadError.invalidValue(field: field, value: value, sampleID: sampleID)
        }
        return intValue
    }

    private static func parseOptionalInt(_ value: String, field: String, sampleID: String) throws -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let intValue = Int(trimmed) else {
            throw CombatSampleLoadError.invalidValue(field: field, value: value, sampleID: sampleID)
        }
        return intValue
    }
}

struct NapoleonicsCombatSampleFailure: Identifiable {
    let id: String
    let sample: NapoleonicsCombatSample
    let result: CombatResult
    let mismatches: [String]
}

struct NapoleonicsCombatSampleReport {
    let totalCount: Int
    let passedCount: Int
    let failures: [NapoleonicsCombatSampleFailure]

    var allPassed: Bool {
        failures.isEmpty
    }

    var summaryText: String {
        if allPassed {
            return "Combat smoke test passed: \(passedCount) of \(totalCount) samples succeeded."
        } else {
            return "Combat smoke test failed: \(failures.count) of \(totalCount) samples had mismatches."
        }
    }
}

enum NapoleonicsCombatSampleRunner {

    static func runAll(using evaluator: NapoleonicsInfantryCombatEvaluator = NapoleonicsInfantryCombatEvaluator()) -> NapoleonicsCombatSampleReport {
        do {
            let samples = try NapoleonicsCombatSampleLoader.loadSamples()
            var failures: [NapoleonicsCombatSampleFailure] = []

            for sample in samples {
                let result = evaluator.evaluate(context: sample.context)
                let mismatches = compare(sample: sample, result: result)

                if !mismatches.isEmpty {
                    failures.append(
                        NapoleonicsCombatSampleFailure(
                            id: sample.id,
                            sample: sample,
                            result: result,
                            mismatches: mismatches
                        )
                    )
                }
            }

            return NapoleonicsCombatSampleReport(
                totalCount: samples.count,
                passedCount: samples.count - failures.count,
                failures: failures
            )
        } catch {
            let pseudoSample = NapoleonicsCombatSample(
                id: "load-error",
                name: "Combat sample load error",
                context: CombatContext(
                    combatMode: .melee,
                    movedHexes: 0,
                    targetDistance: 1,
                    attackerCountryID: "unknown",
                    attackerUnitID: "unknown",
                    attackerBlocks: 0,
                    attackerTerrainID: nil,
                    defenderCountryID: "unknown",
                    defenderUnitID: "unknown",
                    defenderBlocks: 0,
                    defenderTerrainID: nil,
                    attackDirection: .flat
                ),
                expectedAllowed: false,
                expectedFinalDice: nil
            )


            let result = CombatResult(
                validation: CombatValidation(isAllowed: false, reasons: [error.localizedDescription]),
                baseDice: nil,
                modifiers: [],
                modifierTotal: 0,
                finalDice: nil,
                notes: [],
                appliedRules: []
            )

            return NapoleonicsCombatSampleReport(
                totalCount: 0,
                passedCount: 0,
                failures: [
                    NapoleonicsCombatSampleFailure(
                        id: pseudoSample.id,
                        sample: pseudoSample,
                        result: result,
                        mismatches: ["Could not load combat samples."]
                    )
                ]
            )
        }
    }

    private static func compare(sample: NapoleonicsCombatSample, result: CombatResult) -> [String] {
        var mismatches: [String] = []

        if result.validation.isAllowed != sample.expectedAllowed {
            mismatches.append(
                "Expected allowed = \(sample.expectedAllowed), actual = \(result.validation.isAllowed)."
            )
        }

        if !diceMatches(sample: sample, result: result) {
            mismatches.append(
                "Expected finalDice = \(describe(sample.expectedFinalDice)), actual = \(describe(result.finalDice))."
            )
        }

        return mismatches
    }

    private static func diceMatches(sample: NapoleonicsCombatSample, result: CombatResult) -> Bool {
        if sample.expectedAllowed == false && result.validation.isAllowed == false {
            let expected = sample.expectedFinalDice ?? 0
            let actual = result.finalDice ?? 0
            return expected == actual
        }

        return sample.expectedFinalDice == result.finalDice
    }


    private static func describe(_ value: Int?) -> String {
        guard let value else { return "nil" }
        return String(value)
    }

    static func formattedReport(_ report: NapoleonicsCombatSampleReport) -> String {
        var lines: [String] = [report.summaryText]

        guard !report.failures.isEmpty else {
            return lines.joined(separator: "\n")
        }

        for failure in report.failures {
            lines.append("")
            lines.append("=== \(failure.sample.id): \(failure.sample.name) ===")
            lines.append("Mismatches:")
            failure.mismatches.forEach { lines.append("- \($0)") }

            let context = failure.sample.context
            lines.append("Input:")
            lines.append("- Mode: \(context.combatMode)")
            lines.append("- Moved hexes: \(context.movedHexes.map(String.init) ?? "not set")")


            lines.append("- Target distance: \(context.targetDistance.map(String.init) ?? "nil")")
            lines.append("- Attacker: \(context.attackerUnitID) blocks=\(context.attackerBlocks) terrain=\(context.attackerTerrainID ?? "clear")")
            lines.append("- Defender: \(context.defenderUnitID) blocks=\(context.defenderBlocks) terrain=\(context.defenderTerrainID ?? "clear")")

            lines.append("Expected:")
            lines.append("- Allowed: \(failure.sample.expectedAllowed)")
            lines.append("- Final dice: \(describe(failure.sample.expectedFinalDice))")

            lines.append("Actual:")
            lines.append("- Allowed: \(failure.result.validation.isAllowed)")
            lines.append("- Final dice: \(describe(failure.result.finalDice))")

            if !failure.result.validation.reasons.isEmpty {
                lines.append("Reasons:")
                failure.result.validation.reasons.forEach { lines.append("- \($0)") }
            }

            if !failure.result.notes.isEmpty {
                lines.append("Notes:")
                failure.result.notes.forEach { lines.append("- \($0)") }
            }

            if !failure.result.appliedRules.isEmpty {
                lines.append("Applied rules:")
                for rule in failure.result.appliedRules {
                    lines.append("- \(rule.title): \(rule.outcome)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
