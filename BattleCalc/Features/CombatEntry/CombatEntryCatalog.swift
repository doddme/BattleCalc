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

    init(id: String, title: String, subtitle: String? = nil, imageName: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
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

    /// Unit types for a country + class, sorted by name.
    static func unitTypes(in countryID: String, classID: String) -> [CombatPickItem] {
        NapoleonicsUnitLibrary.all
            .filter { $0.countryID == countryID && $0.unitClass.rawValue == classID }
            .sorted { $0.name < $1.name }
            .map { unit in
                CombatPickItem(
                    id: unit.id,
                    title: unit.name,
                    subtitle: "Range \(unit.combatProfile.range) · max \(unit.maxBlocks) blocks"
                )
            }
    }

    /// All terrain definitions, sorted by name. Used for both attacker and
    /// defender terrain because the two are selected independently.
    static func terrains() -> [CombatPickItem] {
        NapoleonicsTerrainLibrary.all.map { terrain in
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
