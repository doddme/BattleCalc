//
//  NapoleonicsUnitData.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/13/26.
//


import Foundation

/// Raw CSV row model.
/// Keep this string-based so parsing and conversion stay separate.
private struct UnitCSVRow {
    let id: String
    let countryID: String
    let name: String
    let unitClass: String
    let maxBlocks: String
    let maxMovement: String
    let maxMovementToShoot: String
    let range: String
    let standingFireRule: String
    let movingFireRule: String
    let meleeRule: String
    let meleeBonusVsInfantry: String
    let canBattleAfterEnteringTerrainIDs: String
    let hasSaber: String
}

enum UnitLoadError: Error, LocalizedError {
    case fileNotFound(String)
    case unreadableFile(String)
    case invalidRow(String)
    case invalidValue(field: String, value: String, unitID: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "Could not find \(fileName) in the app bundle."

        case .unreadableFile(let fileName):
            return "Could not read \(fileName) from the app bundle."

        case .invalidRow(let row):
            return "Invalid unit CSV row: \(row)"

        case .invalidValue(let field, let value, let unitID):
            return "Invalid value '\(value)' for field '\(field)' in unit '\(unitID)'."
        }
    }
}

/// Loads Napoleonics unit definitions from Units.csv in the app bundle.
enum NapoleonicsUnitCSVLoader {

    static func loadUnitDefinitions() throws -> [UnitDefinition] {
        let fileName = "Units"
        let fileExtension = "csv"

        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            throw UnitLoadError.fileNotFound("\(fileName).\(fileExtension)")
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw UnitLoadError.unreadableFile("\(fileName).\(fileExtension)")
        }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            return []
        }

        let dataLines = lines.dropFirst()
        var units: [UnitDefinition] = []

        for line in dataLines {
            let columns = line
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            // We only care about the first 14 real columns.
            // Extra trailing empty CSV columns are ignored.
            guard columns.count >= 14 else {
                throw UnitLoadError.invalidRow(line)
            }

            let row = UnitCSVRow(
                id: columns[0],
                countryID: columns[1],
                name: columns[2],
                unitClass: columns[3],
                maxBlocks: columns[4],
                maxMovement: columns[5],
                maxMovementToShoot: columns[6],
                range: columns[7],
                standingFireRule: columns[8],
                movingFireRule: columns[9],
                meleeRule: columns[10],
                meleeBonusVsInfantry: columns[11],
                canBattleAfterEnteringTerrainIDs: columns[12],
                hasSaber: columns[13]
            )

            let unit = try makeUnitDefinition(from: row)
            units.append(unit)
        }

        return units
    }

    private static func makeUnitDefinition(from row: UnitCSVRow) throws -> UnitDefinition {
        UnitDefinition(
            id: row.id,
            countryID: row.countryID,
            name: row.name,
            unitClass: try parseUnitClass(row.unitClass, unitID: row.id),
            maxBlocks: try parseInt(row.maxBlocks, field: "maxBlocks", unitID: row.id),
            hasSaber: try parseBool(row.hasSaber, field: "hasSaber", unitID: row.id),
            combatProfile: UnitCombatProfile(
                maxMovement: try parseInt(row.maxMovement, field: "maxMovement", unitID: row.id),
                maxMovementToShoot: try parseInt(row.maxMovementToShoot, field: "maxMovementToShoot", unitID: row.id),
                range: try parseInt(row.range, field: "range", unitID: row.id),
                standingFireRule: try parseStandingFireRule(row.standingFireRule, unitID: row.id),
                movingFireRule: try parseMovingFireRule(row.movingFireRule, unitID: row.id),
                meleeRule: try parseMeleeRule(row.meleeRule, unitID: row.id),
                bonuses: UnitCombatBonuses(
                    meleeBonusVsInfantry: try parseBool(
                        row.meleeBonusVsInfantry,
                        field: "meleeBonusVsInfantry",
                        unitID: row.id
                    )
                ),
                canBattleAfterEnteringTerrainIDs: parseTerrainIDs(row.canBattleAfterEnteringTerrainIDs)
            )
        )
    }

    private static func parseUnitClass(_ value: String, unitID: String) throws -> UnitClass {
        guard let unitClass = UnitClass(rawValue: value) else {
            throw UnitLoadError.invalidValue(field: "unitClass", value: value, unitID: unitID)
        }
        return unitClass
    }

    private static func parseStandingFireRule(_ value: String, unitID: String) throws -> StandingFireRule {
        guard let rule = StandingFireRule(rawValue: value) else {
            throw UnitLoadError.invalidValue(field: "standingFireRule", value: value, unitID: unitID)
        }
        return rule
    }

    private static func parseMovingFireRule(_ value: String, unitID: String) throws -> MovingFireRule {
        guard let rule = MovingFireRule(rawValue: value) else {
            throw UnitLoadError.invalidValue(field: "movingFireRule", value: value, unitID: unitID)
        }
        return rule
    }

    private static func parseMeleeRule(_ value: String, unitID: String) throws -> MeleeRule {
        guard let rule = MeleeRule(rawValue: value) else {
            throw UnitLoadError.invalidValue(field: "meleeRule", value: value, unitID: unitID)
        }
        return rule
    }

    private static func parseBool(_ value: String, field: String, unitID: String) throws -> Bool {
        switch value.uppercased() {
        case "TRUE":
            return true
        case "FALSE":
            return false
        default:
            throw UnitLoadError.invalidValue(field: field, value: value, unitID: unitID)
        }
    }

    private static func parseInt(_ value: String, field: String, unitID: String) throws -> Int {
        guard let intValue = Int(value) else {
            throw UnitLoadError.invalidValue(field: field, value: value, unitID: unitID)
        }
        return intValue
    }

    private static func parseTerrainIDs(_ value: String) -> [String] {
        value
            .split(separator: "|", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

/// Runtime unit lookup used by the combat evaluator.
enum NapoleonicsUnitLibrary {

    private static let unitsByID: [String: UnitDefinition] = {
        do {
            let units = try NapoleonicsUnitCSVLoader.loadUnitDefinitions()
            return Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })
        } catch {
            print("Failed to load Units.csv: \(error.localizedDescription)")
            return [:]
        }
    }()

    static func unit(for id: String?) -> UnitDefinition? {
        guard let id else { return nil }
        return unitsByID[id]
    }

    static var all: [UnitDefinition] {
        unitsByID.values.sorted { $0.name < $1.name }
    }
}
