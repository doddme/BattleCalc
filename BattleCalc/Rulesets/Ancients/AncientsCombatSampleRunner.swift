//
//  AncientsCombatSampleRunner.swift
//  BattleCalc
//
//  Debug smoke-test runner for the draft Ancients evaluator.
//

import Foundation

struct AncientsCombatSampleFailure: Identifiable, Hashable {
    var id: String { sample.id }
    let sample: AncientsCombatSample
    let result: CombatResult
    let messages: [String]
}

struct AncientsCombatSampleReport: Hashable {
    let total: Int
    let passed: Int
    let failures: [AncientsCombatSampleFailure]

    var failed: Int { failures.count }
}

enum AncientsCombatSampleRunner {
    static func runAll(using evaluator: AncientsCombatEvaluator = AncientsCombatEvaluator()) -> AncientsCombatSampleReport {
        var failures: [AncientsCombatSampleFailure] = []

        for sample in AncientsCombatSampleLibrary.all {
            let mode: CombatMode = sample.targetDistance == 1 ? .melee : .ranged
            let context = CombatContext(
                combatMode: mode,
                movedHexes: sample.movedHexes,
                targetDistance: sample.targetDistance,
                attackerCountryID: "generic",
                attackerUnitID: sample.attackerUnitID,
                attackerBlocks: sample.attackerBlocks,
                attackerTerrainID: sample.attackerTerrainID,
                defenderCountryID: "generic",
                defenderUnitID: sample.defenderUnitID,
                defenderBlocks: sample.defenderBlocks,
                defenderTerrainID: sample.defenderTerrainID,
                attackDirection: .flat
            )

            let result = evaluator.evaluate(context)
            var messages: [String] = []

            if result.validation.isAllowed != sample.expectedAllowed {
                messages.append("expected allowed=\(sample.expectedAllowed), got \(result.validation.isAllowed)")
            }

            if result.finalDice != sample.expectedFinalDice {
                messages.append("expected finalDice=\(sample.expectedFinalDice), got \(result.finalDice.map(String.init) ?? "nil")")
            }

            if !messages.isEmpty {
                failures.append(AncientsCombatSampleFailure(sample: sample, result: result, messages: messages))
            }
        }

        return AncientsCombatSampleReport(
            total: AncientsCombatSampleLibrary.all.count,
            passed: AncientsCombatSampleLibrary.all.count - failures.count,
            failures: failures
        )
    }
}
