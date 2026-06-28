//
//  NapoleonicsTerrainData.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/13/26.
//

import Foundation

/// Full terrain definition used by the Napoleonics combat evaluator.
/// This is more detailed than the older MapTerrainType model because
/// combat needs entry restrictions, line-of-sight blocking, and class-based
/// attack penalties.
struct TerrainDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String

    let blocksBattleOnEntry: Bool
    let blocksLineOfSight: Bool

    // Base "attacking into this terrain" penalties. These apply to normal
    // into-terrain handling for both ranged and melee unless a melee-only
    // extra penalty is also present.
    let infantryIntoPenalty: Int
    let cavalryIntoPenalty: Int
    let artilleryIntoPenalty: Int

    let infantryOutPenalty: Int
    let cavalryOutPenalty: Int

    // Optional because some terrain/unit combinations are not just "0 dice" or
    // "a penalty" — they are not allowed at all. Example: artillery attacking
    // out of Sand Quarry.
    let artilleryOutPenalty: Int?


    // Extra melee-only "into terrain" penalties. These are added on top of the
    // normal INTO penalty only when the attack is close combat (distance 1).
    // Example: Marsh can be 0 for normal INTO, but -1 here for melee INTO.
    let infantryMeleeIntoPenalty: Int
    let cavalryMeleeIntoPenalty: Int
    let artilleryMeleeIntoPenalty: Int

    // Whether an infantry defender on this terrain may form square when charged
    // by cavalry. FALSE means we should surface "MAY NOT FORM SQUARE".
    let mayFormSquare: Bool
}

/// Raw CSV row model.
/// Keep this string-based so parsing and conversion stay separate.
private struct TerrainCSVRow {
    let id: String
    let name: String
    let blocksBattleOnEntry: String
    let blocksLineOfSight: String
    let infantryIntoPenalty: String
    let cavalryIntoPenalty: String
    let artilleryIntoPenalty: String
    let infantryOutPenalty: String
    let cavalryOutPenalty: String
    let artilleryOutPenalty: String
    let infantryMeleeIntoPenalty: String
    let cavalryMeleeIntoPenalty: String
    let artilleryMeleeIntoPenalty: String
    let mayFormSquare: String
}


enum TerrainLoadError: Error, LocalizedError {
    case fileNotFound(String)
    case unreadableFile(String)
    case invalidRow(String)
    case invalidValue(field: String, value: String, terrainID: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Could not find \(fileName) in the app bundle."

        case .unreadableFile(let fileName):
            return "Could not read \(fileName) from the app bundle."

        case .invalidRow(let row):
            return "Invalid terrain CSV row: \(row)"

        case .invalidValue(let field, let value, let terrainID):
            return "Invalid value '\(value)' for field '\(field)' in terrain '\(terrainID)'."
        }
    }
}

/// Loads Napoleonics terrain definitions from Terrain.csv in the app bundle.
enum NapoleonicsTerrainCSVLoader {

    static func loadTerrainDefinitions() throws -> [TerrainDefinition] {
        let fileName = "NapoleonicsTerrain"
        let fileExtension = "csv"

        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            throw TerrainLoadError.fileNotFound("\(fileName).\(fileExtension)")
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw TerrainLoadError.unreadableFile("\(fileName).\(fileExtension)")
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            return []
        }

        let dataLines = lines.dropFirst()
        var terrains: [TerrainDefinition] = []

        for line in dataLines {
            let columns = line
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            // Napoleonics terrain now includes 14 meaningful columns:
            // the original INTO/OUT values, three melee-only INTO values,
            // and the MayFormSquare flag.
            guard columns.count >= 14 else {
                throw TerrainLoadError.invalidRow(line)
            }

            let row = TerrainCSVRow(
                id: columns[0],
                name: columns[1],
                blocksBattleOnEntry: columns[2],
                blocksLineOfSight: columns[3],
                infantryIntoPenalty: columns[4],
                cavalryIntoPenalty: columns[5],
                artilleryIntoPenalty: columns[6],
                infantryOutPenalty: columns[7],
                cavalryOutPenalty: columns[8],
                artilleryOutPenalty: columns[9],
                infantryMeleeIntoPenalty: columns[10],
                cavalryMeleeIntoPenalty: columns[11],
                artilleryMeleeIntoPenalty: columns[12],
                mayFormSquare: columns[13]
            )


            let terrain = try makeTerrainDefinition(from: row)
            terrains.append(terrain)
        }

        return terrains
    }

    private static func makeTerrainDefinition(from row: TerrainCSVRow) throws -> TerrainDefinition {
        TerrainDefinition(
            id: row.id,
            name: row.name,
            blocksBattleOnEntry: try parseBool(
                row.blocksBattleOnEntry,
                field: "blocksBattleOnEntry",
                terrainID: row.id
            ),
            blocksLineOfSight: try parseBool(
                row.blocksLineOfSight,
                field: "blocksLineOfSight",
                terrainID: row.id
            ),

            // Base INTO penalties used in all attack modes.
            infantryIntoPenalty: try parseInt(
                row.infantryIntoPenalty,
                field: "InfantryINTOPenalty",
                terrainID: row.id
            ),
            cavalryIntoPenalty: try parseInt(
                row.cavalryIntoPenalty,
                field: "CavalryINTOPenalty",
                terrainID: row.id
            ),
            artilleryIntoPenalty: try parseInt(
                row.artilleryIntoPenalty,
                field: "ArtilleryINTOPenalty",
                terrainID: row.id
            ),

            infantryOutPenalty: try parseInt(
                row.infantryOutPenalty,
                field: "InfantryOutPenalty",
                terrainID: row.id
            ),
            cavalryOutPenalty: try parseInt(
                row.cavalryOutPenalty,
                field: "CavalryOutPenalty",
                terrainID: row.id
            ),
            // "NA" means this unit/terrain interaction is not allowed at all,
            // not a numeric penalty. Keep that distinction in the model so the
            // evaluator can block the attack and tell the user why.
            artilleryOutPenalty: try parseOptionalPenaltyAllowingNA(
                row.artilleryOutPenalty,
                field: "ArtilleryOutPenalty",
                terrainID: row.id
            ),


            // Extra melee-only INTO penalties. Keep these data-driven so special
            // terrain like Marsh / Sand Quarry / Fordable River needs no
            // hardcoded terrain-name logic in the evaluator.
            infantryMeleeIntoPenalty: try parseInt(
                row.infantryMeleeIntoPenalty,
                field: "InfantryMeleeINTO",
                terrainID: row.id
            ),
            cavalryMeleeIntoPenalty: try parseInt(
                row.cavalryMeleeIntoPenalty,
                field: "CavalryMeleeINTO",
                terrainID: row.id
            ),
            artilleryMeleeIntoPenalty: try parseInt(
                row.artilleryMeleeIntoPenalty,
                field: "ArtilleryMeleeINTO",
                terrainID: row.id
            ),

            // Square eligibility is terrain-owned data.
            mayFormSquare: try parseBool(
                row.mayFormSquare,
                field: "MayFormSquare",
                terrainID: row.id
            )
        )
    }


    private static func parseBool(
        _ value: String,
        field: String,
        terrainID: String
    ) throws -> Bool {
        switch value.uppercased() {
        case "TRUE":
            return true
        case "FALSE":
            return false
        default:
            throw TerrainLoadError.invalidValue(field: field, value: value, terrainID: terrainID)
        }
    }

    private static func parseInt(
        _ value: String,
        field: String,
        terrainID: String
    ) throws -> Int {
        guard let intValue = Int(value) else {
            throw TerrainLoadError.invalidValue(field: field, value: value, terrainID: terrainID)
        }
        return intValue
    }

    /// Parses a terrain penalty field that may use "NA" to mean "this terrain /
    /// unit interaction is not allowed at all" rather than a numeric modifier.
    ///
    /// Returns:
    /// - Int value for normal numeric penalties
    /// - nil for "NA" (illegal / not allowed)
    private static func parseOptionalPenaltyAllowingNA(
        _ value: String,
        field: String,
        terrainID: String
    ) throws -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.uppercased() == "NA" {
            return nil
        }

        return try parseInt(trimmed, field: field, terrainID: terrainID)
    }

}

/// Runtime terrain lookup used by the combat evaluator.
enum NapoleonicsTerrainLibrary {

    private static let terrainsByID: [String: TerrainDefinition] = {
        do {
            let terrains = try NapoleonicsTerrainCSVLoader.loadTerrainDefinitions()
            return Dictionary(uniqueKeysWithValues: terrains.map { ($0.id, $0) })
        } catch {
            print("Failed to load NapoleonicsTerrain.csv: \(error.localizedDescription)")
            return [:]
        }
    }()

    static func terrain(for id: String?) -> TerrainDefinition? {
        guard let id else { return nil }
        return terrainsByID[id]
    }

    static var all: [TerrainDefinition] {
        terrainsByID.values.sorted { $0.name < $1.name }
    }
}
