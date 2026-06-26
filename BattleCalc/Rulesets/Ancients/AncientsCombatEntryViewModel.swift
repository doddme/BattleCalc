//
//  AncientsCombatEntryViewModel.swift
//  BattleCalc
//
//  Draft view model for the Ancients combat entry path. Kept separate from the
//  Napoleonics CombatEntryViewModel so the existing game stays unchanged.
//

import Foundation
import Combine

@MainActor
final class AncientsCombatEntryViewModel: ObservableObject {
    private let evaluator = AncientsCombatEvaluator()

    @Published var attackerClass: CombatPickItem? { didSet { if attackerClass?.id != oldValue?.id { clearAttackerUnit() } } }
    @Published var attackerUnit: CombatPickItem? { didSet { if attackerUnit?.id != oldValue?.id { attackerUnitDidChange() } } }
    @Published var attackerBlocks: Int = 1 { didSet { recompute() } }
    @Published var attackerMovedHexes: Int? { didSet { recompute() } }
    @Published var attackerTerrain: CombatPickItem? { didSet { if attackerTerrain?.id != oldValue?.id { recompute() } } }
    @Published var attackerLeaderSupport: CombatLeaderSupport = .none { didSet { recompute() } }

    @Published var defenderClass: CombatPickItem? { didSet { if defenderClass?.id != oldValue?.id { clearDefenderUnit() } } }
    @Published var defenderUnit: CombatPickItem? { didSet { if defenderUnit?.id != oldValue?.id { defenderUnitDidChange() } } }
    @Published var defenderBlocks: Int = 1 { didSet { recompute() } }
    @Published var defenderTerrain: CombatPickItem? { didSet { if defenderTerrain?.id != oldValue?.id { recompute() } } }
    @Published var defenderLeaderSupport: CombatLeaderSupport = .none { didSet { recompute() } }
    @Published var defenderSupported: Bool = false { didSet { recompute() } }

    @Published var targetDistance: Int = 1 { didSet { recompute() } }
    @Published private(set) var result: CombatResult?

    @Published var defenderStayedInHex: Bool? { didSet { if defenderStayedInHex != oldValue { battleBackAnswerDidChange() } } }
    @Published private(set) var battleBackResult: CombatResult?

    var classOptions: [CombatPickItem] { AncientsCombatEntryCatalog.classes() }
    var attackerUnitOptions: [CombatPickItem] {
        guard let unitClass = attackerClass else { return [] }
        return AncientsCombatEntryCatalog.unitTypes(in: unitClass.id)
    }
    var defenderUnitOptions: [CombatPickItem] {
        guard let unitClass = defenderClass else { return [] }
        return AncientsCombatEntryCatalog.unitTypes(in: unitClass.id)
    }
    var terrainOptions: [CombatPickItem] { AncientsCombatEntryCatalog.terrains() }

    var attackerMaxBlocks: Int { attackerUnit.map { AncientsCombatEntryCatalog.maxBlocks(forUnit: $0.id) } ?? 4 }
    var defenderMaxBlocks: Int { defenderUnit.map { AncientsCombatEntryCatalog.maxBlocks(forUnit: $0.id) } ?? 4 }
    var maxMovedHexes: Int { 4 }

    var isMelee: Bool { targetDistance == 1 }
    var distanceHeadline: String {
        isMelee ? "Adjacent Close Combat" : "Ranged combat at \(targetDistance) hexes"
    }

    var attackerComplete: Bool { attackerUnit != nil && attackerMovedHexes != nil && attackerTerrain != nil }
    var attackDetailsComplete: Bool { attackerComplete }
    var defenderComplete: Bool { defenderUnit != nil && defenderTerrain != nil }

    var attackerSummaryDetail: String {
        var parts: [String] = []
        parts.append(blocksChip(attackerBlocks))
        if let moved = attackerMovedHexes {
            parts.append(moved > 0 ? "Moved \(moved) hex\(moved == 1 ? "" : "es")" : "Stationary")
        }
        if let terrain = attackerTerrain { parts.append(terrain.title) }
        if let leaderSummary = attackerLeaderSupport.summary { parts.append(leaderSummary) }
        return parts.joined(separator: " • ")
    }

    var attackSummaryDetail: String {
        "\(targetDistance) hex\(targetDistance == 1 ? "" : "es") • \(isMelee ? "Close Combat" : "Ranged")"
    }

    var defenderSummaryDetail: String {
        var parts: [String] = []
        parts.append(blocksChip(defenderBlocks))
        if let terrain = defenderTerrain { parts.append(terrain.title) }
        if let leaderSummary = defenderLeaderSupport.summary { parts.append(leaderSummary) }
        if defenderSupported { parts.append("Supported") }
        return parts.joined(separator: " • ")
    }

    var canEvaluate: Bool { buildContext() != nil }
    var showsBattleBackControls: Bool { isMelee && result?.validation.isAllowed == true }
    var canBattleBack: Bool { showsBattleBackControls && defenderStayedInHex == true }

    var momentumAdvanceGuidance: String {
        guard isMelee, let attackerUnit else { return "" }
        guard let unit = AncientsUnitLibrary.unit(for: attackerUnit.id) else { return "" }

        if unit.unitClass == "artillery" {
            return "No Momentum Advance: War Machine units may never make a Momentum Advance."
        }

        var parts: [String] = []
        parts.append("Successful Close Combat: attacker may Momentum Advance (Take Ground) into the vacated hex.")

        if unit.unitClass == "cavalry", !unit.id.contains("camel") {
            parts.append("Cavalry may move one additional hex after the initial Momentum Advance; camels, chariots, and elephants do not get this extra hex.")
        }

        if canMakeBonusCloseCombatAfterMomentumAdvance(unit) {
            parts.append("**This attacker MAY choose a BONUS CLOSE COMBAT after making the Momentum Advance (Take Ground).**")
        } else {
            parts.append("This attacker can NOT Bonus Close Combat after Momentum Advance.")
        }

        return parts.joined(separator: " ")
    }

    func buildContext() -> CombatContext? {
        guard
            let attackerUnit, let attackerMovedHexes, let attackerTerrain,
            let defenderUnit, let defenderTerrain
        else { return nil }

        return CombatContext(
            combatMode: isMelee ? .melee : .ranged,
            movedHexes: attackerMovedHexes,
            targetDistance: targetDistance,
            attackerCountryID: "generic",
            attackerUnitID: attackerUnit.id,
            attackerBlocks: attackerBlocks,
            attackerTerrainID: attackerTerrain.id,
            defenderCountryID: "generic",
            defenderUnitID: defenderUnit.id,
            defenderBlocks: defenderBlocks,
            defenderTerrainID: defenderTerrain.id,
            attackerLeaderSupport: attackerLeaderSupport,
            defenderLeaderSupport: defenderLeaderSupport,
            defenderSupported: defenderSupported,
            attackDirection: .flat
        )
    }

    func recompute() {
        battleBackResult = nil
        defenderStayedInHex = nil
        guard let context = buildContext() else {
            result = nil
            return
        }
        result = evaluator.evaluate(context)
    }

    func setDefenderStayedInHex(_ value: Bool) {
        defenderStayedInHex = value
    }

    func performBattleBack() {
        guard canBattleBack, let context = buildBattleBackContext() else { return }
        battleBackResult = evaluator.evaluate(context)
    }

    func buildBattleBackContext() -> CombatContext? {
        guard
            let attackerUnit, let attackerTerrain,
            let defenderUnit, let defenderTerrain
        else { return nil }

        return CombatContext(
            combatMode: .melee,
            movedHexes: 0,
            targetDistance: 1,
            attackerCountryID: "generic",
            attackerUnitID: defenderUnit.id,
            attackerBlocks: defenderBlocks,
            attackerTerrainID: defenderTerrain.id,
            defenderCountryID: "generic",
            defenderUnitID: attackerUnit.id,
            defenderBlocks: attackerBlocks,
            defenderTerrainID: attackerTerrain.id,
            attackerLeaderSupport: defenderLeaderSupport,
            defenderLeaderSupport: attackerLeaderSupport,
            attackDirection: .flat,
            isBattleBack: true
        )
    }

    func reset() {
        attackerClass = nil
        attackerUnit = nil
        attackerBlocks = 1
        attackerMovedHexes = nil
        attackerTerrain = nil
        attackerLeaderSupport = .none
        defenderClass = nil
        defenderUnit = nil
        defenderBlocks = 1
        defenderTerrain = nil
        defenderLeaderSupport = .none
        defenderSupported = false
        targetDistance = 1
        result = nil
        defenderStayedInHex = nil
        battleBackResult = nil
    }

    private func blocksChip(_ blocks: Int) -> String {
        "\(blocks) block\(blocks == 1 ? "" : "s")"
    }

    private func canMakeBonusCloseCombatAfterMomentumAdvance(_ unit: AncientsUnitDefinition) -> Bool {
        if unit.id == "warrior-infantry" { return true }
        if unit.unitClass == "infantry" {
            return attackerLeaderSupport == .attached
        }
        return ["cavalry", "chariot", "elephant"].contains(unit.unitClass)
    }

    private func battleBackAnswerDidChange() {
        battleBackResult = nil
    }

    private func clearAttackerUnit() {
        attackerUnit = nil
        attackerBlocks = 1
        attackerMovedHexes = nil
        attackerTerrain = nil
        attackerLeaderSupport = .none
        recompute()
    }

    private func attackerUnitDidChange() {
        attackerBlocks = attackerMaxBlocks
        attackerMovedHexes = nil
        attackerTerrain = nil
        attackerLeaderSupport = .none
        recompute()
    }

    private func clearDefenderUnit() {
        defenderUnit = nil
        defenderBlocks = 1
        defenderTerrain = nil
        defenderLeaderSupport = .none
        defenderSupported = false
        recompute()
    }

    private func defenderUnitDidChange() {
        defenderBlocks = defenderMaxBlocks
        defenderTerrain = nil
        defenderLeaderSupport = .none
        defenderSupported = false
        recompute()
    }
}
