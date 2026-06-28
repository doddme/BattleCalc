//
//  AncientsCombatEntryCatalog.swift
//  BattleCalc
//
//  Picker-friendly lookup layer for future Ancients combat entry screens.
//  This stays separate from CombatEntryCatalog because the current combat entry
//  flow is backed by Napoleonics data and rules.
//

import Foundation

enum AncientsCombatEntryCatalog {

    /// Unit classes present in the Ancients data. The current data is generic,
    /// so the UI starts here instead of asking for a faction first.
    static func classes() -> [CombatPickItem] {
        let classes = Set(AncientsUnitLibrary.all.filter { $0.unitClass != "leader" }.map { $0.unitClass })
        return preferredClassOrder
            .filter { classes.contains($0) }
            .map { CombatPickItem(id: $0, title: displayName(forUnitClass: $0)) }
    }

    /// Unit types for a class, sorted by banner color (green, blue, red), then name.
    static func unitTypes(in classID: String) -> [CombatPickItem] {
        AncientsUnitLibrary.all
            .filter { $0.unitClass == classID && $0.unitClass != "leader" }
            .sorted { lhs, rhs in
                let leftColor = symbolGroupRank(lhs.symbolGroup)
                let rightColor = symbolGroupRank(rhs.symbolGroup)
                if leftColor != rightColor { return leftColor < rightColor }
                return lhs.name < rhs.name
            }
            .map { unit in
                CombatPickItem(
                    id: unit.id,
                    title: unit.name,
                    subtitle: unitSubtitle(for: unit),
                    colorKey: unit.symbolGroup
                )
            }
    }

    /// All terrain definitions, with common terrain first and the rest by name.
    static func terrains() -> [CombatPickItem] {
        let all = AncientsTerrainLibrary.all.sorted { $0.name < $1.name }
        let priority = preferredTerrainOrder.compactMap { id in all.first { $0.id == id } }
        let priorityIDs = Set(priority.map(\.id))
        let rest = all.filter { !priorityIDs.contains($0.id) }

        return (priority + rest).map { terrain in
            CombatPickItem(id: terrain.id, title: terrain.name)
        }
    }

    /// Max blocks for a unit, used to bound future blocks controls.
    static func maxBlocks(forUnit unitID: String) -> Int {
        AncientsUnitLibrary.unit(for: unitID)?.maxBlocks ?? 4
    }

    private static let preferredClassOrder = ["infantry", "cavalry", "chariot", "elephant", "artillery"]
    private static let preferredTerrainOrder = ["clear", "hill", "forest", "river", "camp"]

    /// Builds the static colored-chip subtitle for Ancients unit choices.
    /// Keep this limited to always-true unit facts; matchup-specific reminders
    /// like evade belong in the larger gray summary area instead.
    /// Builds the static colored-chip subtitle for Ancients unit choices.
    /// Keep this limited to always-true unit facts the player may want to scan
    /// before choosing a unit. Matchup-specific reminders like evade belong in
    /// the larger gray summary area instead.
    private static func unitSubtitle(for unit: AncientsUnitDefinition) -> String {
        let parts = [
            displayName(forSymbolGroup: unit.symbolGroup),
            "Move: \(unit.move)",
            "Max Range: \(unit.range) Hexes",
            "Melee \(unit.meleeDice) Dice"
        ]

        // Do not show generic evade text here.
        // In Ancients, evade is only useful as a defender-only reminder against
        // the current attacker in melee, so it should live in the outer summary.
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }


    private static func symbolGroupRank(_ id: String) -> Int {
        switch id.lowercased() {
        case "green": return 0
        case "blue": return 1
        case "red": return 2
        default: return 3
        }
    }

    private static func displayName(forUnitClass id: String) -> String {
        switch id {
        case "infantry": return "Infantry"
        case "cavalry": return "Cavalry"
        case "chariot": return "Chariots"
        case "elephant": return "Elephants"
        case "artillery": return "War Machines"
        case "leader": return "Leaders"
        default: return titleCase(id)
        }
    }

    private static func displayName(forSymbolGroup id: String) -> String {
        switch id.lowercased() {
        case "green": return "Green"
        case "blue": return "Blue"
        case "red": return "Red"
        default: return ""
        }
    }

    private static func titleCase(_ id: String) -> String {
        id
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
