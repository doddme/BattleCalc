//
//  UnitDefinition.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

/// Broad category used by the shared combat engine.
enum UnitClass: String, Codable, CaseIterable, Hashable {
    case infantry
    case cavalry
    case artillery
}

/// How standing fire dice are derived from current blocks.
enum StandingFireRule: String, Codable, CaseIterable, Hashable {
    case currentBlocks
    case currentBlocksPlusOne
}

/// How moving fire dice are derived from current blocks.
enum MovingFireRule: String, Codable, CaseIterable, Hashable {
    /// Unit may not fire after moving.
    case none

    /// Use half the current blocks and round up.
    /// Example: 3 blocks -> 2 dice.
    case halfCurrentBlocksRoundedUp

    /// use half the current blocks and round up then add 1 to the result of the division
    case halfCurrentBlocksRoundedUpPlusOne
    
    // use half rounded down and add 1
    case halfCurrentBlocksRoundedDownPlusOne
    /// Use half the current blocks and round down.
    /// Example: 3 blocks -> 1 die.
    case halfCurrentBlocksRoundedDown

    /// Use current blocks directly even after moving.
    case currentBlocks
}

/// How melee dice are derived from current blocks.
enum MeleeRule: String, Codable, CaseIterable, Hashable {
    case currentBlocks
    case currentBlocksPlusOne
}

/// Focused set of bonus flags for the first evaluator.
struct UnitCombatBonuses: Codable, Hashable {
    /// Some units gain +1 die in melee against infantry.
    var meleeBonusVsInfantry: Bool = false
}

/// Combat-facing rules for one unit type.
struct UnitCombatProfile: Codable, Hashable {
    /// Maximum hexes the unit may move in one turn.
    var maxMovement: Int

    /// Maximum hexes the unit may move and still fire.
    /// 0 means it may not move if it wants to fire.
    var maxMovementToShoot: Int

    /// Maximum firing distance in hexes.
    var range: Int

    /// Standing fire behavior.
    var standingFireRule: StandingFireRule

    /// Moving fire behavior.
    var movingFireRule: MovingFireRule

    /// Melee behavior.
    var meleeRule: MeleeRule

    /// Small bag of boolean combat bonuses.
    var bonuses: UnitCombatBonuses = .init()

    /// Whether the unit may enter woods and still fire (for example)
    var canBattleAfterEnteringTerrainIDs: [String] = []}

/// Shared definition for one unit type.
struct UnitDefinition: Identifiable, Codable, Hashable {
    var id: String
    var countryID: String
    var name: String
    var unitClass: UnitClass
    var maxBlocks: Int
    var hasSaber: Bool
    var combatProfile: UnitCombatProfile
    var notes: [String] = []
}
