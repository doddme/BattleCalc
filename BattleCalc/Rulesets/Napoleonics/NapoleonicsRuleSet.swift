//
//  NapoleonicsRuleSet.swift
//  BattleCalc
//
//  Ruleset wrapper for the existing Napoleonics evaluator.
//

import Foundation

struct NapoleonicsRuleSet: GameRuleSet {
    let system: GameSystem = .napoleonics
    let displayName = "Napoleonics"
    let isSelectable = true

    private let evaluator = NapoleonicsInfantryCombatEvaluator()

    func resolveCombat(_ context: CombatContext) -> CombatResult {
        evaluator.evaluate(context: context)
    }
}
