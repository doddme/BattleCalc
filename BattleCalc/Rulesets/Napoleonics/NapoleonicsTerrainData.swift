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

    let infantryIntoPenalty: Int
    let cavalryIntoPenalty: Int
    let artilleryIntoPenalty: Int

    let infantryOutPenalty: Int
    let cavalryOutPenalty: Int
    let artilleryOutPenalty: Int
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

            // We only care about the first 10 real columns.
            // Extra trailing empty CSV columns are ignored.
            guard columns.count >= 10 else {
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
                artilleryOutPenalty: columns[9]
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
            artilleryOutPenalty: try parsePenaltyAllowingNA(
                row.artilleryOutPenalty,
                field: "ArtilleryOutPenalty",
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

    /// For now, treat "NA" as 0 so the loader can succeed with the current CSV.
    /// If you later want "NA" to mean illegal or unsupported terrain interaction,
    /// this is the one place to change that behavior.
    private static func parsePenaltyAllowingNA(
        _ value: String,
        field: String,
        terrainID: String
    ) throws -> Int {
        if value.uppercased() == "NA" {
            return 0
        }

        return try parseInt(value, field: field, terrainID: terrainID)
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
