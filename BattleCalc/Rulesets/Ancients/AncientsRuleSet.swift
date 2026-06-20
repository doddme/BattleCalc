//
//  AncientsRuleSet.swift
//  BattleCalc
//
//  Draft ruleset wrapper. Ancients remains unavailable in the app picker until
//  its evaluator and UI have been reviewed against the published rules.
//

import Foundation

struct AncientsRuleSet: GameRuleSet {
    let system: GameSystem = .ancients
    let displayName = "Ancients"
    let isSelectable = true

    private let evaluator = AncientsCombatEvaluator()

    func resolveCombat(_ context: CombatContext) -> CombatResult {
        evaluator.evaluate(context)
    }
}
