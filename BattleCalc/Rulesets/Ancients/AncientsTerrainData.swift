//
//  AncientsTerrainData.swift
//  BattleCalc
//
//  Ancients-owned terrain definitions. Penalty and cap fields are kept as data
//  until an Ancients ruleset interprets them.
//

import Foundation

struct AncientsTerrainDefinition: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let blocksBattleOnEntry: Bool
    let blocksLineOfSight: Bool
    let infantryIntoPenalty: String
    let cavalryIntoPenalty: String
    let artilleryIntoPenalty: String
    let infantryOutPenalty: String
    let cavalryOutPenalty: String
    let artilleryOutPenalty: String
    let meleeMaxDice: String?
    let rangedMaxDice: String?
    let meleeINTOMaxDice: String?
    let meleeOutMaxDice: String?
    let rangedINTOMaxDice: String?
    let rangedOutMaxDice: String?
    let battleOnEntryRule: String?
    let terrainPostRollNote: String?
    let terrainRuleSource: String?
}

enum AncientsTerrainCSVLoader {
    private static let resourceName = "AncientsTerrain"

    private static let requiredHeaders = [
        "Id", "name", "blocksBattleonEntry", "blocksLineofSight",
        "InfantryINTOPenalty", "CavalryINTOPenalty", "ArtilleryINTOPenalty",
        "InfantryOutPenalty", "CavalryOutPenalty", "ArtilleryOutPenalty",
        "meleeMaxDice", "rangedMaxDice",
        "meleeINTOMaxDice", "meleeOutMaxDice", "rangedINTOMaxDice", "rangedOutMaxDice",
        "battleOnEntryRule", "terrainPostRollNote", "terrainRuleSource"
    ]

    static func loadTerrainDefinitions() throws -> [AncientsTerrainDefinition] {
        try AncientsCSV.loadRows(resourceName: resourceName, requiredHeaders: requiredHeaders).map { row in
            let id = row["Id"] ?? ""
            return AncientsTerrainDefinition(
                id: id,
                name: row["name"] ?? "",
                blocksBattleOnEntry: try AncientsCSV.bool(row["blocksBattleonEntry"] ?? "", field: "blocksBattleonEntry", rowID: id),
                blocksLineOfSight: try AncientsCSV.bool(row["blocksLineofSight"] ?? "", field: "blocksLineofSight", rowID: id),
                infantryIntoPenalty: row["InfantryINTOPenalty"] ?? "",
                cavalryIntoPenalty: row["CavalryINTOPenalty"] ?? "",
                artilleryIntoPenalty: row["ArtilleryINTOPenalty"] ?? "",
                infantryOutPenalty: row["InfantryOutPenalty"] ?? "",
                cavalryOutPenalty: row["CavalryOutPenalty"] ?? "",
                artilleryOutPenalty: row["ArtilleryOutPenalty"] ?? "",
                meleeMaxDice: (row["meleeMaxDice"] ?? "").isEmpty ? nil : row["meleeMaxDice"],
                rangedMaxDice: (row["rangedMaxDice"] ?? "").isEmpty ? nil : row["rangedMaxDice"],
                meleeINTOMaxDice: (row["meleeINTOMaxDice"] ?? "").isEmpty ? nil : row["meleeINTOMaxDice"],
                meleeOutMaxDice: (row["meleeOutMaxDice"] ?? "").isEmpty ? nil : row["meleeOutMaxDice"],
                rangedINTOMaxDice: (row["rangedINTOMaxDice"] ?? "").isEmpty ? nil : row["rangedINTOMaxDice"],
                rangedOutMaxDice: (row["rangedOutMaxDice"] ?? "").isEmpty ? nil : row["rangedOutMaxDice"],
                battleOnEntryRule: (row["battleOnEntryRule"] ?? "").isEmpty ? nil : row["battleOnEntryRule"],
                terrainPostRollNote: (row["terrainPostRollNote"] ?? "").isEmpty ? nil : row["terrainPostRollNote"],
                terrainRuleSource: (row["terrainRuleSource"] ?? "").isEmpty ? nil : row["terrainRuleSource"]
            )
        }
    }
}

enum AncientsTerrainLibrary {
    static let all: [AncientsTerrainDefinition] = {
        do {
            return try AncientsTerrainCSVLoader.loadTerrainDefinitions()
        } catch {
            print("Failed to load AncientsTerrain.csv: \(error.localizedDescription)")
            return []
        }
    }()

    static func terrain(for id: String?) -> AncientsTerrainDefinition? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}
