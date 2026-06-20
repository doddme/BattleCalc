//
//  ContentView.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("selectedGameSystem") private var selectedGameSystemRawValue = ""

    // Earlier entry points, kept for reference:
    //    BattleSetupView()
    //    NapoleonicsCombatDebugView()
    var body: some View {
        switch GameSystem(rawValue: selectedGameSystemRawValue) {
        case .napoleonics:
            CombatEntryView(onChangeGame: clearSelectedGame)
        case .ancients:
            AncientsCombatEntryView(onChangeGame: clearSelectedGame)
        case .none:
            GameSelectionView(selectedGameSystemRawValue: $selectedGameSystemRawValue)
        }
    }

    private func clearSelectedGame() {
        selectedGameSystemRawValue = ""
    }
}
