//
//  Color+BattleCalc.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import SwiftUI

// Central color definitions for BattleCalc.
// We keep the game-specific country colors here so the rest of the UI
// can ask for colors by meaning instead of repeating raw RGB values.
extension Color {
    
    // France
    static let battleCalcFrenchBlue = Color(
        red: 52 / 255,
        green: 96 / 255,
        blue: 201 / 255
    )
    
    // Britain
    static let battleCalcBritishRed = Color(
        red: 196 / 255,
        green: 34 / 255,
        blue: 44 / 255
    )
    
    // Portugal
    static let battleCalcPortugueseBrown = Color(
        red: 125 / 255,
        green: 92 / 255,
        blue: 58 / 255
    )
    
    // Spain
    static let battleCalcSpanishYellow = Color(
        red: 222 / 255,
        green: 181 / 255,
        blue: 37 / 255
    )
    
    // Prussia
    static let battleCalcPrussianGray = Color(
        red: 124 / 255,
        green: 124 / 255,
        blue: 128 / 255
    )
    
    // Austria
    static let battleCalcAustrianWhite = Color(
        red: 245 / 255,
        green: 245 / 255,
        blue: 240 / 255
    )
    
    // Russia
    static let battleCalcRussianGreen = Color(
        red: 68 / 255,
        green: 140 / 255,
        blue: 78 / 255
    )
}
