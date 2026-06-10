//
//  README.md
//  BattleCalc
//
//  Created by Mike Dodd on 6/9/26.
//

# BattleCalc

BattleCalc is an iOS app for helping players calculate combat in a Napoleonic-style block wargame.

The app is being designed to reduce table friction by making it easier to:
- choose the battle setup,
- identify the units involved,
- apply terrain and range effects,
- calculate dice correctly,
- and preserve game-specific rules without forcing players to memorize every case.

## Current direction

The current design direction is centered on a SwiftUI app built in code rather than Interface Builder.

At this stage, the project is still establishing:
- the core data model,
- the setup flow for a battle,
- country-specific unit and terrain definitions,
- and the basic screen structure for creating and saving battle setups.

## Core ideas captured so far

- France is treated as one fixed side in the battle setup flow.
- The opposing side can be a coalition made up of one or more allied countries.
- Country definitions include identity information such as name and display color.
- The battle setup UI is intended to use form-driven SwiftUI screens.
- Country colors should be represented visually in the interface, not only as text.
- Unit definitions will eventually need visual reference images for block identification.

## Documentation structure

This repository includes lightweight working documentation to preserve decisions as the project evolves:
- `docs/architecture.md` for settled structural decisions,
- `docs/roadmap.md` for planned implementation stages,
- `docs/backlog.md` for future ideas and deferred features.

## Current phase

The app is still in the foundation phase.

That means current work is focused more on data structures, naming, setup flow, and UI direction than on polishing the final combat engine or visual design.
