//
//  NapoleonicsSampleCombat.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/11/26.
//

import Foundation

// Small library of sample combat situations used for early testing.
// These are not the full game database.
// They are just named examples we can run through the evaluator
// to make sure the rules are being applied correctly.
enum NapoleonicsSampleCombat {

    static let LineUnitMoveIntoForest = CombatContext(
        combatMode: .melee,
        movedHexes: 1,
        targetDistance: 1,
        attackerCountryID: "france",
        attackerUnitID: "french-light-infantry",
        attackerBlocks: 3,
        attackerTerrainID: "forest",
        defenderCountryID: "britain",
        defenderUnitID: "british-line-infantry",
        defenderBlocks: 4,
        defenderTerrainID: "forest",
        attackDirection: .flat
    )

    static let MovedRanged5blocksNoTown = CombatContext(
        combatMode: .ranged,
        movedHexes: 1,
        targetDistance: 2,
        attackerCountryID: "france",
        attackerUnitID: "portugese-line-infantry",
        attackerBlocks: 3,
        attackerTerrainID: nil,
        defenderCountryID: "britain",
        defenderUnitID: "british-line-infantry",
        defenderBlocks: 4,
        defenderTerrainID: nil,
        attackDirection: .flat
    )

    static let MovedRanged3blocksINTOTown = CombatContext(
        combatMode: .ranged,
        movedHexes: 1,
        targetDistance: 2,
        attackerCountryID: "france",
        attackerUnitID: "french-light-infantry",
        attackerBlocks: 3,
        attackerTerrainID: "town",
        defenderCountryID: "britain",
        defenderUnitID: "british-line-infantry",
        defenderBlocks: 4,
        defenderTerrainID: "town",
        attackDirection: .flat
    )

    static let MovedMelee3blocksNoTown = CombatContext(
        combatMode: .melee,
        movedHexes: 1,
        targetDistance: 1,
        attackerCountryID: "france",
        attackerUnitID: "french-line-infantry",
        attackerBlocks: 3,
        attackerTerrainID: nil,
        defenderCountryID: "britain",
        defenderUnitID: "british-line-infantry",
        defenderBlocks: 4,
        defenderTerrainID: nil,
        attackDirection: .flat
    )

    static let all: [(name: String, context: CombatContext)] = [
        ("Light Unit Move Into Forest", LineUnitMoveIntoForest),
        ("Moved Ranged 5 Blocks No Town", MovedRanged5blocksNoTown),
        ("Moved Ranged 3 Blocks Into Town", MovedRanged3blocksINTOTown),
        ("Moved Melee 3 Blocks No Town", MovedMelee3blocksNoTown)
    ]
}
