# Roadmap

## Now

## Next session

- Open BattleCalc in Xcode and confirm the project builds without errors.
- Run the app in the simulator and walk through creating a new battle setup.
- Verify that saving a battle setup writes a JSON file to the BattleSetups folder.
- Add a simple screen or list to show all saved battle setups using BattleSetupStore.loadAll().
- Confirm that battle setups appear sorted by most recently updated.
- Review docs/architecture.md and adjust any parts that no longer match the code.
- Make a small change (for example, tweak battle name or notes handling) and commit again.
- iPhone-first dice animation with haptics and sound, then a simpler Apple Watch companion roller once the core app model is settled
- Rules for interactions For the Battle Which Side are you On?
= Once we know what side - Which Arm is the Activated Unit (Infantry, Cavalry, Artillery)
= Display a list of all the available units for that Arm of the service
= Once chosen the list collapses if unchoses the list expands
= Asking pertainent questions - Did the activated unit MOVE this turn, Did they move into the woods.  Is there a Combined Fire with Artillery, within range and has line of sight. 
= Ask more questions about range of the Artillery and number of blocks it has for calculating number of dice.
= Now Ask Terrain Pick Terrain you are on, and your Enemy unit is on
= What type of Unit is being attacked 
= Calculate the dice to Roll
- Optionally show the dice roll.






Current priorities:
- stabilize the core model structure,
- finish the battle setup flow,
- keep country definitions aligned with UI needs,
- and document decisions as they are made.

Concrete tasks in the current stage:
- complete and validate `BattleSetupView`,
- support the France vs. coalition setup model,
- centralize country color definitions,
- and keep project notes up to date.

## Next

Near-term implementation targets:
- create a saved battle setup list screen,
- verify save and load behavior,
- improve navigation between setup and saved content,
- and refine setup summaries and display formatting.

This stage should confirm that the app's basic flow works before deeper combat detail is added.

## After that

Once setup and persistence feel stable, the next major layer should include:
- unit definitions,
- terrain definitions,
- combat and range calculations,
- and country-specific rule handling.

At that point, the model should be strong enough to support real gameplay calculations instead of only battle setup.

## Later UI enhancements

Planned interface improvements include:
- richer country color presentation,
- unit rows with small reference images,
- tap-to-expand larger unit images,
- and more polished visual summaries.

## Longer-term direction

Longer-term goals may include:
- a more complete combat calculator workflow,
- better presentation of terrain and directional modifiers,
- improved review screens,
- and clearer visual identification of units and sides during play.

