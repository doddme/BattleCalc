# BattleCalc Multi-Game Architecture Handoff

BattleCalc should evolve from a single-ruleset combat helper into a multi-game platform that begins with an explicit game-selection step. The immediate target is to support both **Napoleonics** and **Ancients**, while preparing the architecture for future Richard Borg system games such as Memoir '44, Battle Cry, Red Alert, Samurai Battles, Medieval, Tricorne, Battle of Hoth, and related variants. The current BattleCalc workspace already contains a shared combat model in `CombatContext` and `CombatResult`, along with app-shell and setup files, so the next phase should build on that shared foundation rather than replacing it. [cite:35][cite:37][conversation_history:1]

## Purpose

The product goal is simple: help players determine the correct number of dice quickly during live play, without forcing them to stop and reconstruct multiple layers of rules, terrain limits, leader effects, support conditions, or unit-specific exceptions. [conversation_history:1] These games are fast and elegant when players can resolve combat confidently, but modifiers and special cases can create friction, confusion, and frustration. [conversation_history:1] The app should reduce that friction while staying faithful to each game's rules and avoiding the dangerous temptation to merge unlike systems into a single over-generalized model. [conversation_history:1]

## New entry screen

A new introduction screen should appear before the user enters any combat setup or rules interaction. That screen must require the user to choose the game they are playing, and that selection becomes the root context for everything that follows: unit lists, terrain options, combat modes, field labels, validation, rules text, special rules, smoke tests, and explanatory notes. [cite:37][conversation_history:1]

Recommended behavior:

- Show a list of supported games, initially `Napoleonics` and `Ancients`. [conversation_history:1]
- Store the last-selected game for convenience, but always provide a visible way to switch games. [conversation_history:1]
- Do not allow entry into a combat calculator flow until a game is selected. [conversation_history:1]
- Once a game is selected, every subsequent screen should be filtered by that game context. [conversation_history:1]

## Core architectural principle

The correct long-term direction is **shared shell, separate rulesets**. The shared shell can own navigation, reusable UI controls, result presentation, storage, persistence, and common view-model plumbing. Each game must then own its own data, validators, rules engine, special-rule interpretations, and game-specific UI sections where needed. [cite:37][conversation_history:1]

This boundary is critical because similar-looking concepts do not mean the same thing across games. `currentBlocks` is a clear example. In Napoleonics, remaining blocks can directly affect melee dice. In Ancients, most units roll fixed Close Combat dice regardless of losses, except for defined exceptions such as Warriors and Light Barbarian Chariots. [file:34][file:31][file:32] That means a single field may still exist in the shared UI, but its *meaning* must be interpreted by the selected game's ruleset rather than by generic combat code. [conversation_history:1]

## Recommended code split

Introduce a domain-level selector such as:

```swift
enum GameSystem: String, Codable, CaseIterable, Hashable {
    case napoleonics
    case ancients
}
```

Then define a ruleset abstraction. The exact shape can evolve, but the app should move toward a pattern like this:

```swift
protocol GameRuleSet {
    var system: GameSystem { get }
    var displayName: String { get }

    func validate(_ context: CombatContext) -> CombatValidation
    func resolveCombat(_ context: CombatContext) -> CombatResult

    func availableUnits() -> [UnitDefinition]
    func availableTerrains() -> [TerrainDefinition]
    func specialRules() -> [SpecialRuleDefinition]
    func combatSamples() -> [CombatSample]
}
```

This ensures that future games are registered as new rulesets instead of being inserted as nested `if` statements throughout the app. [conversation_history:1]

## Shared `CombatContext`, game-owned meaning

The current code already includes a shared `CombatContext` with combat mode, movement, distance, attacker and defender unit IDs, block counts, terrain IDs, and attack direction. [cite:37] That is a strong base. However, the resolver must stop assuming that all fields have universal semantics. [cite:37][conversation_history:1]

For example:

- In **Napoleonics**, `attackerBlocks` and `defenderBlocks` can directly influence combat dice. [conversation_history:1]
- In **Ancients**, those block counts usually affect survival, elimination, and a few unit exceptions, but they usually do **not** determine Close Combat dice rolled. [file:34][file:32]

Because of that, the active ruleset must always interpret the context. Shared fields are acceptable, but shared assumptions are not. [conversation_history:1]

## Recommended `CombatContext` evolution

Keep the shared base context because it already fits the app well, but extend it so game-specific resolvers can use additional state without polluting unrelated rules. [cite:37][conversation_history:1]

A good direction would be:

```swift
enum GameSystem: String, Codable, CaseIterable, Hashable {
    case napoleonics
    case ancients
}

struct CombatContext: Codable, Hashable {
    var gameSystem: GameSystem

    var combatMode: CombatMode
    var movedHexes: Int?
    var targetDistance: Int?

    var attackerCountryID: String
    var attackerUnitID: String
    var attackerBlocks: Int
    var attackerTerrainID: String?

    var defenderCountryID: String
    var defenderUnitID: String
    var defenderBlocks: Int
    var defenderTerrainID: String?

    var attackDirection: AttackDirection?

    // Game-optional state
    var attackerLeaderAttachedOrAdjacent: Bool?
    var defenderLeaderAttachedOrAdjacent: Bool?
    var attackerSupported: Bool?
    var defenderSupported: Bool?

    // Post-attack or game-specific state
    var defenderSurvivedInitialAttack: Bool?
    var defenderRetreatedFromInitialAttack: Bool?
    var defenderEvadedInitialAttack: Bool?

    // Optional flags for game-specific unit logic
    var attackerStartedFullStrength: Bool?
    var defenderStartedFullStrength: Bool?
}
```

The important principle is that these fields are shared *containers*, but only the selected ruleset decides which ones matter and how to interpret them. [conversation_history:1]

## UI split

The UI should be organized into three layers:

1. **Shared shell UI** — game picker, navigation, recent calculations, storage, result presentation.
2. **Shared combat controls** — unit picker, terrain picker, moved hexes, target range, attack direction, common toggles.
3. **Game-specific sections** — fields, labels, helper text, and post-resolution questions that only make sense for one game or are interpreted very differently. [conversation_history:1][cite:37]

Examples:

- `currentBlocks` can remain a shared field, but its helper text should differ per game. [cite:37][file:34]
- Ancients needs explicit post-Close-Combat handling for Battle Back based on survival and retreat status. [file:34][file:31]
- Napoleonics may continue to emphasize block-driven melee dice loss. [conversation_history:1]

The app should therefore avoid one monolithic combat form with one fixed vocabulary. Instead, it should render shared controls plus rule-set-specific sections and explanations. [conversation_history:1]

## Result-model evolution

The existing `CombatResult` model already supports validation, base dice, modifiers, final dice, notes, and applied rules. [cite:37] That should remain the shared result shell. However, for multi-game support, the result may need optional game-specific fields where they materially improve clarity.

A good immediate enhancement for Ancients is explicit Battle Back reporting:

```swift
struct CombatResult: Codable, Hashable {
    var validation: CombatValidation

    var baseDice: Int?
    var modifiers: [CombatModifier]
    var modifierTotal: Int
    var finalDice: Int?

    var defenderCanBattleBack: Bool?
    var defenderBattleBackBaseDice: Int?
    var defenderBattleBackFinalDice: Int?

    var notes: [String]
    var appliedRules: [AppliedRule]
}
```

This keeps the result model shared while allowing a ruleset like Ancients to expose a second meaningful outcome from Close Combat. [file:34][file:31][cite:37]

## Ancients-specific warning

Ancients is the clearest example of why this split matters. The rules summary states: “If a defending unit survived a CC attack and was not retreated out of its hex, it may Battle Back against the attacking unit.” [file:34] The FAQ reinforces the same condition in plain language: a unit can battle back only if it survives and does not retreat. [file:31]

That must drive both logic and UI:

- If the defender retreats after Close Combat, it cannot Battle Back. [file:34][file:31]
- If the defender is eliminated, it cannot Battle Back. [file:34]
- If the defender survives and remains in hex, it may Battle Back if otherwise eligible. [file:34][file:31]
- If the defender cannot retreat because its retreat path is blocked and instead loses blocks for failed retreat, it may still Battle Back if still present in the hex. [file:31]

This rule belongs in the Ancients ruleset, not in generic shared combat code. [file:34][conversation_history:1]

## Ancients rules that matter immediately

The first Ancients integration should assume the following unless a specific unit says otherwise:

- Most units use fixed Close Combat dice regardless of losses. [file:34][file:32]
- Block count mainly affects survival, elimination, and some special-case unit profiles. [file:34][file:32]
- Battle Back is allowed only if the defender survives and does not retreat. [file:34][file:31]
- Battle Back can use a different dice value from the initial attack for some units. [file:32][file:28]

Important unit cases already identified in this thread:

- **Warrior Infantry**: 4 dice at full strength, otherwise 3; if first hit occurs during the initial attack and the unit remains in place, it still Battle Backs with 4 because Battle Back is part of the same combat sequence. [file:34][file:31][file:32]
- **Light Barbarian Chariot**: 3 dice at full strength, otherwise 2, using similar combat-sequence reasoning. [file:34][file:32]
- **Camel / Cataphract Camel**: 3 dice attacking, 2 dice Battle Back. [file:32][file:28]
- **Heavy Chariot**: 4 dice attacking, 3 dice Battle Back. [file:32][file:28]
- **Elephant**: uses special opponent-based dice rules and Battle Backs with the attacker’s normal dice, not bonus dice. [file:34][file:32]

These examples alone justify separating `meleeAttackDice` and `meleeBattleBackDice` in the Ancients unit data. [file:32][file:28]

## Data ownership by game

Do not force every game into one global CSV schema unless every column truly means the same thing across every game. A safer long-term organization is:

- `Data/Napoleonics/...`
- `Data/Ancients/...`
- later `Data/Memoir44/...`, `Data/BattleCry/...`, and so on. [cite:37][conversation_history:1]

Within each game folder, keep files owned by that game, for example:

- `Units.csv`
- `Terrain.csv`
- `SpecialRules.csv`
- `CombatSamples.csv`
- optional scenario or faction maps where needed [cite:37][conversation_history:1]

The loader can be generic, but decoding types and semantics should be game-specific whenever the rule meaning is different. [conversation_history:1]

## Suggested Ancients unit schema

For Ancients specifically, do not depend on a single generic `meleeDice` column. The data should be explicit enough that the ruleset can resolve combat without reverse-engineering meaning from ambiguous numbers. [file:32][file:28][conversation_history:1]

A practical Ancients unit schema could include:

```text
id,name,class,blocks,move,range,fireHold,fireMove,
meleeAttackDice,meleeBattleBackDice,
retreatHexes,
canEvade,evadeProfile,
canMomentumAdvance,canBonusCloseCombat,
hitsOnSwords,
ignoreFlagIfSupported,
ignoreSwordInMelee,
meleeDiceProfile,
battleBackProfile,
specialRuleKey,
fullStrengthAttackDice,damagedAttackDice,
fullStrengthBattleBackDice,damagedBattleBackDice
```

Examples:

- Medium Infantry: attack 4, battle back 4, fixed profile. [file:32][file:28]
- Heavy Infantry: attack 5, battle back 5, fixed profile. [file:32][file:28]
- Warrior Infantry: combat profile depends on full strength. [file:31][file:32]
- Camel: attack 3, battle back 2. [file:32][file:28]
- Heavy Chariot: attack 4, battle back 3. [file:32][file:28]
- Elephant: custom attack and battle-back logic. [file:34][file:32]

## Suggested Ancients terrain schema

The same principle applies to terrain. The data should express combat limits and protections explicitly rather than assuming the same terrain semantics as Napoleonics. [file:34][file:28]

A practical Ancients terrain schema could include:

```text
id,name,blocksLOS,
mustStopOnEntry,
canBattleAfterEntry,
meleeIntoMaxDice,
meleeOutOfMaxDice,
rangedIntoMaxDice,
rangedOutOfMaxDice,
defenderIgnoreSwordInMelee,
defenderIgnoreFlagInMelee,
defenderIgnoreFlagInRanged,
occupantDiceModifier,
defenderFirstStrike,
mountedGetsProtection,
notesKey
```

Examples already established in this thread:

- Forest: stop on entry, many units cannot battle after entry, melee max 2, ranged into target max 1, blocks LOS. [file:34][file:28]
- Hill: uphill melee max 2, downhill or hill-to-hill cap depends on foot vs mounted, blocks LOS through hill. [file:34]
- Fortified Camp: defender may ignore sword and flag in melee, ignore flag in ranged, occupying unit rolls one fewer die, mounted gets no protection, blocks LOS. [file:34]
- Bridge: melee into/out of max 2, ranged out max 1, defending foot may ignore one flag. [file:34]
- Scalable City Wall: melee max 2, defender may ignore sword and flag, may battle first if not evading, blocks LOS. [file:34]

## About the special notation

There was earlier discussion about compact notations or code-like fields for unit behavior, such as encoded movement/combat permissions or abbreviated special rule markers. [conversation_history:1] If those compact codes are kept, they should not be treated as user-facing notation. They should be treated as **internal data tokens** that map to explicit rules in code and to readable help text in the UI. [conversation_history:1]

That means:

- The CSV may keep compact tokens if they make parsing easier. [conversation_history:1]
- The app must decode those tokens into human-readable rule explanations before presenting them to the user. [conversation_history:1]
- The resolver must not depend on mysterious one-off string parsing scattered across the codebase. [conversation_history:1]
- A raw token should never appear directly in the player-facing UI. [conversation_history:1]

## Suggested token system

A better pattern is to keep compact tokens but document them centrally and decode them immediately after loading. For example:

```text
canBattleAfterMove = always | never | onlyIfNoMove | moveAllowedButNoBattleAfter1 | moveAllowedButNoBattleAfter2 | chargeRequiredAfterMove2
battleBackProfile = standard | none | attackerNormalDice | custom
meleeDiceProfile = fixed | blocksSensitive | custom
specialRuleKey = none | warrior | elephant | camel | heavyChariot | lightBarbarianChariot
```

Then the code can interpret those cleanly:

- `moveAllowedButNoBattleAfter2` means the unit may move 2 hexes but may not battle after doing so.
- `chargeRequiredAfterMove2` means a 2-hex move is legal only when it proceeds into Close Combat.
- `battleBackProfile = attackerNormalDice` represents the elephant Battle Back rule in Ancients. [file:34][file:32]
- `meleeDiceProfile = blocksSensitive` captures exceptions like Warriors instead of making block sensitivity the app-wide default. [file:34][file:31][file:32]

If compact codes remain in the CSVs, they should be backed by a developer-facing decoder table in code or in a small markdown file. That makes them acceptable even if they are not ideal from a readability standpoint. [conversation_history:1]

## Suggested token guidance for Perplexity Computer

If the coding agent keeps data tokens, it should follow these rules:

1. Tokens are for machine readability, not player readability. [conversation_history:1]
2. Every token must have one documented meaning and one decoding path. [conversation_history:1]
3. Tokens should map to enums or structured types as early as possible after loading. [conversation_history:1]
4. UI text should come from decoded rule descriptions, not raw token strings. [conversation_history:1]
5. Game-specific tokens should stay inside the game module that owns them. [conversation_history:1]
6. Tokens should never be interpreted in generic shared code unless the semantics are truly shared across systems. [conversation_history:1]

A useful Swift direction would be:

```swift
enum MeleeDiceProfile {
    case fixed
    case blocksSensitive
    case custom
}

enum BattleBackProfile {
    case standard
    case none
    case attackerNormalDice
    case custom
}

enum MoveBattlePermission {
    case always
    case never
    case onlyIfNoMove
    case allowedAfterMove(Int)
    case moveAllowedButNoBattleAfter(Int)
    case chargeRequiredAfterMove(Int)
}
```

This keeps the data compact while moving behavior into readable typed code. [conversation_history:1]

## Folder structure

A good long-term file and type layout would look like this:

```text
BattleCalc/
  App/
  CoreCombat/
    CombatContext.swift
    CombatResult.swift
    GameSystem.swift
    GameRuleSet.swift
  Games/
    Napoleonics/
      NapoleonicsRuleSet.swift
      NapoleonicsCombatFormSection.swift
      NapoleonicsUnitDefinition.swift
      NapoleonicsTerrainDefinition.swift
    Ancients/
      AncientsRuleSet.swift
      AncientsCombatFormSection.swift
      AncientsUnitDefinition.swift
      AncientsTerrainDefinition.swift
  Data/
    Napoleonics/
      Units.csv
      Terrain.csv
      CombatSamples.csv
    Ancients/
      Units.csv
      Terrain.csv
      SpecialRules.csv
      CombatSamples.csv
```

This preserves a single app while making each game's boundaries obvious. [cite:37][conversation_history:1]

## Future games

Future Richard Borg games should be added as new rulesets rather than as more conditionals inside Napoleonics or Ancients code. [conversation_history:1] Planned future candidates mentioned in this thread include Memoir '44, Battle Cry, Red Alert, Samurai Battles, Medieval, Tricorne, and Battle of Hoth. [conversation_history:1]

The implementation principle should be:

- every game gets its own rule module
- every game gets its own unit and terrain data
- every game gets its own smoke tests
- only truly shared concepts belong in the common layer [conversation_history:1]

A registry can expose supported games:

```swift
struct GameCatalog {
    static let supported: [GameRuleSet] = [
        NapoleonicsRuleSet(),
        AncientsRuleSet()
    ]
}
```

## Guardrails

The project should optimize for fast gameplay support, but correctness matters more than surface consistency. [conversation_history:1] If two games use similar words but different underlying rules, it is better to show slightly different UI wording or separate controls than to force a misleading abstraction. [conversation_history:1]

Recommended guardrails:

- Shared UI is allowed only when the rule meaning is truly shared. [conversation_history:1]
- If a field means something materially different across games, rename it in UI or add game-specific explanatory text. [conversation_history:1]
- Game logic should live in game modules, not in view-level `if` chains whenever possible. [conversation_history:1]
- Every new game should ship with its own combat smoke tests before being made selectable from the introduction screen. [cite:37][conversation_history:1]
- Compact data codes are acceptable only if they are documented and decoded into typed rules immediately after loading. [conversation_history:1]

## Suggested implementation order

A safe implementation order would be:

1. Add `GameSystem` and a new game-selection introduction screen. [conversation_history:1]
2. Make the app shell hold the selected game as top-level state. [cite:37][conversation_history:1]
3. Introduce a `GameRuleSet` abstraction. [cite:37][conversation_history:1]
4. Split Napoleonics and Ancients into separate rule modules and per-game data folders. [cite:37][conversation_history:1]
5. Refactor the combat form into shared controls plus game-specific sections. [conversation_history:1]
6. Add a token-decoding layer if compact CSV notations are kept. [conversation_history:1]
7. Add per-game smoke tests and keep them passing before adding more titles. [cite:37][conversation_history:1]

## Immediate outcome

The immediate goal is not to implement every Borg-system title now. The immediate goal is to establish a strong boundary between the shared BattleCalc shell and game-owned rules so that Ancients and Napoleonics can both be correct today, and future games can be added without turning the code into a maze of conditionals or overly blended abstractions. [cite:37][conversation_history:1]
