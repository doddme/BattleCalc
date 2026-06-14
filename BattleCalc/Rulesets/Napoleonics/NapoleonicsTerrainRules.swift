//
//  NapoleonicsTerrainRules.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/12/26.
//

import Foundation

enum NapoleonicsTerrainRules {

    static func meleeModifier(
        attackerTerrainID: String?,
        defenderTerrainID: String?
    ) -> Int {
        // Fordable river: any melee into or out of the river is -1.
        if attackerTerrainID == "fordable-river" || defenderTerrainID == "fordable-river" {
            return -1
        }

        // Hill: attacking into a hill is -1 unless both units are on hills.
        if defenderTerrainID == "hill" {
            if attackerTerrainID == "hill" {
                return 0
            } else {
                return -1
            }
        }

        return 0
    }
}

