//
//  CombatResult.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

/// One human-readable rule explanation attached to a combat result.
/// This is useful for debug output now and for the final product later
/// when players want to understand how a number was produced.
struct AppliedRule: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    /// Stable internal rule identifier.
    var ruleID: String

    /// Human-readable label for the rule.
    var title: String

    /// What the rule actually did in this calculation.
    var outcome: String
}

/// Whether the requested combat was legal and, if not, why it failed.
struct CombatValidation: Codable, Hashable {
    var isAllowed: Bool
    var reasons: [String]
}

/// One numeric modifier that affected the result.
struct CombatModifier: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var value: Int
    var detail: String?
}

/// Final output for one combat calculation.
struct CombatResult: Codable, Hashable {
    var validation: CombatValidation

    /// Dice before modifiers are applied.
    var baseDice: Int?

    /// Line-item modifiers applied after the base dice.
    var modifiers: [CombatModifier]

    /// Sum of all modifier values.
    var modifierTotal: Int

    /// Final dice after modifiers, never below zero.
    var finalDice: Int?

    /// Free-form notes for temporary explanation or reminders.
    var notes: [String]

    /// Human-readable explanation trace for how the result was built.
    var appliedRules: [AppliedRule]
}
