//
//  BattleSetupStore.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

// Handles saving, loading, listing, and deleting BattleSetup files.
// Version 1 uses simple JSON files in the app's Documents directory.
// This keeps persistence understandable and easy to inspect later.
final class BattleSetupStore {
    
    // Shared store used by the current app flow.
    // This allows screens and view models to access one common persistence store.
    static let shared = BattleSetupStore()
    
    // Prevents accidental creation of multiple store instances.
    // For now, the app uses the shared store above.
    private init() {}
    
    // Shared JSON encoder used for writing battle setups to disk.
    // Pretty-printed output makes the saved files easier to inspect
    // during development and debugging.
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    // Shared JSON decoder used for restoring battle setups from disk.
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // Root folder where all battle setup JSON files will live.
    // We keep them inside a dedicated subfolder so the app's document storage
    // does not become cluttered as more features are added later.
    private var battleSetupsDirectoryURL: URL {
        URL.documentsDirectory.appendingPathComponent("BattleSetups", isDirectory: true)
    }
    
    // Ensures the BattleSetups folder exists before any read or write operation.
    private func ensureBattleSetupsDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: battleSetupsDirectoryURL,
            withIntermediateDirectories: true
        )
    }
    
    // Builds a stable filename for one battle setup.
    // We use the UUID as the actual filename so renaming a battle
    // does not break the saved file path.
    private func fileURL(for battleSetup: BattleSetup) -> URL {
        battleSetupsDirectoryURL
            .appendingPathComponent(battleSetup.id.uuidString)
            .appendingPathExtension("json")
    }
    
    // Saves a battle setup to disk.
    // If the file already exists, it is replaced with the new content.
    func save(_ battleSetup: BattleSetup) throws {
        try ensureBattleSetupsDirectoryExists()
        
        let data = try encoder.encode(battleSetup)
        try data.write(to: fileURL(for: battleSetup), options: .atomic)
    }
    
    // Loads a single battle setup from its file URL.
    func load(from url: URL) throws -> BattleSetup {
        let data = try Data(contentsOf: url)
        return try decoder.decode(BattleSetup.self, from: data)
    }
    
    // Returns all saved battle setups found in the BattleSetups folder.
    // If the folder does not exist yet, we return an empty array.
    func loadAll() throws -> [BattleSetup] {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: battleSetupsDirectoryURL.path()) else {
            return []
        }
        
        let fileURLs = try fileManager.contentsOfDirectory(
            at: battleSetupsDirectoryURL,
            includingPropertiesForKeys: nil
        )
        
        let jsonFiles = fileURLs.filter { $0.pathExtension.lowercased() == "json" }
        
        let battleSetups = try jsonFiles.map { try load(from: $0) }
        
        // Newest updated battles first is a useful default for the UI.
        return battleSetups.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    // Deletes one saved battle setup from disk.
    func delete(_ battleSetup: BattleSetup) throws {
        let url = fileURL(for: battleSetup)
        
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
