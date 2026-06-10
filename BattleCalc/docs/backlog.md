# Backlog

## Unit image references

Status: Deferred

Each country-specific unit type should eventually support a visual reference image.

Why it matters:
- players may want to compare the on-screen image to the physical block,
- different countries may have visually distinct versions of similar unit types,
- and a thumbnail plus enlarged detail view would improve confidence during unit selection.

Possible future model fields:
- `thumbnailImageName`
- `detailImageName`
- `imageAltText`

Possible future UI behavior:
- show a small image beside the unit name,
- tap the image or row to open a larger reference view,
- and include the unit name and country in the expanded display.

## Visual polish helpers

Status: Deferred

The app will likely benefit from more presentation helpers over time.

Examples:
- color chips and badges for countries,
- more visual side summaries,
- and reusable row components for setup and selection screens.

## Saved battle review flow

Status: Planned

A dedicated saved-battle review and selection experience will likely be needed once persistence is in place.

This may include:
- listing saved battle setups,
- opening an existing setup for review or editing,
- and confirming that save/load behavior is stable before deeper combat logic is added.

## Documentation discipline

Status: Ongoing

One important process goal is to keep architecture and roadmap notes current as development continues.

Working rule:
- settled structural decisions go in `architecture.md`,
- near-term implementation plans go in `roadmap.md`,
- and ideas not ready for implementation stay in `backlog.md`.
