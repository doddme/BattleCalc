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

        // Class dispatch. Infantry keeps the original melee/ranged paths
        // unchanged. Cavalry and artillery have their own evaluators (Phase 2).
        switch attacker.unitClass {
        case .infantry:
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

        case .cavalry:
            return evaluateCavalry(
                context: context,
                attacker: attacker,
                defender: defender
            )

        case .artillery:
            return evaluateArtillery(
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

    // MARK: - Cavalry (Phase 2)

    /// Cavalry is melee-only. Distance > 1 is not allowed. There is no
    /// moved-into-melee penalty for cavalry, so base dice come from the unit's
    /// melee rule with `movedHexes` forced to 0. Cavalry terrain in/out
    /// modifiers apply through the shared class-based penalties; sabers depend
    /// on the unit's `hasSaber` flag exactly as already modeled.
    private func evaluateCavalry(
        context: CombatContext,
        attacker: UnitDefinition,
        defender: UnitDefinition
    ) -> CombatResult {

        let distance = context.targetDistance ?? 1
        guard distance <= 1 else {
            return blockedResult(
                reason: "\(attacker.name) is melee-only and cannot attack a target \(distance) hexes away.",
                ruleID: "napoleonics.cavalry.meleeOnly"
            )
        }

        // No moved-to-melee penalty for cavalry: force movedHexes to 0.
        let baseDice = meleeBaseDice(
            for: attacker,
            currentBlocks: context.attackerBlocks,
            movedHexes: 0
        )

        let attackerTerrain = NapoleonicsTerrainLibrary.terrain(for: context.attackerTerrainID)
        let defenderTerrain = NapoleonicsTerrainLibrary.terrain(for: context.defenderTerrainID)

        var modifiers: [CombatModifier] = []
        var appliedRules: [AppliedRule] = [
            AppliedRule(
                ruleID: "napoleonics.cavalry.baseRule",
                title: "Base cavalry melee",
                outcome: "Current blocks \(context.attackerBlocks) -> \(baseDice) dice"
            )
        ]

        // Hill-to-hill (and any future special melee) takes precedence over the
        // standard per-class terrain penalties, exactly as in the infantry path,
        // so cavalry no longer takes the hill out/into deduction in hill-to-hill
        // melee.
        if let special = specialMeleeResolution(
            context: context,
            attacker: attacker,
            defender: defender,
            attackerTerrain: attackerTerrain,
            defenderTerrain: defenderTerrain
        ) {
            appliedRules.append(
                AppliedRule(ruleID: special.ruleID, title: special.title, outcome: special.outcome)
            )
            if special.modifier != 0 {
                modifiers.append(
                    CombatModifier(id: UUID(), label: special.title, value: special.modifier, detail: special.detail)
                )
            }
        } else {
            applyTerrainModifiers(
                attacker: attacker,
                attackerTerrain: attackerTerrain,
                defenderTerrain: defenderTerrain,
                verb: "melee",
                ruleNamespace: "napoleonics.cavalry",
                modifiers: &modifiers,
                appliedRules: &appliedRules
            )
        }

        let modifierTotal = modifiers.map(\.value).reduce(0, +)
        let finalDice = max(0, baseDice + modifierTotal)

        appliedRules.append(
            AppliedRule(
                ruleID: "napoleonics.result.final",
                title: "Final cavalry melee",
                outcome: "\(finalDice) dice"
            )
        )

        return CombatResult(
            validation: CombatValidation(isAllowed: true, reasons: []),
            baseDice: baseDice,
            modifiers: modifiers,
            modifierTotal: modifierTotal,
            finalDice: finalDice,
            notes: ["Napoleonics cavalry melee evaluation."],
            appliedRules: appliedRules
        )
    }

    // MARK: - Artillery (Phase 2)

    /// Artillery ignores the legacy `range` column entirely. The active fire
    /// band is selected by standing/moved × current block band (>1 or ==1).
    /// Distance 1 is melee (base dice = active band index 0; sabers/terrain
    /// apply; the defender's battle-back is left to the existing resolution
    /// flow). Distance > 1 is fire (base dice = active band index distance-1).
    /// A whole `nil` band = not allowed; a `nil` slot or a distance past the
    /// band = out of range, reported with the table-derived range.
    private func evaluateArtillery(
        context: CombatContext,
        attacker: UnitDefinition,
        defender: UnitDefinition
    ) -> CombatResult {

        guard let tables = attacker.combatProfile.artilleryFireTables else {
            return blockedResult(
                reason: "\(attacker.name) has no artillery fire data.",
                ruleID: "napoleonics.artillery.noTables"
            )
        }

        let distance = context.targetDistance ?? 1
        let moved = (context.movedHexes ?? 0) > 0
        let singleBlock = context.attackerBlocks <= 1

        guard let band = artilleryActiveBand(tables: tables, moved: moved, singleBlock: singleBlock) else {
            return blockedResult(
                reason: artilleryNotAllowedReason(attacker: attacker, moved: moved, singleBlock: singleBlock),
                ruleID: "napoleonics.artillery.tableNotAllowed"
            )
        }

        // The active moving band only says moving fire *exists*; maxMovementToShoot
        // still caps how far the unit may move and still fire. So even when the
        // moving table is populated (e.g. Horse Artillery), firing is NOT ALLOWED
        // when movedHexes exceeds maxMovementToShoot — same concept as infantry.
        // Distance 1 is melee (adjacent), which is governed by maxMovement rather
        // than the fire cap, so this gate applies to fire (distance > 1) only.
        let movedHexes = context.movedHexes ?? 0
        if distance > 1, movedHexes > attacker.combatProfile.maxMovementToShoot {
            return blockedResult(
                reason: "\(attacker.name) cannot fire after moving \(movedHexes) hexes.",
                ruleID: "napoleonics.artillery.movedCannotFire"
            )
        }

        let derivedRange = artilleryDerivedRange(band)
        let index = distance - 1
        guard index >= 0, index < band.count, let slotDice = band[index] else {
            return blockedResult(
                reason: "Target is out of range. This artillery range is \(derivedRange) hex\(derivedRange == 1 ? "" : "es").",
                ruleID: "napoleonics.artillery.outOfRange"
            )
        }

        let isMelee = distance <= 1
        let baseDice = slotDice

        let attackerTerrain = NapoleonicsTerrainLibrary.terrain(for: context.attackerTerrainID)
        let defenderTerrain = NapoleonicsTerrainLibrary.terrain(for: context.defenderTerrainID)

        var modifiers: [CombatModifier] = []
        var appliedRules: [AppliedRule] = [
            AppliedRule(
                ruleID: isMelee ? "napoleonics.artillery.meleeBase" : "napoleonics.artillery.fireBase",
                title: isMelee ? "Artillery melee base" : "Artillery fire base",
                outcome: "Active table at \(distance) hex\(distance == 1 ? "" : "es") -> \(baseDice) dice"
            )
        ]

        // Apply hill-to-hill (and any future special) resolution first, matching
        // the infantry path: melee hill-to-hill = no modifier, ranged
        // hill-to-hill = -1. Only when there is no special do the standard
        // per-class terrain penalties apply.
        let special = isMelee
            ? specialMeleeResolution(context: context, attacker: attacker, defender: defender,
                                     attackerTerrain: attackerTerrain, defenderTerrain: defenderTerrain)
            : specialRangedResolution(context: context, attacker: attacker, defender: defender,
                                      attackerTerrain: attackerTerrain, defenderTerrain: defenderTerrain)
        if let special {
            appliedRules.append(
                AppliedRule(ruleID: special.ruleID, title: special.title, outcome: special.outcome)
            )
            if special.modifier != 0 {
                modifiers.append(
                    CombatModifier(id: UUID(), label: special.title, value: special.modifier, detail: special.detail)
                )
            }
        } else {
            applyTerrainModifiers(
                attacker: attacker,
                attackerTerrain: attackerTerrain,
                defenderTerrain: defenderTerrain,
                verb: isMelee ? "melee" : "ranged fire",
                ruleNamespace: isMelee ? "napoleonics.artillery.melee" : "napoleonics.artillery.fire",
                modifiers: &modifiers,
                appliedRules: &appliedRules
            )
        }

        let modifierTotal = modifiers.map(\.value).reduce(0, +)
        let finalDice = max(0, baseDice + modifierTotal)

        appliedRules.append(
            AppliedRule(
                ruleID: "napoleonics.result.final",
                title: isMelee ? "Final artillery melee" : "Final artillery fire",
                outcome: "\(finalDice) dice"
            )
        )

        return CombatResult(
            validation: CombatValidation(isAllowed: true, reasons: []),
            baseDice: baseDice,
            modifiers: modifiers,
            modifierTotal: modifierTotal,
            finalDice: finalDice,
            notes: [
                "Napoleonics artillery \(isMelee ? "melee" : "fire") evaluation.",
                "artilleryBase:\(baseDice)@\(distance)"
            ],
            appliedRules: appliedRules
        )
    }

    // MARK: - Artillery Helpers (Phase 2)

    /// Selects the active fire band for the current standing/moved × block-band
    /// situation. Returns `nil` when that band is "not allowed".
    private func artilleryActiveBand(
        tables: ArtilleryFireTables,
        moved: Bool,
        singleBlock: Bool
    ) -> ArtilleryFireBand? {
        switch (moved, singleBlock) {
        case (false, false): return tables.standingMultiBlock
        case (false, true):  return tables.standingSingleBlock
        case (true, false):  return tables.movingMultiBlock
        case (true, true):   return tables.movingSingleBlock
        }
    }

    /// Derived range for a band: highest non-nil slot index + 1 (trailing nil
    /// slots = out of range, so they do not extend the range). An all-nil band
    /// yields 0.
    private func artilleryDerivedRange(_ band: ArtilleryFireBand) -> Int {
        var range = 0
        for (i, slot) in band.enumerated() where slot != nil {
            range = i + 1
        }
        return range
    }

    /// Generic, unit-name based reason for a "not allowed" active band. Foot
    /// guns have no moving bands; horse guns with 1 block may have no
    /// moving-single band — both read naturally from the unit's name.
    private func artilleryNotAllowedReason(
        attacker: UnitDefinition,
        moved: Bool,
        singleBlock: Bool
    ) -> String {
        if moved {
            if singleBlock {
                return "\(attacker.name) with 1 block cannot fire after moving."
            }
            return "\(attacker.name) cannot fire after moving."
        }
        if singleBlock {
            return "\(attacker.name) with 1 block cannot fire."
        }
        return "\(attacker.name) cannot fire in this situation."
    }

    /// Shared attacker-out / defender-into terrain modifiers for the Phase 2
    /// cavalry and artillery paths. Mirrors the infantry terrain handling but
    /// without the infantry-only hill-to-hill specials.
    private func applyTerrainModifiers(
        attacker: UnitDefinition,
        attackerTerrain: TerrainDefinition?,
        defenderTerrain: TerrainDefinition?,
        verb: String,
        ruleNamespace: String,
        modifiers: inout [CombatModifier],
        appliedRules: inout [AppliedRule]
    ) {
        if let attackerTerrain {
            let penalty = outPenalty(for: attacker.unitClass, terrain: attackerTerrain)
            if penalty != 0 {
                modifiers.append(
                    CombatModifier(
                        id: UUID(),
                        label: "Attacker terrain",
                        value: penalty,
                        detail: "Attacking out of \(attackerTerrain.name) affected \(verb)."
                    )
                )
                appliedRules.append(
                    AppliedRule(
                        ruleID: "\(ruleNamespace).attackerTerrainOut",
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
                        detail: "Attacking into \(defenderTerrain.name) affected \(verb)."
                    )
                )
                appliedRules.append(
                    AppliedRule(
                        ruleID: "\(ruleNamespace).defenderTerrainInto",
                        title: "Defender terrain into penalty",
                        outcome: "\(defenderTerrain.name): \(penalty) dice"
                    )
                )
            }
        }
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

        // Hill-to-hill melee (all classes): no terrain-based dice modifier when
        // both units are on hill hexes. Returning a non-nil special with
        // modifier 0 also suppresses the normal attacker-out / defender-into
        // terrain penalties (e.g. cavalry's hill out/into -1), so the only
        // terrain effect of hill-vs-hill melee is "none".
        if attackerTerrain.id == "hill",
           defenderTerrain.id == "hill" {
            return SpecialCaseResolution(
                modifier: 0,
                ruleID: "napoleonics.melee.hillToHill",
                title: "Hill-to-hill melee",
                outcome: "No hill deduction",
                detail: "Melee from hill to hill does not reduce battle dice."
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

        // Hill-to-hill ranged fire (all classes): firing from hill to hill
        // reduces dice by exactly 1, replacing the normal attacker-out /
        // defender-into hill penalties so the net hill-vs-hill ranged effect is
        // a single -1 regardless of class.
        if attackerTerrain.id == "hill",
           defenderTerrain.id == "hill" {
            return SpecialCaseResolution(
                modifier: -1,
                ruleID: "napoleonics.ranged.hillToHill",
                title: "Hill-to-hill ranged fire",
                outcome: "-1 die",
                detail: "Ranged fire from hill to hill reduces battle dice by 1."
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
