//
//  CountryDefinition.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

// Defines one country that can appear in battle setup and later in unit data.
//
// This model stores lightweight identity and display-oriented information.
// It is intentionally simple so it can be reused in setup, summaries,
// persistence, and later unit-definition relationships.
struct CountryDefinition: Identifiable, Codable {
    // Stable identifier used for persistence and internal lookups.
    let id: String
    
    // Player-facing country name.
    let name: String
    
    // Stored color name for lightweight serialization.
    // UI code can map this to a SwiftUI Color when needed.
    let colorName: String
    
    // Optional notes for future expansion.
    // This allows country-specific reminders or metadata without forcing
    // every current initializer call to supply a value.
    let notes: String
    
    // Explicit initializer with a default notes value.
    // This keeps current call sites simple while allowing the model to grow.
    init(
        id: String,
        name: String,
        colorName: String,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.notes = notes
    }
}
