//
//  CombatEntryViewModel.swift
//  BattleCalc
//
//  Holds every selection for the one-page combat-entry screen and enforces
//  the cascade rule: changing a parent selection clears all dependent
//  selections below it. It assembles a real CombatContext and runs the real
//  NapoleonicsInfantryCombatEvaluator, so the result and trace shown on screen
//  are exactly what the engine produces.
//

import Foundation
import Combine

@MainActor
final class CombatEntryViewModel: ObservableObject {

    private let evaluator = NapoleonicsInfantryCombatEvaluator()

    // MARK: Attacker selections.
    // Each didSet clears the next level down only when the value actually
    // changed, so re-selecting the same value is a no-op and the chained
    // setters cannot loop.
    @Published var attackerCountry: CombatPickItem? { didSet { if attackerCountry?.id != oldValue?.id { attackerCountryDidChange(from: oldValue) } } }
    @Published var attackerClass: CombatPickItem?   { didSet { if attackerClass?.id != oldValue?.id { clearAttackerUnit() } } }
    @Published var attackerUnit: CombatPickItem?    { didSet { if attackerUnit?.id != oldValue?.id { attackerUnitDidChange() } } }
    @Published var attackerBlocks: Int?             { didSet { if attackerBlocks != oldValue { clearAttackerMoved() } } }
    @Published var attackerMovedHexes: Int?         { didSet { if attackerMovedHexes != oldValue { clearAttackerTerrain() } } }
    // Terrain is the last attacker field: changing it no longer touches the
    // defender side (editing one side must not reset the other) — it only
    // re-runs the engine.
    @Published var attackerTerrain: CombatPickItem? { didSet { if attackerTerrain?.id != oldValue?.id { recompute() } } }

    // MARK: Defender selections.
    @Published var defenderCountry: CombatPickItem? { didSet { if defenderCountry?.id != oldValue?.id { clearDefenderClass() } } }
    @Published var defenderClass: CombatPickItem?   { didSet { if defenderClass?.id != oldValue?.id { clearDefenderUnit() } } }
    @Published var defenderUnit: CombatPickItem?    { didSet { if defenderUnit?.id != oldValue?.id { defenderUnitDidChange() } } }
    @Published var defenderBlocks: Int?             { didSet { if defenderBlocks != oldValue { clearDefenderTerrain() } } }
    // Terrain is the last defender field: changing it must not reset the
    // battle-wide target distance, so it only re-runs the engine.
    @Published var defenderTerrain: CombatPickItem? { didSet { if defenderTerrain?.id != oldValue?.id { recompute() } } }

    // MARK: Extras.
    // targetDistance drives the engine's melee/ranged choice exactly as the
    // CSV sample loader does (distance 1 == melee). Default 1 = adjacent melee.
    @Published var targetDistance: Int = 1 { didSet { if targetDistance != oldValue { recompute() } } }

    // MARK: Output.
    @Published private(set) var result: CombatResult?

    // MARK: - Option providers (each section reads these).
    var countryOptions: [CombatPickItem] { CombatEntryCatalog.countries() }
    var attackerClassOptions: [CombatPickItem] { attackerCountry.map { CombatEntryCatalog.classes(in: $0.id) } ?? [] }
    var attackerUnitOptions: [CombatPickItem] {
        guard let c = attackerCountry, let k = attackerClass else { return [] }
        return CombatEntryCatalog.unitTypes(in: c.id, classID: k.id)
    }
    // MARK: - French-always-on-one-side rule.
    // France is always on exactly one side. The attacker is chosen freely; the
    // defender country is then constrained: a non-France attacker faces France,
    // and a France attacker faces some non-France country the user picks.
    private static let franceID = "france"

    /// True once an attacker country is chosen and it is France.
    var isFranceAttacker: Bool { attackerCountry?.id == Self.franceID }

    /// When the attacker is non-France the defender is forced to France, so the
    /// defender Country row is redundant and hidden. When the attacker is France
    /// the user must pick the (non-France) defender country, so the row shows.
    var showsDefenderCountryRow: Bool { isFranceAttacker }

    /// Defender country choices honoring the rule: only non-France countries are
    /// offered (and only when the attacker is France). Empty otherwise.
    var defenderCountryOptions: [CombatPickItem] {
        guard isFranceAttacker else { return [] }
        return CombatEntryCatalog.countries().filter { $0.id != Self.franceID }
    }

    /// The France pick item from the catalog, used to auto-assign the defender
    /// when the attacker is non-France. Nil only if data has no France units.
    private var franceCountryItem: CombatPickItem? {
        CombatEntryCatalog.countries().first { $0.id == Self.franceID }
    }

    var defenderClassOptions: [CombatPickItem] { defenderCountry.map { CombatEntryCatalog.classes(in: $0.id) } ?? [] }
    var defenderUnitOptions: [CombatPickItem] {
        guard let c = defenderCountry, let k = defenderClass else { return [] }
        return CombatEntryCatalog.unitTypes(in: c.id, classID: k.id)
    }
    var terrainOptions: [CombatPickItem] { CombatEntryCatalog.terrains() }

    var attackerMaxBlocks: Int { attackerUnit.map { CombatEntryCatalog.maxBlocks(forUnit: $0.id) } ?? 8 }
    var defenderMaxBlocks: Int { defenderUnit.map { CombatEntryCatalog.maxBlocks(forUnit: $0.id) } ?? 8 }

    // MARK: - Class-aware target distance (Phase 2).
    // The distance row must adapt to the attacker's class: cavalry is melee-only
    // (locked to 1), artillery's max comes from its *active* fire table (which
    // depends on moved + blocks), and infantry keeps the fixed 1...4.
    private var attackerUnitDefinition: UnitDefinition? {
        attackerUnit.flatMap { NapoleonicsUnitLibrary.unit(for: $0.id) }
    }

    /// Attacker's unit class, or nil before a unit is chosen.
    var attackerUnitClass: UnitClass? { attackerUnitDefinition?.unitClass }

    /// Cavalry is melee-only, so the UI locks the distance row to 1.
    var lockTargetDistanceToMelee: Bool { attackerUnitClass == .cavalry }

    /// Cavalry still needs the moved yes/no question (moving into woods/town can
    /// forbid battle — only Russian Cossacks fight after entering woods), but the
    /// *distance* is irrelevant to cavalry, so the UI shows a yes/no row with no
    /// hexes-moved stepper. Infantry and artillery keep yes/no + distance.
    var usesMovedYesNoOnly: Bool { attackerUnitClass == .cavalry }

    /// Upper bound for the "hexes moved" stepper: the attacker unit's own
    /// `maxMovement`, so e.g. an artillery piece with maxMovement 2 cannot be set
    /// to 3. Falls back to a permissive value before a unit is chosen.
    var maxMovedHexes: Int { attackerUnitDefinition?.combatProfile.maxMovement ?? 8 }

    /// Upper bound for the distance stepper. Cavalry -> 1; artillery -> its
    /// active table's derived range (falls back to 4 when the active band is
    /// "not allowed", since the engine still blocks the attack with the correct
    /// reason); infantry/default -> 4 (unchanged behavior).
    var maxTargetDistance: Int {
        switch attackerUnitClass {
        case .cavalry:   return 1
        case .artillery: return artilleryActiveDerivedRange ?? 4
        default:         return 4
        }
    }

    /// Derived range (leading non-nil slot count) of the artillery attacker's
    /// *active* fire band for the current moved/blocks situation, or nil when
    /// there is no active band (not allowed) or the attacker is not artillery.
    private var artilleryActiveDerivedRange: Int? {
        guard let tables = attackerUnitDefinition?.combatProfile.artilleryFireTables else { return nil }
        let moved = (attackerMovedHexes ?? 0) > 0
        let singleBlock = (attackerBlocks ?? attackerMaxBlocks) <= 1
        let band: ArtilleryFireBand?
        switch (moved, singleBlock) {
        case (false, false): band = tables.standingMultiBlock
        case (false, true):  band = tables.standingSingleBlock
        case (true, false):  band = tables.movingMultiBlock
        case (true, true):   band = tables.movingSingleBlock
        }
        guard let band else { return nil }
        var range = 0
        for (i, slot) in band.enumerated() where slot != nil { range = i + 1 }
        return range
    }

    // MARK: - Collapsed-summary detail lines.
    // Compact "chips" shown on a side's colored summary box so the separate
    // blocks / moved / terrain rows can disappear once chosen. Only set values
    // appear; a side that is not yet complete shows whatever is set so far.
    private static func blocksChip(_ n: Int?) -> String? { n.map { "\($0) block\($0 == 1 ? "" : "s")" } }

    /// Attacker chips: blocks • moved status • terrain. "Moved" is
    /// attacker-specific, so it lives here.
    var attackerSummaryDetail: String {
        var parts: [String] = []
        if let b = Self.blocksChip(attackerBlocks) { parts.append(b) }
        // Cavalry tracks moved yes/no only, so its chip omits the hex count
        // ("Moved" / "Stationary"); infantry/artillery show the distance.
        if let m = attackerMovedHexes {
            if usesMovedYesNoOnly {
                parts.append(m > 0 ? "Moved" : "Stationary")
            } else {
                parts.append(m > 0 ? "Moved \(m) hex\(m == 1 ? "" : "es")" : "Stationary")
            }
        }
        if let t = attackerTerrain { parts.append(t.title) }
        return parts.joined(separator: " • ")
    }

    /// Defender chips: blocks • terrain (defender has no movement).
    var defenderSummaryDetail: String {
        var parts: [String] = []
        if let b = Self.blocksChip(defenderBlocks) { parts.append(b) }
        if let t = defenderTerrain { parts.append(t.title) }
        return parts.joined(separator: " • ")
    }

    /// True once a side has all of its fields, so it can collapse to a summary.
    var attackerComplete: Bool { attackerTerrain != nil }
    var defenderComplete: Bool { defenderTerrain != nil }

    /// Battle-wide extras summary (range + resolved mode). Not country-specific,
    /// so it collapses into its own compact row rather than a side box.
    var extrasSummaryDetail: String {
        let mode = targetDistance == 1 ? "Melee" : "Ranged"
        return "\(targetDistance) hex\(targetDistance == 1 ? "" : "es") • \(mode)"
    }

    /// Prominent, always-visible distance/mode phrase shown between the attacker
    /// and defender. Distance 1 reads as melee ("Defender in Melee at 1 hex");
    /// distance > 1 reads as ranged ("Defender at Range Attack 2 hexes away"),
    /// driven purely by the current `targetDistance` (no engine dependency, so it
    /// shows reliably whenever the distance is known).
    var distanceToTargetHeadline: String {
        if targetDistance == 1 {
            return "Defender in Melee at 1 hex"
        }
        return "Defender at Range Attack \(targetDistance) hexes away"
    }

    // MARK: - Cascade clearing (top-down within ONE side only).
    // Each helper clears everything below it on the same side. Cross-side
    // effects live solely in `attackerCountryDidChange`, so editing the
    // attacker's class/unit/blocks/moved/terrain never disturbs the defender,
    // and vice versa.
    private func clearAttackerClass()   { attackerClass = nil;   clearAttackerUnit() }
    private func clearAttackerUnit()     { attackerUnit = nil;    clearAttackerBlocks() }
    private func clearAttackerBlocks()   { attackerBlocks = nil;  clearAttackerMoved() }
    // All classes (cavalry included) now show a "Moved This Turn?" row, so moved
    // can clear to nil for everyone: the row re-prompts and re-populates it, so a
    // cavalry edit can re-complete and collapse to its summary without stranding.
    private func clearAttackerMoved()    { attackerMovedHexes = nil; clearAttackerTerrain() }
    private func clearAttackerTerrain()  { attackerTerrain = nil; recompute() }

    private func clearDefenderClass()    { defenderClass = nil;   clearDefenderUnit() }
    private func clearDefenderUnit()      { defenderUnit = nil;    clearDefenderBlocks() }
    private func clearDefenderBlocks()   { defenderBlocks = nil;  clearDefenderTerrain() }
    private func clearDefenderTerrain()  { defenderTerrain = nil; recompute() }

    // MARK: - Unit change → default blocks to maxBlocks.
    /// When a unit type is picked we start blocks at that unit's maxBlocks (the
    /// common case is a full-strength unit), so the player never has to "Set"
    /// then count up from 1. Picking a *different* unit re-defaults to the new
    /// unit's max (per request: prefer max over preserving the old count). When
    /// the unit is cleared, blocks fall back to nil so dependents below clear.
    /// Setting blocks here triggers the blocks didSet, which clears moved/terrain
    /// below — exactly what a new unit should invalidate.
    private func attackerUnitDidChange() {
        if attackerUnit != nil { attackerBlocks = attackerMaxBlocks }
        else { clearAttackerBlocks() }
        reconcileMovedForUnit()
    }

    /// Reconciles `attackerMovedHexes` with the freshly chosen unit: clamps a
    /// previously-entered distance larger than the new unit's `maxMovement` down
    /// so the UI/context can never carry an out-of-range distance. Cavalry tracks
    /// moved yes/no only (a nonzero value just means "moved"), so it is not
    /// distance-clamped here. Called after blocks default in (blocks' didSet has
    /// already cleared moved to nil, so this is usually a no-op).
    private func reconcileMovedForUnit() {
        guard attackerUnit != nil, !usesMovedYesNoOnly else { return }
        if let m = attackerMovedHexes, m > maxMovedHexes {
            attackerMovedHexes = maxMovedHexes
        }
    }

    private func defenderUnitDidChange() {
        if defenderUnit != nil { defenderBlocks = defenderMaxBlocks }
        else { clearDefenderBlocks() }
    }

    // MARK: - Attacker country change + France-pairing reconciliation.
    /// Handles an attacker-country change in one place. It always clears the
    /// attacker's own dependents (class/unit/blocks/moved/terrain), then keeps
    /// the France-on-one-side invariant with the least disruption to the
    /// defender:
    ///  - Non-France attacker: the defender must be France. Only (re)assign it
    ///    when it is not already France, so an existing France defender setup is
    ///    preserved untouched.
    ///  - France attacker that collides with a France defender: best-effort
    ///    side-flip — move the previous (non-France) attacker setup down to the
    ///    defender so nothing is wiped, then leave the France attacker to be
    ///    rebuilt. If there is no previous non-France attacker to move, fall
    ///    back to clearing the defender so the user can repick.
    private func attackerCountryDidChange(from oldAttacker: CombatPickItem?) {
        // Capture the outgoing attacker setup BEFORE clearing, in case we need
        // to flip it to the defender below.
        let prior = SideSetup(country: oldAttacker, unitClass: attackerClass,
                              unit: attackerUnit, blocks: attackerBlocks,
                              terrain: attackerTerrain)

        clearAttackerClass()   // clears class/unit/blocks/moved/terrain (attacker only)

        if isFranceAttacker {
            // France just became the attacker. If the defender is also France we
            // would violate the rule, so flip the previous attacker down.
            if defenderCountry?.id == Self.franceID {
                if let oldA = oldAttacker, oldA.id != Self.franceID {
                    applyToDefender(prior)            // safe side-flip, no wipe
                } else {
                    clearDefenderCountry()            // nothing to move; repick
                }
            }
            // Otherwise the defender is already a valid non-France side: leave it.
        } else if attackerCountry != nil {
            // Non-France attacker: defender must be France. Preserve an existing
            // France defender; only reassign when it is currently something else.
            if defenderCountry?.id != Self.franceID {
                clearDefenderCountry()
            }
        } else {
            // Attacker cleared entirely: drop the defender too.
            clearDefenderCountry()
        }
        recompute()
    }

    /// Resets the defender country to satisfy the France rule from scratch:
    /// France attacker -> nil (user picks non-France); non-France attacker ->
    /// France; no attacker -> nil. Clears defender dependents first.
    private func clearDefenderCountry() {
        clearDefenderClass()
        if isFranceAttacker {
            defenderCountry = nil
        } else if attackerCountry != nil {
            defenderCountry = franceCountryItem
        } else {
            defenderCountry = nil
        }
    }

    /// Snapshot of one side's selections, used for the best-effort side-flip.
    private struct SideSetup {
        let country: CombatPickItem?
        let unitClass: CombatPickItem?
        let unit: CombatPickItem?
        let blocks: Int?
        let terrain: CombatPickItem?
    }

    /// Writes a captured setup onto the defender side, skipping the cascade
    /// wipes by assigning top-down so each level's parent is already in place.
    /// Defender carries no "moved" field, so movement is intentionally dropped.
    private func applyToDefender(_ s: SideSetup) {
        defenderCountry = s.country
        defenderClass = s.unitClass
        defenderUnit = s.unit
        defenderBlocks = s.blocks
        defenderTerrain = s.terrain
    }

    // MARK: - Result breakdown (display only — no combat math).
    // One signed dice line for the result list. `value` is the signed delta;
    // `label` is a short human phrase ("moved to melee", "melee into church").
    struct DiceModifierLine: Identifiable, Hashable {
        let id = UUID()
        let label: String
        let value: Int
        var signed: String { value >= 0 ? "+\(value)" : "\(value)" }
    }

    // Everything the Result section needs, derived from the engine's CombatResult
    // and the current selections. Base is shown as the RAW attacker block count
    // (what the player can read off the board); the engine sometimes folds the
    // moved-into-melee penalty into its baseDice, so that gap is re-exposed here
    // as an explicit "moved to melee" line. The arithmetic always closes:
    // base + sum(lines) == final.
    struct ResultBreakdown {
        let isAllowed: Bool
        let reasons: [String]
        let mode: String              // "Melee" / "Ranged"
        let baseBlocks: Int           // raw attacker blocks (display base)
        let lines: [DiceModifierLine] // ordered signed modifier lines
        let total: Int                // sum of all line values
        let final: Int

        /// Artillery base is table-derived, not a block count. When set, the UI
        /// shows "Base Dice: 3 at 2 hexes" instead of "Base Dice: N blocks".
        /// Nil for infantry/cavalry, so their display is unchanged.
        var artilleryBaseDescription: String? = nil

        /// True when nothing modifies the base, so the UI can collapse to a
        /// single "Melee: Final Dice: N" line. Artillery always shows the
        /// table-derived base, so a present description forces the full layout.
        var isTrivial: Bool { artilleryBaseDescription == nil && lines.isEmpty && baseBlocks == final }
    }

    /// Builds the display breakdown for the current result, or nil when there is
    /// no allowable/complete result yet. Pure presentation: it never alters the
    /// engine output, only relabels and re-splits it for clarity.
    var resultBreakdown: ResultBreakdown? {
        guard let r = result else { return nil }

        guard r.validation.isAllowed,
              let base = r.baseDice,
              let final = r.finalDice,
              let blocks = attackerBlocks
        else {
            return ResultBreakdown(
                isAllowed: r.validation.isAllowed,
                reasons: r.validation.reasons,
                mode: targetDistance == 1 ? "Melee" : "Ranged",
                baseBlocks: attackerBlocks ?? 0,
                lines: [], total: 0, final: r.finalDice ?? 0
            )
        }

        let isMelee = targetDistance == 1
        var lines: [DiceModifierLine] = []

        // Artillery base is table-derived (e.g. "3 at 2 hexes"), so the
        // base-vs-blocks gap line below does not apply — the raw block count is
        // not the base for artillery. For infantry/cavalry this is nil.
        let artilleryBase = artilleryBaseDescription(from: r.notes)

        // Re-expose the base-vs-raw-blocks gap as an explicit line. For melee with
        // the moved penalty this is exactly -1 ("moved to melee"); for ranged the
        // fire rule may halve the blocks, so the gap is labeled generically.
        // Skipped for artillery, whose base is not derived from block count.
        if artilleryBase == nil {
            let baseGap = base - blocks
            if baseGap != 0 {
                let movedThisTurn = (attackerMovedHexes ?? 0) > 0
                let label: String
                if isMelee {
                    label = movedThisTurn ? "moved to melee" : "base adjustment"
                } else {
                    label = movedThisTurn ? "moving fire" : "standing fire"
                }
                lines.append(DiceModifierLine(label: label, value: baseGap))
            }
        }

        // Map each engine modifier to a short phrase. Terrain labels are generic
        // ("Defender terrain"); the terrain name lives in `detail`, so we recover
        // it to produce "melee into <terrain>" / "melee out of <terrain>".
        for m in r.modifiers {
            lines.append(DiceModifierLine(label: shortModifierLabel(m, isMelee: isMelee),
                                          value: m.value))
        }

        let total = lines.map(\.value).reduce(0, +)

        return ResultBreakdown(
            isAllowed: true,
            reasons: [],
            mode: isMelee ? "Melee" : "Ranged",
            baseBlocks: blocks,
            lines: lines,
            total: total,
            final: final,
            artilleryBaseDescription: artilleryBase
        )
    }

    /// Parses the engine's machine-readable artillery base note
    /// ("artilleryBase:3@2") into a human phrase ("3 at 2 hexes"). Returns nil
    /// when the note is absent (non-artillery results), so their display is
    /// unchanged.
    private func artilleryBaseDescription(from notes: [String]) -> String? {
        let marker = "artilleryBase:"
        guard let note = notes.first(where: { $0.hasPrefix(marker) }) else { return nil }
        let parts = note.dropFirst(marker.count).split(separator: "@")
        guard parts.count == 2, let dice = Int(parts[0]), let dist = Int(parts[1]) else { return nil }
        return "\(dice) at \(dist) hex\(dist == 1 ? "" : "es")"
    }

    /// Short, human phrase for one engine modifier. Prefers the terrain name from
    /// `detail` over the generic label so the line reads "melee into church".
    private func shortModifierLabel(_ m: CombatModifier, isMelee: Bool) -> String {
        let verb = isMelee ? "melee" : "ranged fire"
        switch m.label {
        case "Defender terrain":
            if let name = terrainName(in: m.detail) { return "\(verb) into \(name)" }
            return "\(verb) into terrain"
        case "Attacker terrain":
            if let name = terrainName(in: m.detail) { return "\(verb) out of \(name)" }
            return "\(verb) out of terrain"
        case "Melee vs infantry":
            return "melee vs infantry"
        case "Hill-to-hill ranged fire":
            return "hill-to-hill fire"
        default:
            return m.label.lowercased()
        }
    }

    /// Extracts the terrain name from a modifier detail string of the form
    /// "Attacking into <Name> affected …" / "Attacking out of <Name> affected …".
    /// Returns a lowercased name, or nil if the pattern is absent.
    private func terrainName(in detail: String?) -> String? {
        guard let detail else { return nil }
        let markers = ["Attacking into ", "Attacking out of "]
        for marker in markers where detail.hasPrefix(marker) {
            let rest = detail.dropFirst(marker.count)
            if let end = rest.range(of: " affected") {
                return String(rest[rest.startIndex..<end.lowerBound]).lowercased()
            }
        }
        return nil
    }

    // MARK: - Result.
    /// Recomputes whenever the request is fully specified; clears it otherwise.
    func recompute() {
        // Keep the chosen distance within the attacker class's bounds. Switching
        // to cavalry (or to an artillery situation with a shorter active range)
        // must snap a previously-larger distance back in. The assignment re-enters
        // recompute via targetDistance's didSet, but the second pass is a no-op
        // clamp, so it settles in one extra hop without looping.
        let upper = max(1, maxTargetDistance)
        if targetDistance > upper { targetDistance = upper; return }
        if targetDistance < 1 { targetDistance = 1; return }
        guard let context = buildContext() else { result = nil; return }
        result = evaluator.evaluate(context: context)
    }

    /// Assembles a real CombatContext from the current selections, or nil when
    /// any required field is still missing.
    func buildContext() -> CombatContext? {
        guard
            let ac = attackerCountry, let au = attackerUnit,
            let ab = attackerBlocks, let am = attackerMovedHexes, let at = attackerTerrain,
            let dc = defenderCountry, let du = defenderUnit,
            let db = defenderBlocks, let dt = defenderTerrain
        else { return nil }

        // Distance 1 is melee; anything else is ranged — same rule the smoke
        // test loader uses, so on-screen results match the CSV samples.
        let mode: CombatMode = (targetDistance == 1) ? .melee : .ranged

        return CombatContext(
            combatMode: mode,
            movedHexes: am,
            targetDistance: targetDistance,
            attackerCountryID: ac.id,
            attackerUnitID: au.id,
            attackerBlocks: ab,
            attackerTerrainID: at.id,
            defenderCountryID: dc.id,
            defenderUnitID: du.id,
            defenderBlocks: db,
            defenderTerrainID: dt.id,
            attackDirection: .flat
        )
    }

    /// Ordered, human-readable trace for the most recent battle (the engine's
    /// applied rules), used by the debug screen.
    var lastTrace: [AppliedRule] { result?.appliedRules ?? [] }
}
