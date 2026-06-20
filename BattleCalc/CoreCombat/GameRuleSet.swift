//
//  GameRuleSet.swift
//  BattleCalc
//
//  Minimal ruleset boundary for routing combat resolution by selected game.
//  The current UI still uses the existing Napoleonics path until each game flow
//  is ready to be switched over safely.
//

import Foundation

protocol GameRuleSet {
    var system: GameSystem { get }
    var displayName: String { get }
    var isSelectable: Bool { get }
    var supportsTerrainImages: Bool { get }
    var supportsUnitImages: Bool { get }
    func resolveCombat(_ context: CombatContext) -> CombatResult
}
extension GameRuleSet {
    var supportsTerrainImages: Bool { false }
    var supportsUnitImages: Bool { false }
}
