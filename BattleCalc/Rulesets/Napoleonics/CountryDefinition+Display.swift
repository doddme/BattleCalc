//
//  CountryDefinition+Display.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import SwiftUI

// UI-focused helpers for displaying country information.
// This keeps presentation logic out of the raw model type.
extension CountryDefinition {
    
    // Returns the SwiftUI color that should represent this country in the app.
    // We map from stored data so the model stays Codable and lightweight.
    var displayColor: Color {
        switch id {
        case "france":
            return .battleCalcFrenchBlue
        case "britain":
            return .battleCalcBritishRed
        case "portugal":
            return .battleCalcPortugueseBrown
        case "spain":
            return .battleCalcSpanishYellow
        case "prussia":
            return .battleCalcPrussianGray
        case "austria":
            return .battleCalcAustrianWhite
        case "russia":
            return .battleCalcRussianGreen
        default:
            return .gray
        }
    }
}
