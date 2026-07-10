//
//  AncientsUnitData.swift
//  BattleCalc
//
//  Ancients-owned unit definitions. This is intentionally separate from
//  Napoleonics UnitDefinition because similar fields do not always mean the
//  same thing across games.
//

import Foundation

struct AncientsUnitDefinition: Codable, Hashable, Identifiable {
    let id: String
    let factionID: String
    let name: String
    let unitClass: String
    let symbolGroup: String
    let maxBlocks: Int
    let move: String
    let range: Int
    let holdFireDice: Int
    let moveFireDice: Int
    let rangedMaxMove: Int?
    let rangedRuleSource: String?
    let meleeDice: String
    let closeCombatMaxMove: Int?
    let battleBackDiceOverride: Int?
    let canEvade: Bool
    let retreatDistance: String
    let canMomentumAdvance: Bool
    let canBonusCloseCombat: Bool
    let swordsHit: Bool
    let canBattleAfterEnteringForest: Bool
    // Direction-specific post-roll reminders keep the combat worksheet concise:
    // show the attack-facing reminder only for the attacker and the defend-facing
    // reminder only for the defender.
    let postRollNoteWhenAttacking: String?
    let postRollNoteWhenDefending: String?
    let closeCombatRuleSource: String?
    let special: String?

}

enum AncientsUnitCSVLoader {
    private static let resourceName = "AncientsUnits"

    private static let requiredHeaders = [
        "id", "factionID", "name", "unitClass", "symbolGroup", "maxBlocks",
        "move", "range", "holdFireDice", "moveFireDice", "rangedMaxMove", "rangedRuleSource", "meleeDice",
        "closeCombatMaxMove", "battleBackDiceOverride",
        "canEvade", "retreatDistance", "canMomentumAdvance",
        "canBonusCloseCombat", "swordsHit", "canBattleAfterEnteringForest",
        "postRollNoteWhenAttacking", "postRollNoteWhenDefending",
        "closeCombatRuleSource", "special"
    ]

    static func loadUnitDefinitions() throws -> [AncientsUnitDefinition] {
        try AncientsCSV.loadRows(resourceName: resourceName, requiredHeaders: requiredHeaders).map { row in
            let id = row["id"] ?? ""
            return AncientsUnitDefinition(
                id: id,
                factionID: row["factionID"] ?? "",
                name: row["name"] ?? "",
                unitClass: row["unitClass"] ?? "",
                symbolGroup: row["symbolGroup"] ?? "",
                maxBlocks: try AncientsCSV.int(row["maxBlocks"] ?? "", field: "maxBlocks", rowID: id),
                move: row["move"] ?? "",
                range: try AncientsCSV.int(row["range"] ?? "", field: "range", rowID: id),
                holdFireDice: try AncientsCSV.int(row["holdFireDice"] ?? "", field: "holdFireDice", rowID: id),
                moveFireDice: try AncientsCSV.int(row["moveFireDice"] ?? "", field: "moveFireDice", rowID: id),
                rangedMaxMove: AncientsCSV.optionalInt(row["rangedMaxMove"] ?? "", field: "rangedMaxMove", rowID: id),
                rangedRuleSource: (row["rangedRuleSource"] ?? "").isEmpty ? nil : row["rangedRuleSource"],
                meleeDice: row["meleeDice"] ?? "",
                closeCombatMaxMove: AncientsCSV.optionalInt(row["closeCombatMaxMove"] ?? "", field: "closeCombatMaxMove", rowID: id),
                battleBackDiceOverride: AncientsCSV.optionalInt(row["battleBackDiceOverride"] ?? "", field: "battleBackDiceOverride", rowID: id),
                canEvade: try AncientsCSV.bool(row["canEvade"] ?? "", field: "canEvade", rowID: id),
                retreatDistance: row["retreatDistance"] ?? "",
                canMomentumAdvance: try AncientsCSV.bool(row["canMomentumAdvance"] ?? "", field: "canMomentumAdvance", rowID: id),
                canBonusCloseCombat: try AncientsCSV.bool(row["canBonusCloseCombat"] ?? "", field: "canBonusCloseCombat", rowID: id),
                swordsHit: try AncientsCSV.bool(row["swordsHit"] ?? "", field: "swordsHit", rowID: id),
                canBattleAfterEnteringForest: try AncientsCSV.bool(row["canBattleAfterEnteringForest"] ?? "", field: "canBattleAfterEnteringForest", rowID: id),
                postRollNoteWhenAttacking: (row["postRollNoteWhenAttacking"] ?? "").isEmpty ? nil : row["postRollNoteWhenAttacking"],
                postRollNoteWhenDefending: (row["postRollNoteWhenDefending"] ?? "").isEmpty ? nil : row["postRollNoteWhenDefending"],
                closeCombatRuleSource: (row["closeCombatRuleSource"] ?? "").isEmpty ? nil : row["closeCombatRuleSource"],
                special: (row["special"] ?? "").isEmpty ? nil : row["special"]
            )
        }
    }
}

enum AncientsUnitLibrary {
    static let all: [AncientsUnitDefinition] = {
        do {
            return try AncientsUnitCSVLoader.loadUnitDefinitions()
        } catch {
            print("Failed to load AncientsUnits.csv: \(error.localizedDescription)")
            return []
        }
    }()

    static func unit(for id: String) -> AncientsUnitDefinition? {
        all.first { $0.id == id }
    }
}
