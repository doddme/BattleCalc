//
//  GameSystem.swift
//  BattleCalc
//
//  Identifies the selected ruleset at the app-shell level.
//

import Foundation

enum GameSystem: String, Codable, CaseIterable, Hashable, Identifiable {
    case napoleonics
    case ancients

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .napoleonics:
            return "Napoleonics"
        case .ancients:
            return "Ancients"
        }
    }

    var subtitle: String {
        switch self {
        case .napoleonics:
            return "Commands & Colors: Napoleonics"
        case .ancients:
            return "Commands & Colors: Ancients"
        }
    }

    var isSelectable: Bool {
        switch self {
        case .napoleonics, .ancients:
            return true
        }
    }
}
