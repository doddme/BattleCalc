//
//  GameCatalog.swift
//  BattleCalc
//
//  Registry of rulesets known to the app shell.
//

import Foundation

enum GameCatalog {
    static let supported: [any GameRuleSet] = [
        NapoleonicsRuleSet(),
        AncientsRuleSet()
    ]

    static func ruleset(for system: GameSystem) -> (any GameRuleSet)? {
        supported.first { $0.system == system }
    }
}
