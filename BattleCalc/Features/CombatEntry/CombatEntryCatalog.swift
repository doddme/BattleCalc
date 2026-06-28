//
//  CombatEntryCatalog.swift
//  BattleCalc
//
//  Read-only lookup layer for the combat-entry screen.
//  It derives the selectable hierarchy (country -> unit class -> unit type)
//  straight from the already-loaded NapoleonicsUnitLibrary so the picker can
//  never offer a unit that the combat evaluator cannot resolve, and terrain
//  straight from NapoleonicsTerrainLibrary. Pure presentation glue: no rules.
//

import Foundation

/// One selectable row. `imageName` is intentionally optional and unused for
/// now so terrain/unit art can be added later without touching the views.
struct CombatPickItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let imageName: String?
    let colorKey: String?

    init(id: String, title: String, subtitle: String? = nil, imageName: String? = nil, colorKey: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.colorKey = colorKey
    }
}

/// Cascading catalog backed by the real Napoleonics data libraries.
enum CombatEntryCatalog {

    /// Countries that actually have at least one unit, sorted by display name.
    static func countries() -> [CombatPickItem] {
        let byCountry = Dictionary(grouping: NapoleonicsUnitLibrary.all, by: { $0.countryID })
        return byCountry.keys
            .map { id in
                CombatPickItem(id: id, title: displayName(forCountry: id))
            }
            .sorted { $0.title < $1.title }
    }

    /// Unit classes present for the given country, in canonical order.
    static func classes(in countryID: String) -> [CombatPickItem] {
        let classes = Set(
            NapoleonicsUnitLibrary.all
                .filter { $0.countryID == countryID }
                .map { $0.unitClass }
        )
        return UnitClass.allCases
            .filter { classes.contains($0) }
            .map { CombatPickItem(id: $0.rawValue, title: $0.rawValue.capitalized) }
    }

    /// Unit types for a country + class. Infantry uses a play-test-friendly rank
    /// order (line, light, grenadier, guard, other, militia last); every other
    /// class keeps the existing name sort. IDs/selections are unchanged.
    static func unitTypes(in countryID: String, classID: String) -> [CombatPickItem] {
        let units = NapoleonicsUnitLibrary.all
            .filter { $0.countryID == countryID && $0.unitClass.rawValue == classID }

        let ordered: [UnitDefinition]
        if classID == UnitClass.infantry.rawValue {
            // Stable secondary sort by name, then a stable primary sort by rank
            // bucket, so units within the same bucket stay alphabetical.
            ordered = units
                .sorted { $0.name < $1.name }
                .sorted { infantryRank($0) < infantryRank($1) }
        } else {
            ordered = units.sorted { $0.name < $1.name }
        }

        return ordered.map { unit in
            CombatPickItem(
                id: unit.id,
                title: unit.name,
                subtitle: unitPickerSubtitle(for: unit)
            )
        }
    }

    /// Short Napoleonics unit reminder shown in the unit picker.
    /// For artillery, show the standing multi-block table when available because
    /// that is the clearest default summary before the player has entered blocks
    /// and movement on the worksheet.
    private static func unitPickerSubtitle(for unit: UnitDefinition) -> String? {
        var parts: [String] = []

        if unit.combatProfile.isMeleeOnly || unit.unitClass == .cavalry {
            parts.append("Close Combat only")
        } else if unit.unitClass == .artillery {
            if let artillerySummary = artilleryPickerSubtitle(for: unit) {
                parts.append(artillerySummary) // Show useful artillery dice-by-range instead of only a max range.
            } else {
                parts.append("Range \(unit.combatProfile.range) or Melée") // Safe fallback if artillery table data is missing.
            }
        } else if unit.combatProfile.range > 1 {
            parts.append("Range \(unit.combatProfile.range) or Melée") // Prevent "Range 2" from sounding like the unit cannot also fight in close combat.
        }

        if unit.combatProfile.canBattleAfterEnteringTerrainIDs.contains("forest") {
            parts.append("May battle after entering forest") // Use the correct Napoleonics terrain name and ID.
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    /// Default artillery picker summary. Before the player chooses movement and
    /// current blocks, use the clearest baseline table: standing multi-block.
    private static func artilleryPickerSubtitle(for unit: UnitDefinition) -> String? {
        guard unit.unitClass == .artillery,
              let band = unit.combatProfile.artilleryFireTables?.standingMultiBlock else {
            return nil
        }

        let derivedRange = artilleryDerivedRange(band)
        guard derivedRange > 0 else { return nil }

        let diceByDistance = band.prefix(derivedRange).map { slot in
            if let slot { return String(slot) }
            return "-"
        }.joined(separator: "|")

        return "Range \(derivedRange) • \(diceByDistance)"
    }

    /// Highest usable artillery distance in a picker-summary band.
    private static func artilleryDerivedRange(_ band: ArtilleryFireBand) -> Int {
        var range = 0
        for (i, slot) in band.enumerated() where slot != nil {
            range = i + 1
        }
        return range
    }



    /// Rank bucket for infantry display order: line(0), light(1), grenadier(2),
    /// guard(3), other(4), militia(5, last). Matches on id/name keywords so it
    /// works regardless of country prefix (e.g. "french-line-infantry").
    private static func infantryRank(_ unit: UnitDefinition) -> Int {
        let key = (unit.id + " " + unit.name).lowercased()
        // Militia is checked first so it always sorts last even if another
        // keyword somehow also appears.
        if key.contains("militia")   { return 5 }
        // Guard is checked before line/light/grenadier so every guard variant
        // ("Young Guard", "Old Guard", "Guard Light", "Guard Grenadier") clusters
        // in the guard bucket instead of splitting across the earlier buckets.
        if key.contains("guard")     { return 3 }
        if key.contains("line")      { return 0 }
        if key.contains("light")     { return 1 }
        if key.contains("grenadier") { return 2 }
        return 4
    }

    /// Preferred terrain order for the picker: the common play-test terrains
    /// first, then everything else in the library's existing (name-sorted)
    /// order. IDs/selections are unchanged — this only reorders display rows.
    /// Applied identically to attacker and defender terrain.
    private static let preferredTerrainOrder = ["clear", "hill", "forest", "town", "walled-garden"]

    /// All terrain definitions, ordered with `preferredTerrainOrder` first and
    /// the remaining terrains after in their existing order. Used for both
    /// attacker and defender terrain because the two are selected independently.
    static func terrains() -> [CombatPickItem] {
        let all = NapoleonicsTerrainLibrary.all
        let priority = preferredTerrainOrder
            .compactMap { id in all.first { $0.id == id } }
        let priorityIDs = Set(priority.map(\.id))
        let rest = all.filter { !priorityIDs.contains($0.id) }
        return (priority + rest).map { terrain in
            CombatPickItem(id: terrain.id, title: terrain.name)
        }
    }

    /// Max blocks for a unit, used to bound the blocks stepper. Falls back to a
    /// sane default when the unit cannot be resolved.
    static func maxBlocks(forUnit unitID: String) -> Int {
        NapoleonicsUnitLibrary.unit(for: unitID)?.maxBlocks ?? 8
    }

    /// Human-readable country name. Mirrors the ids used across the rules data.
    private static func displayName(forCountry id: String) -> String {
        switch id {
        case "france":   return "France"
        case "britain":  return "Britain"
        case "portugal": return "Portugal"
        case "spain":    return "Spain"
        case "prussia":  return "Prussia"
        case "austria":  return "Austria"
        case "russia":   return "Russia"
        default:         return id.capitalized
        }
    }
}
