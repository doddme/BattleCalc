//
//  CombatContext.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

/// High-level attack type for a combat query.
/// We separate melee from ranged because the legal checks and dice rules
/// are often different for the same unit.
enum CombatMode: String, Codable, CaseIterable, Hashable {
    case melee
    case ranged
}

/// Relative attack direction used for terrain-dependent modifiers.
/// We keep this simple for version 1, but it gives us a place to express
/// cases like attacking uphill into a hill or firing into a town.
enum AttackDirection: String, Codable, CaseIterable, Hashable {
    case flat
    case uphill
    case downhill
}

/// Leader support available to a unit for the current combat.
/// Adjacent leaders can affect Close Combat hit symbols, while attached leaders
/// can also affect morale and some follow-up combat reminders.
enum CombatLeaderSupport: String, Codable, CaseIterable, Hashable {
    case none
    case adjacent
    case attached

    var title: String {
        switch self {
        case .none: return "No leader"
        case .adjacent: return "Adjacent leader"
        case .attached: return "Attached leader"
        }
    }

    var summary: String? {
        switch self {
        case .none: return nil
        case .adjacent: return "Leader adjacent"
        case .attached: return "Leader attached"
        }
    }
}

/// Full input state for one combat calculation request.
/// This is the runtime object built from the user's choices on screen.
/// Later, the rules engine will read this object and produce a CombatResult.
struct CombatContext: Codable, Hashable {
    /// Whether this is a melee attack or a ranged attack.
    var combatMode: CombatMode

    /// Number of hexes the attacker moved this turn.
    /// This is more precise than a yes/no flag and maps better to unit rules.
    /// It can be nil when movement is not relevant, such as in melee.
    var movedHexes: Int?

    /// Distance between attacker and defender in hexes.
    /// This matters mainly for ranged attacks, but we keep it optional
    /// so the same object can represent both melee and ranged contexts.
    var targetDistance: Int?

    /// Attacker identity and state.
    var attackerCountryID: String
    var attackerUnitID: String
    var attackerBlocks: Int
    var attackerTerrainID: String?

    /// Defender identity and state.
    var defenderCountryID: String
    var defenderUnitID: String
    var defenderBlocks: Int
    var defenderTerrainID: String?

    /////////////////////////////////////////
    /// Combined attack support for Napoleonics artillery.
    /// When true, the artillery attack may add melee dice from one supporting
    /// adjacent ordered unit.
    var isCombinedAttack: Bool = false

    /// Optional supporting unit identity for a combined artillery attack.
    var supportingUnitID: String? = nil

    /// Current block count of the supporting unit, if one is selected.
    var supportingUnitBlocks: Int? = nil
    
    /// Terrain occupied by the supporting unit during a combined artillery attack.
    /// This matters because the supporting unit's melee dice may be modified by terrain.
    var supportingUnitTerrainID: String? = nil

    /// True when the supporting infantry unit is in square.
    /// Ignored for cavalry and when there is no supporting unit.
    var supportingUnitInSquare: Bool = false

    /// True when the supporting unit moved into melee this turn.
    /// This is tracked separately from the artillery attacker's movement because
    /// some supporting-unit melee rules depend only on whether that support unit
    /// moved into melee, not on how many hexes it moved.
    var supportingUnitMovedIntoMelee: Bool = false


    /////////////////////////////////////////////
    
    
    /// Leader support selected for each side in this combat.
    var attackerLeaderSupport: CombatLeaderSupport = .none
    var defenderLeaderSupport: CombatLeaderSupport = .none

    /// Whether the defender is supported for morale in this combat.
    var defenderSupported: Bool = false

    /// Direction matters for certain terrain interactions,
    /// such as attacks involving hills or other protected positions.
    var attackDirection: AttackDirection?

    /// True when this context represents a defender Battle Back rather than the
    /// original ordered attack. Some rulesets use different dice in Battle Back.
    var isBattleBack: Bool = false
}
