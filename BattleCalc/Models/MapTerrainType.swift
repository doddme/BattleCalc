//
//  MapTerrainType.swift
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

import Foundation

// Reference data for one terrain type that can appear in a battle setup.
// We keep each terrain type distinct so the app can handle special cases later,
// but we also include a group identifier so terrains with similar behavior
// can still be treated together when that makes the rules easier to manage.
struct MapTerrainType: Codable, Identifiable, Hashable {
    // Stable internal identifier used throughout the app.
    // Examples: "woods", "hill", "town", "bridge", "fordable_stream".
    let id: String

    // User-facing terrain name shown in setup screens and pickers.
    let name: String

    // Logical grouping for terrains that share similar combat or movement behavior.
    // Examples: "rough", "water_crossing", "elevated", "built_up".
    let groupID: String

    // Optional notes give us a place to record scenario-specific reminders
    // or future rules details without changing the basic structure.
    let notes: [String]
}

