# BattleCalc Combat Entry Workflow Requirements

## Purpose

This document defines requirements and technical design options for a reusable combat-entry workflow in BattleCalc. The goal is to create a compact, Apple-aligned, SwiftUI-friendly interface that works well on iPhone and iPad, supports repeated in-place editing, and can be reused across game systems such as Napoleonics and Ancients. [memory:110][memory:113]

The immediate target is to implement the new workflow first in Ancients, prove the interaction model there, and then migrate Napoleonics onto the shared framework once the behavior feels correct. This reduces risk compared with patching Napoleonics and Ancients separately or attempting a universal form rewrite too early. [memory:116][cite:59][cite:60]

## Product model

BattleCalc should be treated as a reusable combat worksheet rather than a one-time form. Users frequently set up attacker and defender information, inspect the dice outcome, then adjust distance, target, terrain, or unit details and immediately compare a revised result without starting over. [conversation_history:1]

This means the design must optimize for iterative edits, stable summaries, compact rescanning, and partial downstream recomputation rather than forcing a strict start-to-finish wizard. [conversation_history:1][memory:116]

## Core goals

- One-page workflow on iPhone whenever practical. [memory:110]
- Compact collapsed summaries after entry. [memory:113]
- Tap-to-reopen editing for any completed section. [memory:113]
- Clear result visibility with optional expandable rule detail. [memory:114][memory:115]
- Reusable interaction behavior across rulesets. [memory:110]
- iPad adaptation without a separate mental model. [web:97]

## Observed usage patterns

Users do not simply enter one combat and move on. They map out attacker and defender, inspect the dice count, change distance from ranged to melee and back, change target, change terrain, and often reuse the same matchup on the next turn by editing what is already there instead of starting over. [conversation_history:1]

This requires a stateful worksheet that preserves as much valid information as possible when a single variable changes. [conversation_history:1]

## Current-state review

### Napoleonics

Napoleonics already uses progressive disclosure more effectively than Ancients. Attacker and defender sections collapse into summary rows, distance is shown between the two sides as a banner, and rare branches like Combined Attack are conditionally revealed. [cite:60][cite:93][cite:94]

However, some collapse behavior is tied to specific field closures, especially terrain selection, instead of to a generalized section-complete rule. This can make the interface feel clumsy when editing existing entries. [cite:94]

### Ancients

Ancients currently uses local editing state and some summary collapse behavior, but the flow is less unified. It separates Attacker, Attack, and Defender, with distance living in a separate Attack section. [cite:59][cite:76]

That appears to be an implementation artifact rather than a hard gameplay requirement. Distance should remain visually central, but Ancients does not need to preserve a permanently separate Attack section if the same visibility is achieved more cleanly through the shared workflow. [cite:76][cite:93]

## Design principles

The interface should stay close to Apple platform direction by favoring standard SwiftUI structures such as `List`, `Section`, `Button`, `LabeledContent`, SF Symbols, and grouped-list spacing. This makes the UI easier to maintain, more familiar on iPhone and iPad, and less likely to drift into a fragile custom design system. [web:95][web:97][web:99]

The interaction model should follow progressive disclosure: show only the controls needed now, collapse completed sections into useful summaries, and let users reopen sections in place for comparison and reuse. [web:61][page:1][web:85][web:90]

## Functional requirements

1. The screen must support repeated in-place edits without requiring a full reset after each calculation. [conversation_history:1]
2. Completed sections must collapse into summary form and reopen when tapped. [memory:113]
3. The workflow must support ruleset-specific conditional sections such as Combined Attack, Momentum Advance, Bonus Battle, Battle Back, retreat guidance, and special reminders. [cite:60][cite:76]
4. Editing one section must preserve as much valid downstream state as possible while invalidating or recomputing only what is affected. [conversation_history:1]
5. The app must include a Reset Combat action distinct from Change Game. [memory:111][conversation_history:1]
6. Result detail must be expandable while the default result presentation remains compact. [memory:114][memory:115]

## UX requirements

1. The iPhone experience should remain compact and worksheet-like, with temporary vertical growth during editing and automatic shrinking after collapse. [memory:110]
2. One major section should be expanded at a time by default on iPhone, unless a specific branch requires otherwise. [web:85][web:90]
3. Distance/range must remain visually prominent between attacker and defender. [cite:93]
4. Summary rows must prioritize scan speed over exhaustiveness. [memory:110][web:90]
5. iPad should preserve the same workflow model while taking advantage of extra width for richer summaries and clearer explanatory content. [web:97]


## Section categories

The shared workflow should support multiple section categories:

- **Side sections**: attacker, defender, support unit.
- **Context sections**: distance/range or other middle-of-combat context.
- **Conditional branch sections**: Combined Attack, Momentum Advance, Bonus Battle, Battle Back.
- **Result and explanation sections**: compact result plus optional expanded rules detail.

This categorization should guide reuse of the shared UI shell and workflow coordinator without forcing all sections to behave identically. [cite:60][cite:76]

## Section-switch behavior and guardrails

On iPhone, the workflow should prefer one major section open at a time. When the user opens a different major section, the previously open section may collapse automatically if it is complete enough to summarize. [conversation_history:1]

Automatic collapse should occur only when a section has reached a stable summary state, meaning the user-entered information is sufficient to produce a clear collapsed summary row. Incomplete sections should not be silently collapsed into unclear or invalid summaries. [conversation_history:1]

Reopening and editing an earlier section should be treated as a primary workflow, not an exception. The interface should preserve unaffected later inputs whenever possible and invalidate only the dependent values that truly need recalculation. [conversation_history:1][memory:116]

Expansion and collapse behavior should be managed by section-level state transitions in the workflow coordinator rather than being hardcoded inside individual field-selection callbacks. This avoids brittle behavior such as requiring the user to reselect a final field to force a section to collapse. [cite:94]


## Recommended architecture

The recommended architecture is a shared collapsible section shell plus a lightweight workflow coordinator. This is the safest reusable approach because it centralizes interaction behavior without swallowing rules logic into a generic engine. [memory:110][cite:60]

### Layer 1: Shared section shell

A reusable SwiftUI container, such as `CombatEntrySectionShell`, should own:
- expanded/collapsed presentation,
- section title rendering,
- collapsed summary container,
- reopen affordance,
- optional Done button,
- shared Apple-style visual polish.

It must not own rules, validation, or evaluator logic. [cite:59][cite:60]

### Layer 2: Workflow coordinator

A lightweight coordinator, such as `CombatEntryWorkflowCoordinator`, should own:
- section visibility,
- section completeness,
- section expansion state,
- one-open-section behavior,
- downstream invalidation/recompute rules,
- conditional section activation.

It must not own combat rules or summary wording. [conversation_history:1][memory:116]

### Layer 3: Ruleset ownership

Each ruleset screen and view model should continue to own:
- field list and order,
- labels,
- summary wording,
- rules validation,
- evaluator inputs,
- which optional sections appear and when. [cite:59][cite:60][cite:76]



## Shared UI pieces

### `CombatEntrySectionShell`

Responsibilities:
- render title and body,
- switch between summary and editor modes,
- handle tap-to-open,
- support explicit Done where needed,
- apply consistent grouped-list polish.

### `CombatEntrySummaryRowStyle`

Responsibilities:
- spacing,
- typography,
- chips/badges if used,
- chevron behavior,
- tint and accessory styling,
- consistent summary density across games.

### `CombatContextBanner`

Responsibilities:
- show cross-cutting combat facts such as distance/mode,
- remain visually prominent between sides,
- support edit/reopen if needed,
- prevent critical context like melee vs ranged from being buried. [cite:93]

## Section state model

Each section should have a lightweight state model, for example:
- `isVisible`
- `isExpanded`
- `isComplete`
- `isStale`
- `supportsDoneButton`

This state is UI/workflow state only. It should not contain rules. [conversation_history:1]

## Dependency and invalidation rules

The new workflow must define what happens when a section changes after later sections are already filled out.

Examples:
- Changing distance from ranged to melee should preserve attacker and defender identity but recompute result and show or hide follow-up sections like Battle Back or Momentum Advance. [cite:93][conversation_history:1]
- Changing attacker terrain should usually preserve defender identity but refresh result and terrain-dependent notes. [conversation_history:1]
- Changing attacker unit type may invalidate support-unit or follow-up sections that are no longer legal. [cite:60]
- Changing defender target should preserve attacker data but refresh result and defender follow-up content. [conversation_history:1]

The goal is to avoid destructive resets while still keeping the worksheet logically correct. [conversation_history:1][memory:116]

## Ancients first implementation

Ancients should be the first ruleset migrated to the shared workflow.

### Proposed visible layout

1. Attacker section
2. Distance banner
3. Defender section
4. Result
5. Conditional follow-up sections: Battle Back, Momentum Advance, Bonus Close Combat, retreat effects, and special reminders. [cite:76][cite:57]

### Key implementation decisions

- Distance may be edited as part of attacker completion or as a lightweight context edit, but its displayed state should remain visually centered between sides. [cite:76][cite:93]
- The current separate Attack section is not required if the same visibility can be achieved more cleanly. [cite:76]
- Section collapse should be driven by completeness or Done, not by isolated field events like terrain reselection. [cite:94]

## Napoleonics migration target

After Ancients proves the pattern, Napoleonics should migrate to the same workflow.

### Target sections

- Attacker
- Distance banner
- Defender
- Combined Attack
- Result
- Conditional follow-up sections including future Momentum Advance / Bonus Battle if they become interactive worksheet steps. [cite:60][cite:94]

### Cleanup goals

- Replace field-triggered collapse with section-level completion. [cite:94]
- Preserve the center distance banner. [cite:93]
- Keep Combined Attack as a conditional branch that may itself contain one or more collapsible subsections. [cite:94]

## Summary content guidance

Collapsed summaries should be concise and tuned for scan speed.

### Attacker summary
- country if relevant,
- unit type,
- blocks,
- moved status,
- terrain,
- one high-value special fact such as leader or support. [cite:59][cite:60]

### Defender summary
- country if relevant,
- unit type,
- blocks,
- terrain,
- one important modifier such as support or leader status. [cite:59][cite:60][cite:76]

### Distance banner
- clear icon,
- melee vs ranged wording,
- current number of hexes. [cite:93]

## Reset and reuse

The workflow needs both:
- **Reset Combat**: clear the current worksheet.
- **Change Game**: leave the current ruleset. [memory:111]

These should remain in the More menu so the main UI stays uncluttered. [memory:111]

## iPhone and iPad

### iPhone
- one expanded section at a time,
- compact summaries,
- central distance visibility,
- short plain-English rule explanations. [web:95][web:97]

### iPad
- same workflow order,
- same section semantics,
- more room for summary richness and explanation,
- no separate product model. [web:97]

## Risks to avoid

1. Building a universal combat form engine too early.
2. Moving rules logic into shared UI abstractions.
3. Letting collapsed summaries become dense and noisy.
4. Making iPad a different app instead of an adapted layout.
5. Continuing field-triggered collapse behavior instead of section-based completion. [cite:94][cite:59][cite:60]

## Implementation phases

### Phase 1: Requirements lock
- finalize section lists,
- finalize invalidation rules,
- finalize summary content rules,
- finalize reset behavior.

### Phase 2: Shared shell
- build `CombatEntrySectionShell`,
- build `CombatEntrySummaryRowStyle`,
- build `CombatContextBanner`,
- document extension points for future games.

### Phase 3: Workflow coordinator
- add section state,
- add visibility/completion logic,
- add one-open-section behavior,
- add dependency invalidation rules.

### Phase 4: Ancients migration
- migrate attacker,
- add distance banner,
- migrate defender,
- add result,
- add one follow-up branch,
- test iterative edits thoroughly.

### Phase 5: Napoleonics migration
- migrate attacker/defender,
- replace brittle collapse triggers,
- migrate Combined Attack,
- re-test distance and summary behavior.

## Open questions

1. Which sections should auto-collapse and which should require Done?
2. Which edits preserve downstream state versus clearing it?
3. For Momentum Advance / Bonus Battle, should the app derive a fresh context or transform the existing one?
4. How much summary detail is enough before rows become noisy?
5. Should richer iPad explanation layouts wait until after the core workflow is stable?

## Recommendation

The best path forward is to build a reusable combat worksheet workflow centered on a shared collapsible section shell and lightweight workflow coordinator, prove it in Ancients first, and then migrate Napoleonics after the pattern is stable. This best matches actual user behavior, preserves a compact Apple-style iPhone experience, adapts well to iPad, and creates a reusable foundation for future Commands & Colors-style systems without over-generalizing too early. [memory:110][memory:116][cite:76][cite:94]
