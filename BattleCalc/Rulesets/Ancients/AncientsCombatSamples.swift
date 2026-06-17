//
//  AncientsCombatSamples.swift
//  BattleCalc
//
//  Smoke-test data holder for the future Ancients evaluator. These samples are
//  not executed until Ancients combat rules are wired in.
//

import Foundation

struct AncientsCombatSample: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let movedHexes: Int
    let targetDistance: Int
    let attackerUnitID: String
    let attackerBlocks: Int
    let attackerTerrainID: String?
    let defenderUnitID: String
    let defenderBlocks: Int
    let defenderTerrainID: String?
    let expectedAllowed: Bool
    let expectedFinalDice: Int
}

enum AncientsCombatSampleCSVLoader {
    private static let resourceName = "AncientsCombatSamples"

    private static let requiredHeaders = [
        "id", "name", "movedHexes", "targetDistance", "attackerUnitID",
        "attackerBlocks", "attackerTerrainID", "defenderUnitID", "defenderBlocks",
        "defenderTerrainID", "expectedAllowed", "expectedFinalDice"
    ]

    static func loadSamples() throws -> [AncientsCombatSample] {
        try AncientsCSV.loadRows(resourceName: resourceName, requiredHeaders: requiredHeaders).map { row in
            let id = row["id"] ?? ""
            return AncientsCombatSample(
                id: id,
                name: row["name"] ?? "",
                movedHexes: try AncientsCSV.int(row["movedHexes"] ?? "", field: "movedHexes", rowID: id),
                targetDistance: try AncientsCSV.int(row["targetDistance"] ?? "", field: "targetDistance", rowID: id),
                attackerUnitID: row["attackerUnitID"] ?? "",
                attackerBlocks: try AncientsCSV.int(row["attackerBlocks"] ?? "", field: "attackerBlocks", rowID: id),
                attackerTerrainID: (row["attackerTerrainID"] ?? "").isEmpty ? nil : row["attackerTerrainID"],
                defenderUnitID: row["defenderUnitID"] ?? "",
                defenderBlocks: try AncientsCSV.int(row["defenderBlocks"] ?? "", field: "defenderBlocks", rowID: id),
                defenderTerrainID: (row["defenderTerrainID"] ?? "").isEmpty ? nil : row["defenderTerrainID"],
                expectedAllowed: try AncientsCSV.bool(row["expectedAllowed"] ?? "", field: "expectedAllowed", rowID: id),
                expectedFinalDice: try AncientsCSV.int(row["expectedFinalDice"] ?? "", field: "expectedFinalDice", rowID: id)
            )
        }
    }
}

enum AncientsCombatSampleLibrary {
    static let all: [AncientsCombatSample] = {
        do {
            return try AncientsCombatSampleCSVLoader.loadSamples()
        } catch {
            print("Failed to load AncientsCombatSamples.csv: \(error.localizedDescription)")
            return []
        }
    }()
}
