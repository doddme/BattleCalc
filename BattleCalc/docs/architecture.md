# Architecture

## Project status

BattleCalc is currently in early architecture and UI foundation work.

The project is using SwiftUI and is being built in code.

## Design principles

- Prefer simple, explicit data structures over premature abstraction.
- Keep the model aligned with the real tabletop flow.
- Separate game data from UI presentation helpers.
- Capture visual display logic in extensions or helper types when practical.
- Favor forms and guided setup over free-form user entry when the game rules are structured.

## Battle setup model

The battle setup flow currently assumes a France-vs-Allies structure.

Key assumptions so far:
- France is a fixed side in the setup flow.
- The opposing side may include one or more allied countries.
- The user should be able to name each side for display purposes.
- Allied country selection should be handled through a multi-select UI, not plain text entry.

## Country model direction

Country definitions are intended to be lightweight model objects that describe country identity.

Current known responsibilities include:
- stable identifier,
- display name,
- color name,
- and UI display color mapping.

The stored model data should remain simple and serializable.

UI-specific display behavior such as mapping a country to a SwiftUI `Color` should live in extensions or presentation helpers.

## Unit model direction

Unit data will eventually need to be country-specific.

This means a generic unit class alone is not enough for the app's needs, because a French line unit and a British line unit may share gameplay category but still differ in display identity and reference art.

Expected responsibilities for unit definitions include:
- unit identifier,
- country association,
- display name,
- combat-related values,
- movement-related values,
- and later, image references for visual identification.

## Planned visual identification support

A future unit definition revision should support visual reference images.

The current working assumption is that each country-specific unit type may later include:
- a small thumbnail image,
- a larger detail image,
- and optional accessibility text or descriptive metadata.

This will support showing a small image near the unit name and allowing the player to expand the image for closer block comparison.

## Terrain and combat rules direction

Terrain and combat logic will be data-driven where practical.

Known direction so far:
- terrain and unit types should be stored per country where needed,
- combat calculations need to preserve formula and rounding behavior,
- range rules vary by unit type,
- and terrain effects may depend on attack direction and unit class.

## Persistence direction

Battle setups should be saveable and reloadable.

The app will need a persistence layer for storing created battle setups, and the UI will eventually need a saved-battles list for verifying that save and load behavior works correctly.

