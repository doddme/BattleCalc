import Foundation
import SwiftUI
import Combine

// View model for creating and saving a battle setup.
//
// The current app flow assumes France is always one fixed side.
// The user does not enter French-side data directly.
// Instead, the user names the battle, adds optional notes,
// and chooses the opposing coalition countries.
final class BattleSetupViewModel: ObservableObject {
    
    // MARK: - User-entered fields
    
    // Player-facing name for the battle setup.
    @Published var battleName: String = ""
    
    // Optional notes about scenario details, reminders, or house rules.
    @Published var notes: String = ""
    
    // Optional display name for the coalition side.
    // Example: "Allies", "Coalition", or "Anglo-Portuguese Army".
    @Published var alliedDisplayName: String = ""
    
    // Stores the selected allied countries by ID.
    // We keep IDs here instead of full model objects so selection state remains lightweight.
    @Published var selectedAlliedCountryIDs: [String] = []
    
    // MARK: - Fixed and available country data
    
    // France is fixed in the current version of the setup flow.
    // We keep it as data in the view model so save logic remains explicit and self-contained.
    let france: CountryDefinition
    
    // Available coalition countries that may oppose France.
    let availableAlliedCountries: [CountryDefinition]
    
    // MARK: - Initialization
    
    init() {
        // Fixed French side.
        self.france = CountryDefinition(
            id: "france",
            name: "France",
            colorName: "blue"
        )
        
        // Current set of countries that can appear on the opposing coalition side.
        self.availableAlliedCountries = [
            CountryDefinition(id: "britain", name: "Britain", colorName: "red"),
            CountryDefinition(id: "portugal", name: "Portugal", colorName: "brown"),
            CountryDefinition(id: "spain", name: "Spain", colorName: "yellow"),
            CountryDefinition(id: "prussia", name: "Prussia", colorName: "gray"),
            CountryDefinition(id: "austria", name: "Austria", colorName: "white"),
            CountryDefinition(id: "russia", name: "Russia", colorName: "green")
        ]
    }
    
    // MARK: - Validation
    
    // The battle can be saved only when the required fields are present.
    // For now, that means a non-empty battle name and at least one allied country.
    var canSave: Bool {
        !battleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedAlliedCountryIDs.isEmpty
    }
    
    // MARK: - Selection helpers
    
    // Returns true when the given allied country is currently selected.
    func isAlliedCountrySelected(_ countryID: String) -> Bool {
        selectedAlliedCountryIDs.contains(countryID)
    }
    
    // Toggles one allied country in or out of the coalition selection.
    func toggleAlliedCountry(_ countryID: String) {
        if let index = selectedAlliedCountryIDs.firstIndex(of: countryID) {
            selectedAlliedCountryIDs.remove(at: index)
        } else {
            selectedAlliedCountryIDs.append(countryID)
        }
    }
    
    // MARK: - Save
    
    // Builds a BattleSetup model from the current screen state and saves it.
    //
    // France is always stored as the fixed French side even though the UI
    // does not ask the user to enter it explicitly.
    func save() throws {
        let trimmedBattleName = battleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlliedDisplayName = alliedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedBattleName.isEmpty else {
            throw BattleSetupSaveError.missingBattleName
        }
        
        guard !selectedAlliedCountryIDs.isEmpty else {
            throw BattleSetupSaveError.noAlliedCountriesSelected
        }
        
        let now = Date()

        let setup = BattleSetup(
            battleName: trimmedBattleName,
            notes: trimmedNotes,
            frenchCountryID: france.id,
            alliedDisplayName: trimmedAlliedDisplayName,
            alliedCountryIDs: selectedAlliedCountryIDs.sorted(),
            createdAt: now,
            updatedAt: now
        )

        
        try BattleSetupStore.shared.save(setup)
    }
}
