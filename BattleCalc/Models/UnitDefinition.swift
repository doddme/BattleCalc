//
//  UnitDefinition.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

// Broad unit category used for rules that apply to infantry, cavalry, or artillery as a class.
enum UnitClass: String, Codable, CaseIterable, Hashable {
    case infantry
    case cavalry
    case artillery
}

// Flags that describe what a unit is allowed to do.
// These are capability-style properties, not the full combat math.
// The goal is to capture important yes/no behavior cleanly.
struct UnitCapabilities: Codable, Hashable {
    // Whether the unit can make melee attacks.
    let canMelee: Bool

    // Whether the unit can make ranged attacks at all.
    let canFire: Bool

    // Whether the unit can still fire after moving this turn.
    let canFireAfterMoving: Bool

    // Whether the unit is allowed to enter woods and still fire.
    // Most units will probably be false, but a few exceptions may exist.
    let canEnterWoodsAndFire: Bool
}

// Reference data for one unit type.
// This model identifies what the unit is, which country it belongs to,
// and the main capabilities needed for setup and later combat resolution.
struct UnitDefinition: Codable, Identifiable, Hashable {
    // Stable internal identifier used by battle setup and combat logic.
    // Example: "france_line_infantry", "british_rifles", "old_guard".
    let id: String

    // Country this unit belongs to.
    // This should match a CountryDefinition id.
    let countryID: String

    // User-facing unit name shown in pickers and summaries.
    let name: String

    // Broad classification used by many combat and terrain rules.
    let unitClass: UnitClass

    // Maximum number of blocks the unit can have at full strength.
    let maxBlocks: Int

    // Basic behavioral flags that help determine legal actions.
    let capabilities: UnitCapabilities

    // Maximum normal attack range for the unit.
    // We will refine range behavior later, especially for artillery.
    let maxRange: Int

    // Optional notes for special handling, reminders, or exceptions.
    let notes: [String]
}
