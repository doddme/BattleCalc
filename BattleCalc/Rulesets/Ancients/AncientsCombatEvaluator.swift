//
//  AncientsCombatEvaluator.swift
//  BattleCalc
//
//  Draft Ancients evaluator used only by debug smoke tests for now. It resolves
//  basic dice from Ancients-owned CSV data and simple terrain effects. It is not
//  yet a complete gameplay ruleset.
//

import Foundation

struct AncientsCombatEvaluator {
    func evaluate(_ context: CombatContext) -> CombatResult {
        var reasons: [String] = []
        var notes: [String] = []
        var appliedRules: [AppliedRule] = []

        guard let attacker = AncientsUnitLibrary.unit(for: context.attackerUnitID) else {
            return blocked("Unknown Ancients attacker unit: \(context.attackerUnitID)")
        }

        guard let defender = AncientsUnitLibrary.unit(for: context.defenderUnitID) else {
            return blocked("Unknown Ancients defender unit: \(context.defenderUnitID)")
        }

        if attacker.unitClass == "leader" || defender.unitClass == "leader" {
            reasons.append("Leaders are not standalone combat units in this calculator. Use Leader support on the attached or adjacent unit instead.")
        }

        let targetDistance = context.targetDistance ?? (context.combatMode == .melee ? 1 : 0)
        if context.combatMode == .melee, targetDistance != 1 {
            reasons.append("Close Combat requires an adjacent target.")
        }
        if context.combatMode == .ranged, targetDistance <= 1 {
            reasons.append("Ranged combat requires a target more than 1 hex away.")
        }
        if context.combatMode == .ranged, targetDistance > attacker.range {
            reasons.append("Target is beyond this unit’s range.")
        }
        if context.combatMode == .ranged, attacker.range <= 0 {
            reasons.append("This unit does not have a Ranged Combat attack.")
        }
        if context.combatMode == .ranged,
           let movementBlockReason = rangedMovementBlockReason(for: attacker, movedHexes: context.movedHexes ?? 0) {
            reasons.append(movementBlockReason)
        }
        if context.combatMode == .melee,
           let movementBlockReason = closeCombatMovementBlockReason(for: attacker, movedHexes: context.movedHexes ?? 0) {
            reasons.append(movementBlockReason)
        }
        if let terrainBlockReason = terrainBattleBlockReason(for: context, attacker: attacker) {
            reasons.append(terrainBlockReason)
        }

        let validation = CombatValidation(isAllowed: reasons.isEmpty, reasons: reasons)
        guard validation.isAllowed else {
            return CombatResult(
                validation: validation,
                baseDice: nil,
                modifiers: [],
                modifierTotal: 0,
                finalDice: nil,
                notes: notes,
                appliedRules: appliedRules
            )
        }

        let baseDice: Int
        switch context.combatMode {
        case .melee:
            baseDice = meleeDice(
                for: attacker,
                currentBlocks: context.attackerBlocks,
                defender: defender,
                defenderBlocks: context.defenderBlocks,
                isBattleBack: context.isBattleBack
            )
            appliedRules.append(AppliedRule(
                ruleID: "ancients.base.melee",
                title: "Close Combat dice",
                outcome: meleeDiceExplanation(
                    for: attacker,
                    currentBlocks: context.attackerBlocks,
                    defender: defender,
                    defenderBlocks: context.defenderBlocks,
                    isBattleBack: context.isBattleBack,
                    result: baseDice
                )
            ))
        case .ranged:
            let movedHexes = context.movedHexes ?? 0
            baseDice = movedHexes > 0 ? attacker.moveFireDice : attacker.holdFireDice
            appliedRules.append(AppliedRule(
                ruleID: movedHexes > 0 ? "ancients.base.ranged.move" : "ancients.base.ranged.hold",
                title: "Ranged combat dice",
                outcome: movedHexes > 0
                    ? "\(attacker.name) moved this turn so get \(baseDice) ranged dice."
                    : "\(attacker.name) did NOT move this turn so get \(baseDice) ranged dice."
            ))
        }

        let finalDice = applyTerrainEffects(
            dice: baseDice,
            mode: context.combatMode,
            attackerTerrainID: context.attackerTerrainID,
            defenderTerrainID: context.defenderTerrainID,
            attacker: attacker,
            defender: defender,
            appliedRules: &appliedRules,
            notes: &notes
        )

        addEvadeGuidance(
            attacker: attacker,
            defender: defender,
            mode: context.combatMode,
            isBattleBack: context.isBattleBack,
            appliedRules: &appliedRules
        )

        addPostRollGuidance(
            attacker: attacker,
            defender: defender,
            mode: context.combatMode,
            attackerLeaderSupport: context.attackerLeaderSupport,
            defenderLeaderSupport: context.defenderLeaderSupport,
            defenderSupported: context.defenderSupported,
            isBattleBack: context.isBattleBack,
            appliedRules: &appliedRules
        )

        return CombatResult(
            validation: validation,
            baseDice: baseDice,
            modifiers: [],
            modifierTotal: 0,
            finalDice: finalDice,
            notes: notes,
            appliedRules: appliedRules
        )
    }

    private func rangedMovementBlockReason(for attacker: AncientsUnitDefinition, movedHexes: Int) -> String? {
        guard let maxMove = attacker.rangedMaxMove else { return nil }
        let moved = max(0, movedHexes)
        guard moved > maxMove else { return nil }

        if maxMove == 0 {
            return "No Ranged Combat: \(attacker.name) may not move and fire."
        }

        return "No Ranged Combat: \(attacker.name) may move up to \(maxMove) hex\(maxMove == 1 ? "" : "es") and still fire."
    }

    private func closeCombatMovementBlockReason(for attacker: AncientsUnitDefinition, movedHexes: Int) -> String? {
        guard let maxMove = attacker.closeCombatMaxMove else { return nil }
        let moved = max(0, movedHexes)
        guard moved > maxMove else { return nil }

        if maxMove == 0 {
            return "No Close Combat: \(attacker.name) may not move and Close Combat."
        }

        return "No Close Combat: \(attacker.name) may stay in position or move up to \(maxMove) hex\(maxMove == 1 ? "" : "es") before Close Combat."
    }

    private func terrainBattleBlockReason(for context: CombatContext, attacker: AncientsUnitDefinition) -> String? {
        let attackerTerrain = AncientsTerrainLibrary.terrain(for: context.attackerTerrainID)
        let defenderTerrain = AncientsTerrainLibrary.terrain(for: context.defenderTerrainID)
        let movedThisTurn = (context.movedHexes ?? 0) > 0

        if movedThisTurn, let reason = battleOnEntryBlockReason(attacker: attacker, attackerTerrain: attackerTerrain) {
            return reason
        }

        switch context.combatMode {
        case .melee:
            if defenderTerrain?.id == "fortified-city-wall" || attackerTerrain?.id == "fortified-city-wall" {
                return "No Close Combat is allowed with Fortified City Wall unless the scenario uses special siege or scalable wall rules."
            }
            if defenderTerrain?.id == "river" || attackerTerrain?.id == "river" {
                return "River is impassable terrain; Close Combat is not available in rivers."
            }
            if defenderTerrain?.id == "seacoast" || attackerTerrain?.id == "seacoast" {
                return "Seacoast is impassable terrain; Close Combat is not possible."
            }
        case .ranged:
            break
        }

        return nil
    }

    private func battleOnEntryBlockReason(attacker: AncientsUnitDefinition, attackerTerrain: AncientsTerrainDefinition?) -> String? {
        guard let attackerTerrain else { return nil }

        switch attackerTerrain.id {
        case "forest":
            if attacker.canBattleAfterEnteringForest { return nil }
            return "No battle: this unit may not battle on the turn it moves onto Forest. Only Light Infantry, Light Sling Infantry, Light Bow Infantry, Auxilia Infantry, and Warrior Infantry are allowed."
        case "broken-ground":
            if isMounted(attacker) {
                return "No battle: mounted units may NOT battle on the turn they enter Broken Ground."
            }
        default:
            break
        }

        return nil
    }

    private func isMounted(_ unit: AncientsUnitDefinition) -> Bool {
        ["cavalry", "chariot", "elephant"].contains(unit.unitClass)
    }

    private func meleeDice(
        for unit: AncientsUnitDefinition,
        currentBlocks: Int,
        defender: AncientsUnitDefinition,
        defenderBlocks: Int,
        isBattleBack: Bool
    ) -> Int {
        if unit.id == "elephant" {
            return elephantMeleeDice(against: defender, defenderBlocks: defenderBlocks)
        }
        if isBattleBack, let battleBackDiceOverride = unit.battleBackDiceOverride {
            return battleBackDiceOverride
        }

        return normalMeleeDice(for: unit, currentBlocks: currentBlocks)
    }

    private func normalMeleeDice(for unit: AncientsUnitDefinition, currentBlocks: Int) -> Int {
        let token = unit.meleeDice.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fixed = Int(token) { return fixed }

        let parts = token.split(separator: "-")
        if parts.count == 2,
           let damaged = Int(parts[0]),
           let fullStrength = Int(parts[1]) {
            return currentBlocks >= unit.maxBlocks ? fullStrength : damaged
        }

        // Tokens like "*" need special rules before they are player-ready.
        return 0
    }

    private func elephantMeleeDice(against defender: AncientsUnitDefinition, defenderBlocks: Int) -> Int {
        switch defender.id {
        case "elephant", "camel", "cataphract-camel", "warrior-infantry", "heavy-chariot":
            return 3
        case "leader":
            return 1
        default:
            return normalMeleeDiceWithoutFullStrengthBonus(for: defender)
        }
    }

    private func normalMeleeDiceWithoutFullStrengthBonus(for unit: AncientsUnitDefinition) -> Int {
        switch unit.id {
        case "warrior-infantry": return 3
        case "light-barbarian-chariot": return 2
        default:
            return normalMeleeDice(for: unit, currentBlocks: 0)
        }
    }

    private func meleeDiceExplanation(
        for unit: AncientsUnitDefinition,
        currentBlocks: Int,
        defender: AncientsUnitDefinition,
        defenderBlocks: Int,
        isBattleBack: Bool,
        result: Int
    ) -> String {
        if unit.id == "elephant" {
            return elephantMeleeDiceExplanation(against: defender, defenderBlocks: defenderBlocks, result: result)
        }
        if isBattleBack, let battleBackDiceOverride = unit.battleBackDiceOverride {
            return "\(unit.name) rolls \(battleBackDiceOverride) Close Combat dice when Battling Back."
        }

        let token = unit.meleeDice.trimmingCharacters(in: .whitespacesAndNewlines)
        if Int(token) != nil {
            return "\(unit.name) starts with \(result) Close Combat dice."
        }

        let parts = token.split(separator: "-")
        if parts.count == 2 {
            return "\(unit.name) uses \(token) Close Combat dice: \(result) dice at \(currentBlocks) block\(currentBlocks == 1 ? "" : "s")."
        }

        return "REVIEW: \(unit.name) has a special Close Combat token (\(token)) that still NEEDS RULE REVIEW HERE."
    }

    private func elephantMeleeDiceExplanation(
        against defender: AncientsUnitDefinition,
        defenderBlocks: Int,
        result: Int
    ) -> String {
        switch defender.id {
        case "elephant", "camel", "cataphract-camel", "warrior-infantry", "heavy-chariot":
            return "Elephant uses 3 Close Combat dice against \(defender.name). Elephants receive no Leader benefit."
        case "leader":
            return "Elephant uses 1 Close Combat die against a Leader. Elephants receive no Leader benefit."
        default:
            return "Elephant uses the defender’s normal Close Combat dice against \(defender.name), without full-strength bonus dice: \(result) dice. Elephants receive no Leader benefit."
        }
    }

    private func addEvadeGuidance(
        attacker: AncientsUnitDefinition,
        defender: AncientsUnitDefinition,
        mode: CombatMode,
        isBattleBack: Bool,
        appliedRules: inout [AppliedRule]
    ) {
        guard mode == .melee, !isBattleBack else { return }
        guard let reason = evadeEligibilityReason(defender: defender, attacker: attacker) else { return }

        let outcome: String
        if defender.unitClass == "artillery" {
            outcome = "Before dice are rolled, \(defender.name) may Evade. \(reason) If it survives, it evades and is removed from the battlefield; it is not a Victory Banner unless eliminated by the attack roll. The attacker may not Momentum Advance into the vacated hex."
        } else if defender.id == "leader" {
            outcome = "Before dice are rolled, a lone Leader must Evade if attacked. The attacker may not Momentum Advance after Close Combat against an unattached Leader."
        } else {
            outcome = "Before dice are rolled, \(defender.name) may Evade. \(reason) If it Evades, it may not Battle Back and the attacker may not Momentum Advance into the vacated hex."
        }

        appliedRules.append(AppliedRule(
            ruleID: "ancients.pre-roll.evade",
            title: "Evade reminder",
            outcome: outcome
        ))
    }

    private func evadeEligibilityReason(defender: AncientsUnitDefinition, attacker: AncientsUnitDefinition) -> String? {
        let alwaysEvadeIDs: Set<String> = [
            "light-infantry", "light-sling-infantry", "light-bow-infantry",
            "light-cavalry", "light-bow-cavalry", "light-chariot"
        ]
        if alwaysEvadeIDs.contains(defender.id) {
            return "Green-circle light units may always Evade."
        }
        if defender.unitClass == "artillery" {
            return "War Machine units may always Evade."
        }
        if defender.id == "leader" {
            return "A lone Leader must Evade."
        }

        let attackerIsFoot = attacker.unitClass == "infantry" || attacker.unitClass == "artillery"
        let attackerIsElephant = attacker.unitClass == "elephant"
        let heavyMountedIDs: Set<String> = ["heavy-cavalry", "cataphract-cavalry", "heavy-chariot"]
        let attackerIsHeavyMounted = heavyMountedIDs.contains(attacker.id) || attackerIsElephant
        let defenderIsMediumCavalryOrCamel = defender.id == "medium-cavalry" || defender.id == "camel" || defender.id == "cataphract-camel"
        let defenderIsHeavyCavalryOrChariot = defender.id == "heavy-cavalry" || defender.id == "cataphract-cavalry" || defender.id == "heavy-chariot"

        if defenderIsMediumCavalryOrCamel, attackerIsFoot || attackerIsHeavyMounted {
            return "Medium Cavalry and Camel units may Evade foot and heavy mounted units."
        }
        if defenderIsHeavyCavalryOrChariot, attackerIsFoot || attackerIsElephant {
            return "Heavy Cavalry and Heavy Chariot units may Evade foot and elephant units."
        }

        return nil
    }

    private func addPostRollGuidance(
        attacker: AncientsUnitDefinition,
        defender: AncientsUnitDefinition,
        mode: CombatMode,
        attackerLeaderSupport: CombatLeaderSupport,
        defenderLeaderSupport: CombatLeaderSupport,
        defenderSupported: Bool,
        isBattleBack: Bool,
        appliedRules: inout [AppliedRule]
    ) {
        var guidance: [String] = []
        var leaderGuidance: [String] = []

        // Use direction-specific post-roll reminders so the worksheet only shows
        // the special note that actually applies to this unit's current role in
        // the combat. Blank fields intentionally add nothing.
        if mode == .melee {
            if let attackerNote = attacker.postRollNoteWhenAttacking {
                guidance.append("Attacker — \(attacker.name): \(attackerNote)")
            }
            if let defenderNote = defender.postRollNoteWhenDefending {
                guidance.append("Defender — \(defender.name): \(defenderNote)")
            }
        }

        switch attackerLeaderSupport {
        case .none:
            break
        case .adjacent, .attached:
            if mode == .melee {
                if attacker.id == "elephant" {
                    leaderGuidance.append("Attacker: Elephants do not receive Close Combat benefits from leaders.")
                } else if !isBattleBack || attackerLeaderSupport == .attached {
                    leaderGuidance.append("Attacker: \(attackerLeaderSupport.title) lets helmet symbols score hits in Close Combat.")
                    if !isBattleBack, attackerLeaderSupport == .attached, attacker.unitClass == "infantry" {
                        leaderGuidance.append("Attacker: attached leader may allow this foot unit to make a bonus Close Combat after Momentum Advance (Take Ground).")
                    }
                }
            } else {
                leaderGuidance.append("Attacker: leaders do not affect Ranged Combat hit symbols.")
            }
        }

        switch defenderLeaderSupport {
        case .none, .adjacent:
            break
        case .attached:
            leaderGuidance.append("Defender: attached leader lets this unit ignore one flag.")
            if !isBattleBack, mode == .melee {
                if defender.id == "elephant" {
                    leaderGuidance.append("Defender: Elephants do not receive Close Combat benefits from leaders if they Battle Back.")
                } else {
                    leaderGuidance.append("Defender: attached leader can make helmet symbols score hits if this unit Battles Back.")
                }
            }
        }

        if !guidance.isEmpty {
            appliedRules.append(AppliedRule(
                ruleID: "ancients.post-roll.guidance",
                title: "After the dice are rolled",
                outcome: guidance.joined(separator: " ")
            ))
        }

        if defenderSupported {
            let outcome = defender.unitClass == "elephant"
                ? "Defender marked supported, but Elephants do not receive support. They still provide support to friendly units."
                : "Defender is supported and may ignore one flag."
            appliedRules.append(AppliedRule(
                ruleID: "ancients.post-roll.support",
                title: "Support reminder",
                outcome: outcome
            ))
        }

        if !leaderGuidance.isEmpty {
            let hasAttachedLeader = attackerLeaderSupport == .attached || defenderLeaderSupport == .attached
            appliedRules.append(AppliedRule(
                ruleID: hasAttachedLeader ? "ancients.post-roll.leader.attached" : "ancients.post-roll.leader",
                title: "Leader reminders",
                outcome: leaderGuidance.joined(separator: " ")
            ))
        }
    }

    private func applyTerrainEffects(
        dice: Int,
        mode: CombatMode,
        attackerTerrainID: String?,
        defenderTerrainID: String?,
        attacker: AncientsUnitDefinition,
        defender: AncientsUnitDefinition,
        appliedRules: inout [AppliedRule],
        notes: inout [String]
    ) -> Int {
        var finalDice = dice
        finalDice = applyHillCloseCombatCap(
            dice: finalDice,
            mode: mode,
            attackerTerrainID: attackerTerrainID,
            defenderTerrainID: defenderTerrainID,
            attacker: attacker,
            appliedRules: &appliedRules
        )
        finalDice = applyTerrainCap(
            dice: finalDice,
            mode: mode,
            terrainID: defenderTerrainID,
            relationship: .into,
            appliedRules: &appliedRules,
            notes: &notes
        )
        finalDice = applyTerrainCap(
            dice: finalDice,
            mode: mode,
            terrainID: attackerTerrainID,
            relationship: .out,
            appliedRules: &appliedRules,
            notes: &notes
        )
        finalDice = applyFortifiedCampPenalty(
            dice: finalDice,
            attackerTerrainID: attackerTerrainID,
            appliedRules: &appliedRules
        )
        explainFortifiedCampDefense(
            defenderTerrainID: defenderTerrainID,
            defender: defender,
            mode: mode,
            appliedRules: &appliedRules
        )
        explainRampartDefense(
            defenderTerrainID: defenderTerrainID,
            defender: defender,
            mode: mode,
            appliedRules: &appliedRules
        )
        return finalDice
    }

    private func applyHillCloseCombatCap(
        dice: Int,
        mode: CombatMode,
        attackerTerrainID: String?,
        defenderTerrainID: String?,
        attacker: AncientsUnitDefinition,
        appliedRules: inout [AppliedRule]
    ) -> Int {
        guard mode == .melee else { return dice }

        let attackerOnHill = attackerTerrainID == "hill"
        let defenderOnHill = defenderTerrainID == "hill"
        guard attackerOnHill || defenderOnHill else { return dice }

        let cap: Int
        let relationship: String
        if !attackerOnHill && defenderOnHill {
            cap = 2
            relationship = "attacking uphill INTO Hill"
        } else if attackerOnHill && !defenderOnHill {
            cap = isMounted(attacker) ? 2 : 3
            relationship = "attacking downhill OUT of Hill"
        } else {
            cap = isMounted(attacker) ? 2 : 3
            relationship = "Hill-to-Hill Close Combat"
        }

        let finalDice = min(dice, cap)
        let unitTypeText = isMounted(attacker) ? "mounted" : "foot"
        let outcome: String
        if finalDice != dice {
            outcome = "Hill terrain: \(relationship), so this \(unitTypeText) unit is limited to \(cap) dice."
        } else {
            outcome = "Hill terrain: \(relationship), which allows up to \(cap) dice for this \(unitTypeText) unit; this attack is already at \(dice) dice."
        }

        appliedRules.append(AppliedRule(
            ruleID: "ancients.terrain.hill.close-combat",
            title: "Hill Close Combat cap",
            outcome: outcome
        ))

        return finalDice
    }

    private enum TerrainRelationship {
        case into
        case out
    }

    private func applyTerrainCap(
        dice: Int,
        mode: CombatMode,
        terrainID: String?,
        relationship: TerrainRelationship,
        appliedRules: inout [AppliedRule],
        notes: inout [String]
    ) -> Int {
        guard let terrain = AncientsTerrainLibrary.terrain(for: terrainID) else {
            return dice
        }

        let rawCap: String?
        switch (mode, relationship) {
        case (.melee, .into):
            rawCap = terrain.meleeINTOMaxDice ?? terrain.meleeMaxDice
        case (.melee, .out):
            rawCap = terrain.meleeOutMaxDice ?? terrain.meleeMaxDice
        case (.ranged, .into):
            rawCap = terrain.rangedINTOMaxDice ?? terrain.rangedMaxDice
        case (.ranged, .out):
            rawCap = terrain.rangedOutMaxDice
        }

        guard let rawCap, !rawCap.isEmpty else {
            return dice
        }

        guard let cap = Int(rawCap) else {
            notes.append("\(terrain.name) has a non-numeric \(mode.rawValue) cap token: \(rawCap).")
            return dice
        }
        guard cap >= 0 else {
            return dice
        }

        let finalDice = min(dice, cap)
        let directionText: String
        switch relationship {
        case .into:
            directionText = "Attack is INTO \(terrain.name)"
        case .out:
            directionText = "Attack is OUT of \(terrain.name)"
        }

        let outcome: String
        if finalDice != dice {
            outcome = "\(directionText), so this \(mode.rawValue) attack is limited to \(cap) dice."
        } else {
            outcome = "\(directionText), which allows up to \(cap) dice here; this attack is already at \(dice) dice."
        }

        appliedRules.append(AppliedRule(
            ruleID: "ancients.terrain.cap.\(mode.rawValue).\(relationship)",
            title: "Terrain dice cap",
            outcome: outcome
        ))

        return finalDice
    }

    private func applyFortifiedCampPenalty(
        dice: Int,
        attackerTerrainID: String?,
        appliedRules: inout [AppliedRule]
    ) -> Int {
        guard attackerTerrainID == "fortified-camp" else { return dice }
        let finalDice = max(0, dice - 1)
        appliedRules.append(AppliedRule(
            ruleID: "ancients.terrain.fortified-camp.out",
            title: "Fortified Camp penalty",
            outcome: "A unit on a Fortified Camp hex rolls one fewer battle die than usual when it battles."
        ))
        return finalDice
    }

    private func explainFortifiedCampDefense(
        defenderTerrainID: String?,
        defender: AncientsUnitDefinition,
        mode: CombatMode,
        appliedRules: inout [AppliedRule]
    ) {
        guard defenderTerrainID == "fortified-camp" else { return }

        let outcome: String
        if isMounted(defender) {
            outcome = "Mounted units receive no protective benefit from Fortified Camp."
        } else {
            switch mode {
            case .melee:
                outcome = "A non-mounted defender on a Fortified Camp disregards one sword and may disregard one flag."
            case .ranged:
                outcome = "A non-mounted defender on a Fortified Camp may disregard one flag."
            }
        }

        appliedRules.append(AppliedRule(
            ruleID: "ancients.terrain.fortified-camp.defense",
            title: "Fortified Camp defense",
            outcome: outcome
        ))
    }

    private func explainRampartDefense(
        defenderTerrainID: String?,
        defender: AncientsUnitDefinition,
        mode: CombatMode,
        appliedRules: inout [AppliedRule]
    ) {
        guard defenderTerrainID == "rampart" else { return }

        let outcome: String
        if isMounted(defender) {
            outcome = "Mounted units receive no protective benefit from Rampart."
        } else {
            switch mode {
            case .melee:
                outcome = "If the attack crosses a protected Rampart hexside, the defender disregards one sword and may disregard one flag."
            case .ranged:
                outcome = "If the attack crosses a protected Rampart hexside, the defender may disregard one flag."
            }
        }

        appliedRules.append(AppliedRule(
            ruleID: "ancients.terrain.rampart.defense",
            title: "Rampart reminder",
            outcome: outcome
        ))
    }

    private func blocked(_ reason: String) -> CombatResult {
        CombatResult(
            validation: CombatValidation(isAllowed: false, reasons: [reason]),
            baseDice: nil,
            modifiers: [],
            modifierTotal: 0,
            finalDice: nil,
            notes: [],
            appliedRules: []
        )
    }
}
