//
//  CombatContext.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

// High-level attack type for a combat query.
// We separate melee from ranged because the legal checks and dice rules
// are often different for the same unit.
enum CombatMode: String, Codable, CaseIterable, Hashable {
    case melee
    case ranged
}

// Relative attack direction used for terrain-dependent modifiers.
// We keep this simple for version 1, but it gives us a place to express
// cases like attacking uphill into a hill or firing into a town.
enum AttackDirection: String, Codable, CaseIterable, Hashable {
    case flat
    case uphill
    case downhill
}

// Full input state for one combat calculation request.
// This is the runtime object built from the user's choices on screen.
// Later, the rules engine will read this object and produce a CombatResult.
struct CombatContext: Codable, Hashable {
    // Whether this is a melee attack or a ranged attack.
    var combatMode: CombatMode

    // For ranged attacks, this records whether the attacker moved this turn.
    // It can be nil when the value is not relevant, such as in melee.
    var movedThisTurn: Bool?

    // Distance between attacker and defender in hexes.
    // This matters mainly for ranged attacks, but we keep it optional
    // so the same object can represent both melee and ranged contexts.
    var targetDistance: Int?

    // Attacker identity and state.
    var attackerCountryID: String
    var attackerUnitID: String
    var attackerBlocks: Int
    var attackerTerrainID: String?

    // Defender identity and state.
    var defenderCountryID: String
    var defenderUnitID: String
    var defenderBlocks: Int
    var defenderTerrainID: String?

    // Direction matters for certain terrain interactions,
    // such as attacks involving hills or other protected positions.
    var attackDirection: AttackDirection?
}
