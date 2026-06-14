//
// NapoleonicsInfantryCombatEvaluator.swift
// BattleCalc
//
// Created by Mike Dodd on 6/11/26.
//

import Foundation

/// Napoleonics-only infantry combat evaluator.
/// Version 1 is intentionally narrow:
/// - infantry attackers only
/// - basic melee vs ranged handling
/// - movement-aware ranged fire
/// - simple terrain restrictions
/// - no cards yet
/// - no cavalry / artillery yet
struct NapoleonicsInfantryCombatEvaluator {

    /// Main entry point for one combat calculation.
    /// This version resolves the attacker and defender from the IDs
    /// stored in CombatContext, so the runtime state drives the lookup.
    func evaluate(context: CombatContext) -> CombatResult {

        // Resolve the attacking unit from the runtime attackerUnitID.
        guard let attacker = NapoleonicsUnitLibrary.unit(for: context.attackerUnitID) else {
            return blockedResult(
                reason: "Could not find attacker unit definition for \(context.attackerUnitID).",
                ruleID: "napoleonics.lookup.missingAttacker"
            )
        }

        // Resolve the defending unit from the runtime defenderUnitID.
        guard let defender = NapoleonicsUnitLibrary.unit(for: context.defenderUnitID) else {
            return blockedResult(
                reason: "Could not find defender unit definition for \(context.defenderUnitID).",
                ruleID: "napoleonics.lookup.missingDefender"
            )
        }

        return evaluateResolvedUnits(
            context: context,
            attacker: attacker,
            defender: defender
        )
    }

    /// Internal evaluation path once both unit definitions have been found.
    private func evaluateResolvedUnits(
        context: CombatContext,
        attacker: UnitDefinition,
        defender: UnitDefinition
    ) -> CombatResult {

        // Version 1 supports infantry attackers only.
        guard attacker.unitClass == .infantry else {
            return blockedResult(
                reason: "Version 1 evaluator only supports infantry attackers.",
                ruleID: "napoleonics.infantry.only"
            )
        }

        let attackerTerrain = NapoleonicsTerrainLibrary.terrain(for: context.attackerTerrainID)

        if (context.movedHexes ?? 0) > 0,
           let attackerTerrain,
           attackerTerrain.blocksBattleOnEntry,
           !attacker.combatProfile.canBattleAfterEnteringTerrainIDs.contains(attackerTerrain.id) {
            return blockedResult(
                reason: "\(attacker.name) cannot battle on the turn it enters \(attackerTerrain.name).",
                ruleID: "napoleonics.terrain.blocksBattleOnEntry"
            )
        }

        switch context.combatMode {
        case .melee:
            return evaluateMelee(
                context: context,
                attacker: attacker,
                defender: defender
            )

        case .ranged:
            return evaluateRanged(
                context: context,
                attacker: attacker,
                defender: defender
            )
        }
    }

    // MARK: - Melee

    /// Resolve a melee attack using the attacker's melee rule,
    /// plus any currently supported modifiers.
    private func evaluateMelee(
        context: CombatContext,
        attacker: UnitDefinition,
        defender: UnitDefinition
    ) -> CombatResult {

        let baseDice = meleeBaseDice(
            for: attacker,
            currentBlocks: context.attackerBlocks,
            movedHexes: context.movedHexes ?? 0
        )

        
        let attackerTerrain = NapoleonicsTerrainLibrary.terrain(for: context.attackerTerrainID)
        let defenderTerrain = NapoleonicsTerrainLibrary.terrain(for: context.defenderTerrainID)

        var modifiers: [CombatModifier] = []
        var appliedRules: [AppliedRule] = [
            AppliedRule(
                ruleID: "napoleonics.melee.baseRule",
                title: "Base melee attack",
                outcome: meleeBaseExplanation(
                    for: attacker,
                    currentBlocks: context.attackerBlocks,
                    movedHexes: context.movedHexes ?? 0,
                    result: baseDice
                )

            )
        ]

        if attacker.combatProfile.bonuses.meleeBonusVsInfantry && defender.unitClass == .infantry {
            modifiers.append(
                CombatModifier(
                    id: UUID(),
                    label: "Melee vs infantry",
                    value: 1,
                    detail: "This unit gains +1 die in melee against infantry."
                )
            )

            appliedRules.append(
                AppliedRule(
                    ruleID: "napoleonics.melee.bonusVsInfantry",
                    title: "Infantry melee bonus",
                    outcome: "+1 die"
                )
            )
        }

        if let special = specialMeleeResolution(
            context: context,
            attacker: attacker,
            defender: defender,
            attackerTerrain: attackerTerrain,
            defenderTerrain: defenderTerrain
        ) {
            appliedRules.append(
                AppliedRule(
                    ruleID: special.ruleID,
                    title: special.title,
                    outcome: special.outcome
                )
            )

            if special.modifier != 0 {
                modifiers.append(
                    CombatModifier(
                        id: UUID(),
                        label: special.title,
                        value: special.modifier,
                        detail: special.detail
                    )
                )
            }
        } else {
            if let attackerTerrain {
                let penalty = outPenalty(for: attacker.unitClass, terrain: attackerTerrain)

                if penalty != 0 {
                    modifiers.append(
                        CombatModifier(
                            id: UUID(),
                            label: "Attacker terrain",
                            value: penalty,
                            detail: "Attacking out of \(attackerTerrain.name) affected melee."
                        )
                    )

                    appliedRules.append(
                        AppliedRule(
                            ruleID: "napoleonics.melee.attackerTerrainOut",
                            title: "Attacker terrain out penalty",
                            outcome: "\(attackerTerrain.name): \(penalty) dice"
                        )
                    )
                }
            }

            if let defenderTerrain {
                let penalty = intoPenalty(for: attacker.unitClass, terrain: defenderTerrain)

                if penalty != 0 {
                    modifiers.append(
                        CombatModifier(
                            id: UUID(),
                            label: "Defender terrain",
                            value: penalty,
                            detail: "Attacking into \(defenderTerrain.name) affected melee."
                        )
                    )

                    appliedRules.append(
                        AppliedRule(
                            ruleID: "napoleonics.melee.defenderTerrainInto",
                            title: "Defender terrain into penalty",
                            outcome: "\(defenderTerrain.name): \(penalty) dice"
                        )
                    )
                }
            }
        }

        let modifierTotal = modifiers.map(\.value).reduce(0, +)
        let finalDice = max(0, baseDice + modifierTotal)

        appliedRules.append(
            AppliedRule(
                ruleID: "napoleonics.result.final",
                title: "Final melee attack",
                outcome: "\(finalDice) dice"
            )
        )

        return CombatResult(
            validation: CombatValidation(
                isAllowed: true,
                reasons: []
            ),
            baseDice: baseDice,
            modifiers: modifiers,
            modifierTotal: modifierTotal,
            finalDice: finalDice,
            notes: ["Napoleonics infantry melee evaluation."],
            appliedRules: appliedRules
        )
    }

    // MARK: - Ranged

    /// Resolve a ranged attack using movement, range, blocks,
    /// and simple terrain restrictions.
    private func evaluateRanged(
        context: CombatContext,
        attacker: UnitDefinition,
        defender: UnitDefinition
    ) -> CombatResult {

        guard let distance = context.targetDistance else {
            return blockedResult(
                reason: "Ranged attacks require a target distance.",
                ruleID: "napoleonics.ranged.missingDistance"
            )
        }

        guard distance > 1 else {
            return blockedResult(
                reason: "Adjacent attacks are resolved as melee, not ranged fire.",
                ruleID: "napoleonics.ranged.adjacentIsMelee"
            )
        }

        guard distance <= attacker.combatProfile.range else {
            return blockedResult(
                reason: "Target is out of range for \(attacker.name).",
                ruleID: "napoleonics.ranged.outOfRange"
            )
        }

        let movedHexes = context.movedHexes ?? 0

        guard movedHexes <= attacker.combatProfile.maxMovementToShoot else {
            return blockedResult(
                reason: "\(attacker.name) cannot fire after moving \(movedHexes) hexes.",
                ruleID: "napoleonics.ranged.movedCannotFire"
            )
        }

        let attackerTerrain = NapoleonicsTerrainLibrary.terrain(for: context.attackerTerrainID)
        let defenderTerrain = NapoleonicsTerrainLibrary.terrain(for: context.defenderTerrainID)

        let baseDice: Int
        var appliedRules: [AppliedRule] = []
        var modifiers: [CombatModifier] = []

        if movedHexes > 0 {
            baseDice = movingFireDice(
                for: attacker,
                currentBlocks: context.attackerBlocks
            )

            appliedRules.append(
                AppliedRule(
                    ruleID: "napoleonics.ranged.movingFireRule",
                    title: "Moving fire rule",
                    outcome: movingFireExplanation(
                        for: attacker,
                        currentBlocks: context.attackerBlocks,
                        result: baseDice
                    )
                )
            )
        } else {
            baseDice = standingFireDice(
                for: attacker,
                currentBlocks: context.attackerBlocks
            )

            appliedRules.append(
                AppliedRule(
                    ruleID: "napoleonics.ranged.standingFireRule",
                    title: "Standing fire rule",
                    outcome: "Current blocks \(context.attackerBlocks) -> \(baseDice) dice"
                )
            )
        }

        if let special = specialRangedResolution(
            context: context,
            attacker: attacker,
            defender: defender,
            attackerTerrain: attackerTerrain,
            defenderTerrain: defenderTerrain
        ) {
            appliedRules.append(
                AppliedRule(
                    ruleID: special.ruleID,
                    title: special.title,
                    outcome: special.outcome
                )
            )

            if special.modifier != 0 {
                modifiers.append(
                    CombatModifier(
                        id: UUID(),
                        label: special.title,
                        value: special.modifier,
                        detail: special.detail
                    )
                )
            }
        } else {
            if let attackerTerrain {
                let penalty = outPenalty(for: attacker.unitClass, terrain: attackerTerrain)

                if penalty != 0 {
                    modifiers.append(
                        CombatModifier(
                            id: UUID(),
                            label: "Attacker terrain",
                            value: penalty,
                            detail: "Attacking out of \(attackerTerrain.name) affected ranged fire."
                        )
                    )

                    appliedRules.append(
                        AppliedRule(
                            ruleID: "napoleonics.ranged.attackerTerrainOut",
                            title: "Attacker terrain out penalty",
                            outcome: "\(attackerTerrain.name): \(penalty) dice"
                        )
                    )
                }
            }

            if let defenderTerrain {
                let penalty = intoPenalty(for: attacker.unitClass, terrain: defenderTerrain)

                if penalty != 0 {
                    modifiers.append(
                        CombatModifier(
                            id: UUID(),
                            label: "Defender terrain",
                            value: penalty,
                            detail: "Attacking into \(defenderTerrain.name) affected ranged fire."
                        )
                    )

                    appliedRules.append(
                        AppliedRule(
                            ruleID: "napoleonics.ranged.defenderTerrainInto",
                            title: "Defender terrain into penalty",
                            outcome: "\(defenderTerrain.name): \(penalty) dice"
                        )
                    )
                }
            }
        }

        let modifierTotal = modifiers.map(\.value).reduce(0, +)
        let finalDice = max(0, baseDice + modifierTotal)

        appliedRules.append(
            AppliedRule(
                ruleID: "napoleonics.result.final",
                title: "Final ranged attack",
                outcome: "\(finalDice) dice"
            )
        )

        return CombatResult(
            validation: CombatValidation(
                isAllowed: true,
                reasons: []
            ),
            baseDice: baseDice,
            modifiers: modifiers,
            modifierTotal: modifierTotal,
            finalDice: finalDice,
            notes: ["Napoleonics infantry ranged evaluation."],
            appliedRules: appliedRules
        )
    }

    // MARK: - Special Case Rules

    private struct SpecialCaseResolution {
        let modifier: Int
        let ruleID: String
        let title: String
        let outcome: String
        let detail: String
    }

    /// Resolve special-case melee rules before applying standard terrain modifiers.
    /// Return nil when normal rules should be used.
    private func specialMeleeResolution(
        context: CombatContext,
        attacker: UnitDefinition,
        defender: UnitDefinition,
        attackerTerrain: TerrainDefinition?,
        defenderTerrain: TerrainDefinition?
    ) -> SpecialCaseResolution? {

        guard let attackerTerrain, let defenderTerrain else { return nil }

        // Infantry hill-to-hill melee:
        // no hill deduction when both units are on hill hexes.
        if attacker.unitClass == .infantry,
           attackerTerrain.id == "hill",
           defenderTerrain.id == "hill" {
            return SpecialCaseResolution(
                modifier: 0,
                ruleID: "napoleonics.melee.hillToHill",
                title: "Hill-to-hill melee",
                outcome: "No hill deduction",
                detail: "Infantry melee from hill to hill does not reduce battle dice."
            )
        }

        return nil
    }

    /// Resolve special-case ranged rules before applying standard terrain modifiers.
    /// Return nil when normal rules should be used.
    private func specialRangedResolution(
        context: CombatContext,
        attacker: UnitDefinition,
        defender: UnitDefinition,
        attackerTerrain: TerrainDefinition?,
        defenderTerrain: TerrainDefinition?
    ) -> SpecialCaseResolution? {

        guard let attackerTerrain, let defenderTerrain else { return nil }

        // Infantry hill-to-hill ranged fire:
        // ranged combat from hill to hill reduces dice by 1.
        if attacker.unitClass == .infantry,
           attackerTerrain.id == "hill",
           defenderTerrain.id == "hill" {
            return SpecialCaseResolution(
                modifier: -1,
                ruleID: "napoleonics.ranged.hillToHill",
                title: "Hill-to-hill ranged fire",
                outcome: "-1 die",
                detail: "Infantry ranged fire from hill to hill reduces battle dice by 1."
            )
        }

        return nil
    }

    // MARK: - Dice Rules

    /// Standing fire comes straight from the unit's standing fire rule.
    private func standingFireDice(
        for unit: UnitDefinition,
        currentBlocks: Int
    ) -> Int {
        switch unit.combatProfile.standingFireRule {
        case .currentBlocks:
            return currentBlocks
        case .currentBlocksPlusOne:
            return currentBlocks + 1
        }
    }

    /// Moving fire comes from the unit's moving fire rule.
    /// This is where round-up versus round-down is enforced.
    private func movingFireDice(
        for unit: UnitDefinition,
        currentBlocks: Int
    ) -> Int {
        switch unit.combatProfile.movingFireRule {
        case .none:
            return 0

        case .halfCurrentBlocksRoundedUp:
            return Int(ceil(Double(currentBlocks) / 2.0))

        case .halfCurrentBlocksRoundedUpPlusOne:
            return Int(ceil(Double(currentBlocks) / 2.0)) + 1

        case .halfCurrentBlocksRoundedDownPlusOne:
            return (currentBlocks / 2) + 1

        case .halfCurrentBlocksRoundedDown:
            return currentBlocks / 2
        case .halfCurrentBlocksRoundedDownMinusOne:
            return currentBlocks / 2 - 1
        case .currentBlocks:
            return currentBlocks
        }
    }

    /// Human-readable explanation for moving fire.
    private func movingFireExplanation(
        for unit: UnitDefinition,
        currentBlocks: Int,
        result: Int
    ) -> String {
        switch unit.combatProfile.movingFireRule {
        case .none:
            return "Unit may not fire after moving -> 0 dice"

        case .halfCurrentBlocksRoundedUp:
            return "Half current blocks rounded up: \(currentBlocks) -> \(result) dice"

        case .halfCurrentBlocksRoundedUpPlusOne:
            return "Half current blocks rounded up, plus 1: \(currentBlocks) -> \(result) dice"

        case .halfCurrentBlocksRoundedDownPlusOne:
            return "Half current blocks rounded down, plus 1: \(currentBlocks) -> \(result) dice"

        case .halfCurrentBlocksRoundedDown:
            return "Half current blocks rounded down: \(currentBlocks) -> \(result) dice"
       
        case .halfCurrentBlocksRoundedDownMinusOne:
            return "Half current blocks rounded down, minus 1: \(currentBlocks) -> \(result) dice"

        case .currentBlocks:
            return "Current blocks used directly: \(currentBlocks) -> \(result) dice"
        }
    }

    /// Melee comes straight from the unit's melee rule.
    private func meleeBaseDice(
        for unit: UnitDefinition,
        currentBlocks: Int,
        movedHexes: Int
    ) -> Int {
        let movedThisTurn = movedHexes > 0

        switch unit.combatProfile.meleeRule {
        case .currentBlocks:
            return currentBlocks

        case .currentBlocksPlusOne:
            return currentBlocks + 1

        case .currentBlocksMinusOneIfMoved:
            return max(0, currentBlocks - (movedThisTurn ? 1 : 0))

        }
    }
    
    private func meleeBaseExplanation(
        for unit: UnitDefinition,
        currentBlocks: Int,
        movedHexes: Int,
        result: Int
    ) -> String {
        let movedThisTurn = movedHexes > 0

        switch unit.combatProfile.meleeRule {
        case .currentBlocks:
            return "Current blocks used directly: \(currentBlocks) -> \(result) dice"

        case .currentBlocksPlusOne:
            return "Current blocks plus 1: \(currentBlocks) -> \(result) dice"

        case .currentBlocksMinusOneIfMoved:
            let countryName = unit.countryID.capitalized
            let armName = unit.unitClass.rawValue.capitalized
            if movedThisTurn {
                return "Current blocks minus 1 because this \(countryName) \(armName) unit moved into melee this turn: \(currentBlocks) -> \(result) dice"
            } else {
                return "Current blocks with no movement penalty: \(currentBlocks) -> \(result) dice"
            }

        
        }
    }


    // MARK: - Terrain Helpers

    private func intoPenalty(
        for unitClass: UnitClass,
        terrain: TerrainDefinition
    ) -> Int {
        switch unitClass {
        case .infantry:
            return terrain.infantryIntoPenalty
        case .cavalry:
            return terrain.cavalryIntoPenalty
        case .artillery:
            return terrain.artilleryIntoPenalty
        }
    }

    private func outPenalty(
        for unitClass: UnitClass,
        terrain: TerrainDefinition
    ) -> Int {
        switch unitClass {
        case .infantry:
            return terrain.infantryOutPenalty
        case .cavalry:
            return terrain.cavalryOutPenalty
        case .artillery:
            return terrain.artilleryOutPenalty
        }
    }

    // MARK: - Result Helper

    /// Shared helper for illegal or blocked attacks.
    private func blockedResult(reason: String, ruleID: String) -> CombatResult {
        CombatResult(
            validation: CombatValidation(
                isAllowed: false,
                reasons: [reason]
            ),
            baseDice: nil,
            modifiers: [],
            modifierTotal: 0,
            finalDice: nil,
            notes: [],
            appliedRules: [
                AppliedRule(
                    ruleID: ruleID,
                    title: "Attack blocked",
                    outcome: reason
                )
            ]
        )
    }
}
