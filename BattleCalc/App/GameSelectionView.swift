//
//  GameSelectionView.swift
//  BattleCalc
//
//  First-run game picker. The selected game controls which ruleset flow opens.
//

import SwiftUI

struct GameSelectionView: View {
    @Binding var selectedGameSystemRawValue: String
    #if DEBUG
    @State private var showNapoleonicsDataDebug = false
    @State private var showAncientsDataDebug = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(GameSystem.allCases) { gameSystem in
                        Button {
                            guard gameSystem.isSelectable else { return }
                            selectedGameSystemRawValue = gameSystem.rawValue
                        } label: {
                            GameSelectionRow(gameSystem: gameSystem)
                        }
                        .buttonStyle(.plain)
                        .disabled(!gameSystem.isSelectable)
                    }
                } header: {
                    Text("Choose Game")
                } footer: {
                    Text("BattleCalc uses the selected game to choose the right units, terrain, rules, and explanations.")
                }
            }
            .navigationTitle("BattleCalc")
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Napoleonics Data") { showNapoleonicsDataDebug = true }
                        Button("Ancients Data") { showAncientsDataDebug = true }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showNapoleonicsDataDebug) {
                NapoleonicsDataDebugView()
            }
            .sheet(isPresented: $showAncientsDataDebug) {
                AncientsDataDebugView()
            }
            #endif
        }
    }
}

private struct GameSelectionRow: View {
    let gameSystem: GameSystem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gameSystem.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(gameSystem.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if gameSystem.isSelectable {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Coming Soon")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
