import Foundation

// Stores the setup information for one battle.
//
// France is always one fixed side in the current design,
// so the user only chooses the opposing coalition.
// We still store France in the model explicitly so the saved
// battle setup is complete and does not depend on UI assumptions.
struct BattleSetup: Identifiable, Codable {
    // Unique ID for persistence, lists, and future editing support.
    let id: UUID
    
    // Player-facing name for the battle setup.
    var battleName: String
    
    // Optional notes about the battle, scenario, or special setup details.
    var notes: String
    
    // Fixed French side for the current version of the app.
    // This is stored explicitly even though the UI does not ask for it.
    let frenchCountryID: String
    
    // Optional display name for the opposing side.
    // Example: "Allies", "Coalition", or "Anglo-Portuguese Army".
    var alliedDisplayName: String
    
    // One or more allied countries opposing France.
    // This supports coalition setups rather than forcing a single enemy country.
    var alliedCountryIDs: [String]
    
    // Creation timestamp for the saved setup.
    // Useful for future sorting, debugging, and file inspection.
    let createdAt: Date
    
    // Last-updated timestamp for the saved setup.
    // The store currently uses this to sort the newest setups first.
    var updatedAt: Date
    
    // Explicit initializer so the model is easy to create while the app is evolving.
    // Defaults are provided for values that are often implicit or optional.
    init(
        id: UUID = UUID(),
        battleName: String,
        notes: String = "",
        frenchCountryID: String = "france",
        alliedDisplayName: String = "",
        alliedCountryIDs: [String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.battleName = battleName
        self.notes = notes
        self.frenchCountryID = frenchCountryID
        self.alliedDisplayName = alliedDisplayName
        self.alliedCountryIDs = alliedCountryIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
