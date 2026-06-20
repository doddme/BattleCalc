//
//  NapoleonicsUnitData.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/13/26.
//


import Foundation

/// Raw CSV row model.
/// Keep this string-based so parsing and conversion stay separate.
/// Fields are populated by *header name* (see `UnitCSVColumn`), not position,
/// so reordering or inserting columns in Numbers/CSV no longer breaks loading.
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

    // New optional cavalry/artillery support fields. Absent column or blank
    // value is allowed; defaults preserve current infantry behavior.
    let isMeleeOnly: String
    let artilleryStandingMultiBlock: String
    let artilleryStandingSingleBlock: String
    let artilleryMovingMultiBlock: String
    let artilleryMovingSingleBlock: String
}

/// Canonical CSV column names. These are the exact header strings the loader
/// expects in `Units.csv`. Required columns must be present (loader fails
/// loudly via `.missingHeader` if not); optional columns may be omitted and
/// default safely, so older CSVs without the new columns still load.
private enum UnitCSVColumn {
    // Required (must match a header in Units.csv).
    static let required: [String] = [
        "id", "countryID", "name", "unitClass", "maxBlocks",
        "maxMovement", "maxMovementToShoot", "range",
        "standingFireRule", "movingFireRule", "meleeDiceRule",
        "meleeBonusVsInfantry", "canBattleAfterEnteringTerrainIDs", "hasSaber"
    ]

    // Optional new fields — safe to omit; blank/absent => default.
    static let isMeleeOnly = "isMeleeOnly"
    static let artilleryStandingMultiBlock = "artilleryStandingMultiBlock"
    static let artilleryStandingSingleBlock = "artilleryStandingSingleBlock"
    static let artilleryMovingMultiBlock = "artilleryMovingMultiBlock"
    static let artilleryMovingSingleBlock = "artilleryMovingSingleBlock"
}

enum UnitLoadError: Error, LocalizedError {
    case fileNotFound(String)
    case unreadableFile(String)
    case invalidRow(String)
    case invalidValue(field: String, value: String, unitID: String)
    case missingHeader(String)

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

        case .missingHeader(let header):
            return "Units.csv is missing required column header '\(header)'."
        }
    }
}

/// Loads Napoleonics unit definitions from Units.csv in the app bundle.
enum NapoleonicsUnitCSVLoader {

    static func loadUnitDefinitions() throws -> [UnitDefinition] {
        let fileName = "NapoleonicsUnits"
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

        // Build a header-name -> column-index map from the first line. Parsing
        // is now by name, not position, so columns can be reordered or new ones
        // inserted in Numbers/CSV without breaking the loader.
        let headerCells = splitCSV(lines[0])
        var headerIndex: [String: Int] = [:]
        for (index, rawName) in headerCells.enumerated() {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            // First occurrence wins; trailing empty header cells are skipped.
            if headerIndex[name] == nil { headerIndex[name] = index }
        }

        // Required columns must exist by name, else fail loudly.
        for required in UnitCSVColumn.required {
            guard headerIndex[required] != nil else {
                throw UnitLoadError.missingHeader(required)
            }
        }

        let dataLines = lines.dropFirst()
        var units: [UnitDefinition] = []

        for line in dataLines {
            let columns = splitCSV(line)

            // Reads a column by header name. Required headers are guaranteed to
            // exist (checked above); optional columns missing or out of range
            // return "" so new fields default safely.
            func value(_ header: String) -> String {
                guard let idx = headerIndex[header], idx < columns.count else { return "" }
                return columns[idx]
            }

            let row = UnitCSVRow(
                id: value("id"),
                countryID: value("countryID"),
                name: value("name"),
                unitClass: value("unitClass"),
                maxBlocks: value("maxBlocks"),
                maxMovement: value("maxMovement"),
                maxMovementToShoot: value("maxMovementToShoot"),
                range: value("range"),
                standingFireRule: value("standingFireRule"),
                movingFireRule: value("movingFireRule"),
                meleeRule: value("meleeDiceRule"),
                meleeBonusVsInfantry: value("meleeBonusVsInfantry"),
                canBattleAfterEnteringTerrainIDs: value("canBattleAfterEnteringTerrainIDs"),
                hasSaber: value("hasSaber"),
                isMeleeOnly: value(UnitCSVColumn.isMeleeOnly),
                artilleryStandingMultiBlock: value(UnitCSVColumn.artilleryStandingMultiBlock),
                artilleryStandingSingleBlock: value(UnitCSVColumn.artilleryStandingSingleBlock),
                artilleryMovingMultiBlock: value(UnitCSVColumn.artilleryMovingMultiBlock),
                artilleryMovingSingleBlock: value(UnitCSVColumn.artilleryMovingSingleBlock)
            )

            // Skip fully blank lines (e.g. an id-less trailing row).
            guard !row.id.isEmpty else { continue }

            let unit = try makeUnitDefinition(from: row)
            units.append(unit)
        }

        return units
    }

    /// Splits one CSV line into trimmed cells, preserving empty cells so that
    /// header/column alignment by index is correct.
    private static func splitCSV(_ line: String) -> [String] {
        line
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
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
                standingFireRule: try parseStandingFireRule(
                    row.standingFireRule, unitID: row.id, default: .currentBlocks),
                movingFireRule: try parseMovingFireRule(
                    row.movingFireRule, unitID: row.id, default: .none),
                meleeRule: try parseMeleeRule(
                    row.meleeRule, unitID: row.id, default: .currentBlocks),
                isMeleeOnly: try parseOptionalBool(
                    row.isMeleeOnly,
                    field: "isMeleeOnly",
                    unitID: row.id,
                    default: false
                ),
                artilleryFireTables: try parseArtilleryFireTables(from: row),
                bonuses: UnitCombatBonuses(
                    meleeBonusVsInfantry: try parseOptionalBool(
                        row.meleeBonusVsInfantry,
                        field: "meleeBonusVsInfantry",
                        unitID: row.id,
                        default: false
                    )
                ),
                canBattleAfterEnteringTerrainIDs: parseTerrainIDs(row.canBattleAfterEnteringTerrainIDs)
            )
        )
    }

    /// Assembles the optional artillery fire tables from the four pipe-delimited
    /// CSV columns. A blank column => that band is `nil` (= attack not allowed
    /// for that movement/block situation). Blank slots inside a non-blank column
    /// are preserved as `nil` (= out of range at that distance). If all four are
    /// blank the whole `ArtilleryFireTables` is `nil`, so non-artillery rows
    /// stay unaffected.
    private static func parseArtilleryFireTables(from row: UnitCSVRow) throws -> ArtilleryFireTables? {
        let tables = ArtilleryFireTables(
            standingMultiBlock: try parseArtilleryBand(
                row.artilleryStandingMultiBlock,
                field: UnitCSVColumn.artilleryStandingMultiBlock, unitID: row.id),
            standingSingleBlock: try parseArtilleryBand(
                row.artilleryStandingSingleBlock,
                field: UnitCSVColumn.artilleryStandingSingleBlock, unitID: row.id),
            movingMultiBlock: try parseArtilleryBand(
                row.artilleryMovingMultiBlock,
                field: UnitCSVColumn.artilleryMovingMultiBlock, unitID: row.id),
            movingSingleBlock: try parseArtilleryBand(
                row.artilleryMovingSingleBlock,
                field: UnitCSVColumn.artilleryMovingSingleBlock, unitID: row.id)
        )
        return tables.hasAnyTable ? tables : nil
    }

    private static func parseUnitClass(_ value: String, unitID: String) throws -> UnitClass {
        guard let unitClass = UnitClass(rawValue: value) else {
            throw UnitLoadError.invalidValue(field: "unitClass", value: value, unitID: unitID)
        }
        return unitClass
    }

    /// Blank value yields `defaultValue` (non-infantry rows — cavalry/artillery —
    /// legitimately leave fire rules blank); a non-blank but unknown value still
    /// fails loudly so infantry typos are caught.
    private static func parseStandingFireRule(
        _ value: String, unitID: String, default defaultValue: StandingFireRule
    ) throws -> StandingFireRule {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultValue }
        guard let rule = StandingFireRule(rawValue: trimmed) else {
            throw UnitLoadError.invalidValue(field: "standingFireRule", value: trimmed, unitID: unitID)
        }
        return rule
    }

    private static func parseMovingFireRule(
        _ value: String, unitID: String, default defaultValue: MovingFireRule
    ) throws -> MovingFireRule {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultValue }
        guard let rule = MovingFireRule(rawValue: trimmed) else {
            throw UnitLoadError.invalidValue(field: "movingFireRule", value: trimmed, unitID: unitID)
        }
        return rule
    }

    private static func parseMeleeRule(
        _ value: String, unitID: String, default defaultValue: MeleeRule
    ) throws -> MeleeRule {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultValue }
        guard let rule = MeleeRule(rawValue: trimmed) else {
            throw UnitLoadError.invalidValue(field: "meleeRule", value: trimmed, unitID: unitID)
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

    /// Like `parseBool`, but a blank/absent value yields `defaultValue`. Used
    /// for new optional flags so existing rows (and CSVs without the column)
    /// keep their current behavior.
    private static func parseOptionalBool(
        _ value: String,
        field: String,
        unitID: String,
        default defaultValue: Bool
    ) throws -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultValue }
        return try parseBool(trimmed, field: field, unitID: unitID)
    }

    /// Parses one pipe-delimited artillery fire band into an `ArtilleryFireBand`
    /// (`[Int?]`), preserving blank slots so distance positions are not lost:
    ///
    /// - An entirely blank/whitespace field returns `nil` — the whole band is
    ///   "not allowed" for that movement/block situation.
    /// - Inside a non-blank field, every `|`-separated slot is kept: a numeric
    ///   slot becomes its `Int` dice value; a blank slot becomes `nil` (= out
    ///   of range at that distance). So `"3|2|1||"` => `[3, 2, 1, nil, nil]`
    ///   (count 5), `"3|2|1|1|"` => `[3, 2, 1, 1, nil]` (count 5), and
    ///   `"4|3|2|1|1"` => `[4, 3, 2, 1, 1]` (count 5).
    /// - A non-blank slot that is not an integer fails loudly via
    ///   `UnitLoadError.invalidValue` rather than being silently dropped.
    private static func parseArtilleryBand(
        _ value: String,
        field: String,
        unitID: String
    ) throws -> ArtilleryFireBand? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // `components(separatedBy:)` keeps interior AND trailing empty slots,
        // so trailing blanks (out-of-range distances) are preserved.
        var band: ArtilleryFireBand = []
        for rawSlot in trimmed.components(separatedBy: "|") {
            let slot = rawSlot.trimmingCharacters(in: .whitespacesAndNewlines)
            if slot.isEmpty {
                band.append(nil)
            } else if let dice = Int(slot) {
                band.append(dice)
            } else {
                throw UnitLoadError.invalidValue(field: field, value: slot, unitID: unitID)
            }
        }
        return band
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
            print("Failed to load NapoleonicsUnits.csv: \(error.localizedDescription)")
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
