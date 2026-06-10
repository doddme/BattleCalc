//
//  CombatResult.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

// Validation result for a combat query.
// This makes it possible to explain why an attack is not allowed
// instead of only returning a blank or zero result.
struct CombatValidation: Codable, Hashable {
    // True when the attack is legal and can be resolved.
    let isAllowed: Bool

    // Human-readable reasons that explain blocked attacks or important warnings.
    // Example: "This unit cannot fire after moving."
    let reasons: [String]
}

// One applied modifier in the combat calculation.
// We keep these as named line items so the result can show
// how the final dice total was produced.
struct CombatModifier: Codable, Hashable, Identifiable {
    // Stable identifier so modifiers can be shown in SwiftUI lists later.
    let id: UUID

    // Short user-facing label for the modifier source.
    // Example: "Town defense", "Moved and fired", "Range reduction".
    let label: String

    // Signed value applied to the dice total.
    // Negative values reduce dice, positive values increase dice.
    let value: Int

    // Optional detail text for a fuller explanation when needed.
    let detail: String?
}

// Full output from evaluating a CombatContext.
// This is what the rules engine will return to the UI after resolving an attack.
struct CombatResult: Codable, Hashable {
    // Legal/illegal status and any explanation messages.
    let validation: CombatValidation

    // Dice before any modifiers are applied.
    // This is nil when the attack is not legal.
    let baseDice: Int?

    // Itemized list of all modifiers that changed the result.
    let modifiers: [CombatModifier]

    // Sum of all modifier values.
    let modifierTotal: Int

    // Final resolved dice after modifiers are applied.
    // This is nil when the attack is not legal.
    let finalDice: Int?

    // Optional notes for extra explanation that does not fit neatly
    // into validation or modifier line items.
    let notes: [String]

    // Optional rule identifiers that were applied during evaluation.
    // This gives us a path later to trace results back to specific data-driven rules.
    let appliedRuleIDs: [String]
}
