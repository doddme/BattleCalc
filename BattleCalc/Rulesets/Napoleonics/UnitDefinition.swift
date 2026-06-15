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
    
    /// half rounded down minus 1 block
    case halfCurrentBlocksRoundedDownMinusOne

    /// Use current blocks directly even after moving.
    case currentBlocks
}

/// How melee dice are derived from current blocks.
enum MeleeRule: String, Codable, CaseIterable, Hashable {
    case currentBlocks
    case currentBlocksPlusOne
    case currentBlocksMinusOneIfMoved
}


/// Focused set of bonus flags for the first evaluator.
struct UnitCombatBonuses: Codable, Hashable {
    /// Some units gain +1 die in melee against infantry.
    var meleeBonusVsInfantry: Bool = false
}

/// One artillery fire band: dice indexed by hex distance (index 0 == distance
/// 1). Each slot is itself optional so the data can distinguish "out of range
/// at this distance" from "zero dice at this distance":
///
/// - The whole band `nil` (the `ArtilleryFireBand?` is `nil`) = the attack is
///   **not allowed** for that movement/block-band situation (e.g. foot
///   artillery cannot fire after moving, so both `moving*` bands are `nil`;
///   horse artillery with 1 block moved has `movingSingleBlock` `nil`).
/// - A `nil` **slot** inside a non-nil band = that distance is **out of
///   range** (no attack possible at exactly that distance). This is how a
///   trailing blank like `3|2|1||` is preserved as `[3, 2, 1, nil, nil]`
///   rather than collapsing to `[3, 2, 1]`.
/// - A numeric slot is the **dice value** at that distance. A `0` slot would
///   mean a legal attack yielding zero dice — not the current data intent
///   (out-of-range is left blank, never written as 0).
typealias ArtilleryFireBand = [Int?]

/// Optional fire tables for artillery: dice indexed by hex distance
/// (index 0 == distance 1). Each table is split into a `multiBlock` band
/// (current blocks > 1) and a `singleBlock` band (exactly 1 block remaining).
/// See `ArtilleryFireBand` for the per-slot semantics.
///
/// Semantics summary (encoded here for the future evaluator; NOT yet consumed):
/// - A `nil` band means the attack is **not allowed** for that
///   movement/block-band situation.
/// - A `nil` slot inside a non-nil band means **out of range** at that distance.
/// - A numeric slot is the **dice value**; `0` would mean a legal zero-dice
///   attack (not the current data intent).
/// - Distance 1 is resolved as melee using `standing*Block[0]` as the base
///   dice (sabers/terrain still apply); the evaluator will read index 0.
///
/// All fields are optional and default to `nil`, so infantry/cavalry rows
/// that omit them are unaffected and remain `Codable`/`Hashable`.
struct ArtilleryFireTables: Codable, Hashable {
    /// Standing (did not move) fire, current blocks > 1. `nil` = not allowed.
    var standingMultiBlock: ArtilleryFireBand? = nil

    /// Standing fire, exactly 1 block remaining. `nil` = not allowed.
    var standingSingleBlock: ArtilleryFireBand? = nil

    /// Moving fire, current blocks > 1. `nil` = not allowed (e.g. foot guns).
    var movingMultiBlock: ArtilleryFireBand? = nil

    /// Moving fire, exactly 1 block remaining. `nil` = not allowed.
    var movingSingleBlock: ArtilleryFireBand? = nil

    /// True when at least one band is populated (i.e. the unit has any
    /// artillery fire data at all).
    var hasAnyTable: Bool {
        standingMultiBlock != nil || standingSingleBlock != nil
            || movingMultiBlock != nil || movingSingleBlock != nil
    }
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

    /// Melee behavior. This is the existing "melee dice rule" for the unit;
    /// the CSV column is named `meleeDiceRule` and maps onto this `MeleeRule`
    /// enum. Defaults preserve current infantry behavior.
    var meleeRule: MeleeRule

    /// When true the unit may only fight in melee (no ranged/fire attacks).
    /// Default `false` keeps infantry/artillery unaffected. Intended for
    /// cavalry; NOT yet consumed by the evaluator.
    var isMeleeOnly: Bool = false

    /// Optional artillery fire tables (dice by distance and block band).
    /// `nil` for non-artillery units. NOT yet consumed by the evaluator.
    var artilleryFireTables: ArtilleryFireTables? = nil

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
