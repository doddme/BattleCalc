//
//  BattleSetupSaveError.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

enum BattleSetupSaveError: LocalizedError {
    case missingBattleName
    case noAlliedCountriesSelected

    var errorDescription: String? {
        switch self {
        case .missingBattleName:
            return "Please enter a battle name."
        case .noAlliedCountriesSelected:
            return "Please select at least one allied country."
        }
    }
}
