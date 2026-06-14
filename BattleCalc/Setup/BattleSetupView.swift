//
//  BattleSetupView.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import SwiftUI

struct BattleSetupView: View {
    @StateObject private var viewModel = BattleSetupViewModel()
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Battle") {
                    TextField("Battle name", text: $viewModel.battleName)

                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Opposing Side") {
                    TextField("Display name", text: $viewModel.alliedDisplayName)
                }

                Section("Allied Countries") {
                    ForEach(viewModel.availableAlliedCountries) { country in
                        Toggle(
                            isOn: alliedCountryBinding(for: country.id),
                            label: {
                                HStack {
                                    if let displayColor = countryDisplayColor(for: country) {
                                        Circle()
                                            .fill(displayColor)
                                            .frame(width: 14, height: 14)
                                            .overlay {
                                                Circle()
                                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                            }
                                    }

                                    Text(country.name)

                                    Spacer()

                                    Text(country.colorName.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        )
                    }
                }

                Section("Setup Summary") {
                    LabeledContent(
                        "Battle",
                        value: viewModel.battleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "—"
                            : viewModel.battleName
                    )

                    LabeledContent(
                        "Opposition",
                        value: alliedSummaryText()
                    )
                }

                Section {
                    Button("Save Battle Setup") {
                        saveBattleSetup()
                    }
                    .disabled(!viewModel.canSave)
                }

                if let saveMessage {
                    Section("Status") {
                        Text(saveMessage)
                    }
                }
            }
            .navigationTitle("Battle Setup")
        }
    }

    private func alliedCountryBinding(for countryID: String) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.isAlliedCountrySelected(countryID)
            },
            set: { isSelected in
                let isCurrentlySelected = viewModel.isAlliedCountrySelected(countryID)

                if isSelected != isCurrentlySelected {
                    viewModel.toggleAlliedCountry(countryID)
                }
            }
        )
    }

    private func alliedSummaryText() -> String {
        let trimmedDisplayName = viewModel.alliedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        let selectedNames = viewModel.availableAlliedCountries
            .filter { viewModel.selectedAlliedCountryIDs.contains($0.id) }
            .map(\.name)
            .sorted()

        let countriesText = selectedNames.isEmpty ? "None selected" : selectedNames.joined(separator: ", ")

        if trimmedDisplayName.isEmpty {
            return countriesText
        }

        return "\(trimmedDisplayName) - \(countriesText)"
    }

    private func saveBattleSetup() {
        do {
            try viewModel.save()
            saveMessage = "Battle setup saved."
        } catch {
            saveMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func countryDisplayColor(for country: CountryDefinition) -> Color? {
        switch country.id {
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
            return nil
        }
    }
}
