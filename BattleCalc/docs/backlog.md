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


## Napoleonics Combat Evaluator

### Add saber capability to unit definitions

- Add `hasSabers: Bool` to the infantry combat profile or equivalent unit combat definition.
- Default this to `true` for most units.
- Set it to `false` for the known exceptions, currently Militia, Austrian Grenzers, and British Rifles.
- Keep this as a unit capability flag, not an evaluator hard-code, so the evaluator reads the unit definition instead of checking unit names directly.

### Add saber interpretation rules to combat evaluation

- Add evaluator logic that explains when saber results count and when they are ignored.
- This is a hit-interpretation rule, not a dice-count modifier, so it should usually be recorded in `appliedRules` rather than in numeric modifiers.
- For melee combat, sabers count normally when `hasSabers == true`.
- For melee combat, sabers are ignored when `hasSabers == false`.
- For ranged combat, sabers are ignored for all normal ranged attacks.
- Because the evaluator already treats `targetDistance == 1` as melee and only allows ranged combat when `targetDistance > 1`, no extra short-range saber exception is needed inside ranged mode.
- Add player-facing text such as:
  - `Sabers count normally.`
  - `Sabers are ignored in ranged combat.`
  - `Militia do not count saber hits.`

### Preserve future combined attack exception

- Keep room in the saber-rule helper for the one known exception: combined attack between infantry and supporting artillery.
- Normal ranged rule should remain `sabers ignored`, with combined attack handled as a later explicit override.
- Do not hard-code the combined attack logic yet, but design the helper so the exception can be inserted cleanly.

### Expand Special Case Rules section

- Continue using the evaluator-level `Special Case Rules` section as the home for one-off combat exceptions.
- This section should eventually cover:
  - hill-to-hill infantry handling,
  - square-related exceptions,
  - combined arms / combined attack rules,
  - saber interpretation exceptions,
  - other Napoleonics-specific edge cases.
- Follow the pattern `special case first, normal rules second` so standard terrain and dice rules remain readable.

### Add battle back as a follow-on melee step

- Add battle back support to melee resolution.
- Sequence should be:
  1. Resolve the initial melee attack.
  2. Apply the rolled results externally, including block loss and any retreat flag.
  3. If the defender survives and does not retreat, the defender may battle back in melee.
  4. Battle back uses the defender’s remaining blocks and reverses the attacker/defender roles.
  5. Terrain does not change during battle back.
- This should not be treated as a simple modifier on the original `CombatResult`; it is a second combat step.
- Most likely implementation options:
  - a wrapper result such as `CombatSequenceResult` with `initialAttack` and optional `battleBack`, or
  - a higher-level melee-sequence evaluator that calls the existing single-pass melee evaluator twice.
- Keep the current single-pass melee evaluator reusable as the engine for both the initial attack and battle back.

### Add future tests / regression coverage

- Add regression tests for hill-to-hill melee and hill-to-hill ranged fire.
- Add regression tests for units with `hasSabers == false`.
- Add regression tests confirming sabers are ignored in all normal ranged combat.
- Add regression tests later for combined attack saber handling.
- Add regression tests for battle back:
  - defender eliminated, no battle back;
  - defender retreats, no battle back;
  - defender survives in place, battle back occurs using remaining blocks.
