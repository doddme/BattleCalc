//
//  CombatEntryView.swift
//  BattleCalc
//
//  One-page combat-entry screen. Each step is a progressive-disclosure row:
//  an expanded picker until a value is chosen, then a one-line summary row
//  (tap to re-open). Sections appear in order — attacker, then defender, then
//  extras, then an auto-shown result — and a later section stays hidden until
//  the prior one is complete. Rows are image-ready via CombatPickRowContent.
//

import SwiftUI

struct CombatEntryView: View {
    let onChangeGame: (() -> Void)?

    init(onChangeGame: (() -> Void)? = nil) {
        self.onChangeGame = onChangeGame
    }

    @StateObject private var vm = CombatEntryViewModel()
    // Worksheet-style section control:
    // start with Attacker open, let one major side be edited at a time, and keep
    // track of whether Attacker was completed once so later edits can preserve a
    // smoother Ancients-style flow.
    @State private var editingAttacker = true
    @State private var editingDefender = false
    @State private var editingSupportingUnit = false
    @State private var attackerHasBeenCompleted = false

    // Battle-wide extras (range/mode) collapse into a compact summary too.
    @State private var editingExtras = false

    @State private var showChangeGameConfirmation = false
    #if DEBUG
    @State private var showDebug = false
    @State private var showNapoleonicsDataDebug = false
    @State private var showAncientsDataDebug = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                attackerSection
                // Always-visible distance/mode banner between the two sides.
                // Shown as soon as the attacker side is complete (so the target
                // distance is known), independent of whether a result exists — so
                // it no longer "sometimes appears, sometimes not".
                if vm.attackerTerrain != nil { distanceBanner }
                if vm.attackerTerrain != nil { defenderSection }

                // Rare Napoleonics artillery branch:
                // only show the combined-attack questions after both main sides
                // are complete, and only when the attacking unit is artillery.
                // This keeps the common artillery flow fast and hides the extra
                // support-unit questions unless they are actually relevant.
                if vm.attackerComplete && vm.defenderComplete && vm.attackerUnitClass == .artillery {
                    combinedAttackSection
                }

                if vm.result != nil { resultSection }
                // Melee-only follow-up: after an allowed melee result, ask if the
                // defender retreated and (if not) offer a battle-back.
                if vm.showsBattleBackControls { battleBackSection }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Combat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if onChangeGame != nil {
                            Button("Change Game") { showChangeGameConfirmation = true }
                        }
                        #if DEBUG
                        Button("Show Napoleonics Load Data") { showNapoleonicsDataDebug = true }
                        Button("Show Ancients Load Data") { showAncientsDataDebug = true }
                        Button("Debug") { showDebug = true }
                        #endif
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .alert("Change game?", isPresented: $showChangeGameConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Change Game", role: .destructive) { onChangeGame?() }
            } message: {
                Text("This will leave the current combat entry screen and return to game selection.")
            }
            // Debug bar temporarily hidden for playtesting.
            // To restore it, uncomment the safeAreaInset below.
            // .safeAreaInset(edge: .bottom) { debugBar }
            #if DEBUG
            .sheet(isPresented: $showDebug) {
                CombatEntryDebugView(trace: vm.lastTrace, context: vm.buildContext())
            }
            .sheet(isPresented: $showNapoleonicsDataDebug) {
                NapoleonicsDataDebugView()
            }
            .sheet(isPresented: $showAncientsDataDebug) {
                AncientsDataDebugView()
            }
            #endif
        }
    }

    // MARK: - Distance banner (between attacker and defender)
    // Prominent, always-on line so the range/mode is easy to check at a glance.
    // Uses the headline body font (same size as standard row text); the icon
    // distinguishes melee (crossed swords) from ranged (scope). The phrase comes
    // from the view model and is driven by the current target distance.
    @ViewBuilder private var distanceBanner: some View {
        Section {
            Button {
                editingAttacker = true // Reopen attacker because distance is edited from the attacker workflow.
                editingDefender = false // Keep only one major section expanded at a time.
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: vm.targetDistance == 1 ? "shield.lefthalf.filled" : "scope")
                        .foregroundStyle(.tint)
                    Text(vm.distanceToTargetHeadline)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }


    // MARK: - Attacker
    @ViewBuilder private var attackerSection: some View {
        Section("Attacker") {
            if let unit = vm.attackerUnit, vm.attackerComplete, !editingAttacker {
                // Fully collapsed: one colored box with unit type + blocks /
                // moved / terrain chips. Tapping it reopens Attacker and closes
                // Defender so the worksheet behaves like Ancients.
                SideSummaryRow(
                    unit: unit,
                    countryID: vm.attackerCountry?.id,
                    detail: vm.attackerSummaryDetail,
                    trailingCallout: nil // No contextual right-side reminder on the attacker summary.
                ) {
                    editingAttacker = true
                    editingDefender = false
                }


            } else {
                CombatDisclosureRow(label: "Country", selection: vm.attackerCountry,
                                    options: vm.countryOptions) { vm.attackerCountry = $0 }

                if vm.attackerCountry != nil {
                    CombatDisclosureRow(label: "Unit class", selection: vm.attackerClass,
                                        options: vm.attackerClassOptions) { vm.attackerClass = $0 }
                }
                if vm.attackerClass != nil {
                    CombatDisclosureRow(label: "Unit type", selection: vm.attackerUnit,
                                        options: vm.attackerUnitOptions) { vm.attackerUnit = $0 }
                }
                if vm.attackerUnit != nil {
                    CombatBlocksRow(
                        label: "Blocks",
                        value: vm.attackerBlocks ?? vm.attackerMaxBlocks,
                        maxBlocks: vm.attackerMaxBlocks,
                        helperText: vm.attackerBlocksHelperText
                    ) {
                        vm.attackerBlocks = $0
                    }
                }

                // Every class asks "Moved This Turn?" (moving into woods/town can
                // forbid battle). Cavalry needs only yes/no — the distance is
                // irrelevant — so its stepper is suppressed (`distanceAdjustable:
                // false`). Infantry/artillery keep yes/no + a hexes-moved stepper
                // capped at the unit's maxMovement (e.g. artillery maxMovement 2
                // cannot pick 3).
                if vm.attackerBlocks != nil {
                    CombatMovedRow(label: "Moved This Turn?", hexes: vm.attackerMovedHexes,
                                   maxMoved: vm.maxMovedHexes,
                                   distanceAdjustable: !vm.usesMovedYesNoOnly) { vm.attackerMovedHexes = $0 }
                }
                if vm.attackerMovedHexes != nil {
                    // PLAYTEST: target distance moved earlier in the flow (was the
                    // separate "Battle details" extras section). To revert, delete
                    // this `targetDistanceRow` call, remove the helper below, and
                    // re-enable `extrasSection` in `body` (see comments there).
                    targetDistanceRow
                }
                if vm.attackerMovedHexes != nil {
                    // Terrain the attacker fires FROM. Separate from the defender's.
                    // Unlike the older Napoleonics flow, choosing it does NOT
                    // immediately collapse the side; the explicit Done button below
                    // matches the smoother Ancients worksheet behavior.
                    CombatDisclosureRow(label: "Terrain (fires from)", selection: vm.attackerTerrain,
                                        options: vm.terrainOptions) {
                        vm.attackerTerrain = $0
                    }

                    if vm.attackerComplete {
                        Button("Done") {
                            attackerHasBeenCompleted = true // Remember that Attacker was completed once so later edits can keep Defender visible.
                            editingAttacker = false
                        }
                    }
                }

            }
        }
    }

    // MARK: - Defender
    @ViewBuilder private var defenderSection: some View {
        Section("Defender") {
            if let unit = vm.defenderUnit, vm.defenderComplete, !editingDefender {
                // Fully collapsed: one colored box with unit type + blocks /
                // terrain chips (defender has no movement). Tapping it reopens
                // Defender and closes Attacker so only one main section stays open.
                SideSummaryRow(
                    unit: unit,
                    countryID: vm.defenderCountry?.id,
                    detail: vm.defenderSummaryDetail,
                    trailingCallout: vm.defenderContextCallout // Defender-only current-combat reminder, e.g. cavalry attacking infantry.
                ) {
                    editingAttacker = false
                    editingDefender = true
                }



            } else {
                // French rule: a non-France attacker forces the defender to
                // France, so the Country row is redundant and hidden. It only
                // appears when the attacker is France (defender must be picked
                // from the non-France countries).
                if vm.showsDefenderCountryRow {
                    CombatDisclosureRow(label: "Country", selection: vm.defenderCountry,
                                        options: vm.defenderCountryOptions) { vm.defenderCountry = $0 }
                } else if let country = vm.defenderCountry {
                    LabeledContent("Country", value: country.title)
                }

                if vm.defenderCountry != nil {
                    CombatDisclosureRow(label: "Unit class", selection: vm.defenderClass,
                                        options: vm.defenderClassOptions) { vm.defenderClass = $0 }
                }
                if vm.defenderClass != nil {
                    CombatDisclosureRow(label: "Unit type", selection: vm.defenderUnit,
                                        options: vm.defenderUnitOptions) { vm.defenderUnit = $0 }
                }
                if vm.defenderUnit != nil {
                    CombatBlocksRow(
                        label: "Blocks",
                        value: vm.defenderBlocks ?? vm.defenderMaxBlocks,
                        maxBlocks: vm.defenderMaxBlocks,
                        helperText: vm.defenderBlocksHelperText
                    ) {
                        vm.defenderBlocks = $0
                    }
                }

                if vm.defenderBlocks != nil {
                    // Terrain the defender OCCUPIES — chosen independently because
                    // the two units are at least one hex apart. Like Ancients, keep
                    // the side open until the user explicitly taps Done.
                    CombatDisclosureRow(label: "Terrain (occupies)", selection: vm.defenderTerrain,
                                        options: vm.terrainOptions) {
                        vm.defenderTerrain = $0
                    }

                    if vm.defenderComplete {
                        Button("Done") {
                            editingDefender = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Combined attack (Napoleonics artillery only)
    @ViewBuilder private var combinedAttackSection: some View {
        Section("Combined Attack") {
            // Combined attacks are rare, so the UI starts with one high-level
            // yes/no question. Only if the user says yes do we ask for the
            // supporting-unit details needed by the evaluator.
            Toggle("Is this a Combined Attack with another ordered unit?",
                   isOn: $vm.isCombinedAttack)

            if vm.isCombinedAttack {
                // Match the attacker/defender progressive-disclosure pattern:
                // once the support unit has the required fields, collapse it to
                // one compact colored summary row so the result section stays
                // higher on screen and the user scrolls less.
                //
                // Tapping the summary re-expands the support rows for editing,
                // but does not clear the chosen values.
                if let unit = vm.supportingUnit,
                   vm.supportingUnitComplete,
                   !editingSupportingUnit {
                    SideSummaryRow(
                        unit: unit,
                        countryID: vm.supportingCountry?.id,
                        detail: vm.supportingUnitSummaryDetail,
                        trailingCallout: nil // Support summary has no contextual right-side reminder.
                    ) {
                        editingSupportingUnit = true
                    }

                } else {
                    // The supporting unit must be an infantry or cavalry unit from
                    // the attacker's side. We do not ask separately whether it is
                    // infantry or cavalry — the chosen unit answers that naturally.
                    //
                    // This whole branch is the expanded editor for the support unit.
                    // Once complete, the "Done" button below collapses it back to
                    // the compact summary row above.
                    
                    // added so the country is chosen for the supporting unit.
                    // we could have british artillery and spanish infantry
                    //
                    // France is the special case: France has no allied support-country
                    // choice here, so when France is the attacker the support country
                    // is auto-set in the view model and this picker is hidden.
                    if !vm.isFranceAttacker {  // Excluding France because it has no allies and it's always france
                        CombatDisclosureRow(
                            label: "Supporting country",
                            selection: vm.supportingCountry,
                            options: supportingCountryOptions
                        ) {
                            vm.supportingCountry = $0
                        }
                    } else if let country = vm.supportingCountry {
                        // Show the locked France value while expanded so the user
                        // can still see which country is being used for support.
                        LabeledContent("Supporting country", value: country.title)
                    }

                    CombatDisclosureRow(
                        label: "Supporting unit",
                        selection: vm.supportingUnit,
                        options: supportingUnitOptions
                    ) {
                        vm.supportingUnit = $0
                    }

                    if vm.supportingUnit != nil {
                        // The evaluator needs the support unit's current blocks
                        // because its melee contribution depends on block count.
                        CombatBlocksRow(
                            label: "Supporting unit blocks",
                            value: vm.supportingUnitBlocks ?? supportingUnitMaxBlocks,
                            maxBlocks: supportingUnitMaxBlocks
                        ) {
                            vm.supportingUnitBlocks = $0
                        }
                    }

                    if vm.supportingUnit != nil {
                        // The support unit's terrain matters because its melee dice
                        // contribution is still affected by terrain modifiers.
                        //
                        // Selecting terrain is the last always-needed field for the
                        // current support-unit flow, so after this point the support
                        // side is considered complete and may be collapsed.
                        CombatDisclosureRow(
                            label: "Supporting terrain",
                            selection: vm.supportingUnitTerrain,
                            options: vm.terrainOptions
                        ) {
                            vm.supportingUnitTerrain = $0
                        }
                    }
                    
                    if showsSupportingUnitMovedIntoMeleeToggle {
                        // Spanish infantry melee support may lose 1 die if it moved
                        // into melee this turn, so we ask only a simple yes/no here.
                        // We do not ask how many hexes it moved because that does not
                        // affect this support calculation.
                        //
                        // This answer is preserved when collapsing/re-expanding so
                        // the user can review or edit it without re-entering the row.
                        Toggle("Supporting Spanish infantry moved into melee this turn",
                               isOn: $vm.supportingUnitMovedIntoMelee)
                    }

                    if supportingUnitClass == .infantry {
                        // Infantry support needs one extra state: whether it is in
                        // square. Per current Napoleonics combined-attack handling,
                        // infantry in square contributes 1 die before terrain effects.
                        //
                        // This also becomes part of the collapsed summary detail so
                        // the support unit's special status is still visible at a glance.
                        Toggle("Supporting infantry is in square",
                               isOn: $vm.supportingUnitInSquare)
                    }

                    if vm.supportingUnitComplete {
                        // Mirrors the attacker/defender flow: once the support side
                        // is complete, let the user collapse it intentionally to keep
                        // the result dice count visible with minimal scrolling.
                        Button("Done") {
                            editingSupportingUnit = false
                        }
                    }
                }
            }

        }
    }

    
    // MARK: - Extras (battle-wide; compact summary by default)
    @ViewBuilder private var extrasSection: some View {
        Section("Battle details") {
            if !editingExtras {
                // Collapsed: one neutral (not country-colored) summary row, since
                // target distance applies to the whole battle, not one side.
                Button { editingExtras = true } label: {
                    HStack {
                        Text("Range").foregroundStyle(.secondary)
                        Spacer()
                        Text(vm.extrasSummaryDetail)
                        Image(systemName: "chevron.down").font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // Range 1 = melee; 2+ = ranged. Drives the engine's combat mode.
                Stepper(value: Binding(get: { vm.targetDistance },
                                       set: { vm.targetDistance = $0 }), in: 1...4) {
                    LabeledContent("Range to target (hexes)", value: "\(vm.targetDistance)")
                }
                Text(vm.targetDistance == 1 ? "Adjacent — resolved as melee."
                                            : "\(vm.targetDistance) hexes — resolved as ranged fire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Done") { editingExtras = false }
            }
        }
    }

    // MARK: - Target distance (PLAYTEST: inline in the attacker flow)
    // Self-contained distance picker shown between "Moved This Turn?" and the
    // attacker terrain row. Uses the same 1...4 stepper and melee/ranged caption
    // as the old `extrasSection` editor, so behavior (range 1 = melee, 2+ =
    // ranged) is identical — only the placement changed. Delete this helper and
    // re-enable `extrasSection` in `body` to move distance back to the end.
    @ViewBuilder private var targetDistanceRow: some View {
        // Match the smoother Ancients worksheet treatment: keep Distance to Target
        // visually grouped in its own tinted box so the player can quickly verify
        // range and mode before moving on.
        VStack(alignment: .leading, spacing: 10) {
            // Class-aware. Cavalry is melee-only, so the stepper locks to 1.
            // Artillery and infantry use a 1...maxTargetDistance stepper, where
            // the artillery max is derived from the active fire table (updates
            // after moved/blocks change).
            if vm.lockTargetDistanceToMelee {
                LabeledContent("Range to target (hexes)", value: "1")

                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(.tint)
                    Text(vm.distanceToTargetHeadline)
                        .font(.headline)
                }

                Text("Cavalry is melee-only — locked to adjacent (1 hex).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            } else {
                let upper = max(1, vm.maxTargetDistance)

                Stepper(value: Binding(get: { vm.targetDistance },
                                       set: { vm.targetDistance = $0 }), in: 1...upper) {
                    LabeledContent("Range to target (hexes)", value: "\(vm.targetDistance) / \(upper)")
                }

                HStack(spacing: 8) {
                    Image(systemName: vm.targetDistance == 1 ? "shield.lefthalf.filled" : "scope")
                        .foregroundStyle(.tint)
                    Text(vm.distanceToTargetHeadline)
                        .font(.headline)
                }

                Text(vm.targetDistance == 1
                     ? "Range 1 is melee."
                     : "Range \(vm.targetDistance) is resolved as ranged fire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12) // Make the distance/mode area read as one worksheet block, like Ancients.
        .background(Color.accentColor.opacity(0.08)) // Subtle tint so this high-value rule input stands out without feeling like a warning.
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) // Keep the grouped box soft and Apple-like.
    }


    // MARK: - Result (auto-shown)
    @ViewBuilder private var resultSection: some View {
        if let b = vm.resultBreakdown {
            Section("Result") {
                if b.isAllowed {
                    ResultBreakdownView(breakdown: b)
                } else {
                    Label("Attack not allowed", systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                    ForEach(b.reasons, id: \.self) { reason in
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Battle Back (melee-only follow-up)
    // Shown only after an allowed melee primary result. Flow:
    //  1. "Did the defender Retreat?"  No / Yes.
    //  2. If No: a stepper to set the defender's remaining blocks (losses), then
    //     a "Battle Back" button. Reducing to the minimum still allows a battle
    //     back; an eliminated (0-block) defender is modeled by simply not
    //     battling back (the stepper's lower bound is 1 — see the view model).
    //  3. Battle Back runs the reversed melee (original defender → original
    //     attacker) and shows its dice below.
    // If Yes (retreated): no battle-back is offered.
    @ViewBuilder private var battleBackSection: some View {
        Section("Battle Back") {
            HStack {
                Text("Did the Defender Retreat?")
                Spacer()
                Button("No")  { vm.setDefenderRetreated(false) }
                    .buttonStyle(.bordered)
                    .tint(vm.defenderRetreated == false ? .accentColor : nil)
                Button("Yes") { vm.setDefenderRetreated(true) }
                    .buttonStyle(.bordered)
                    .tint(vm.defenderRetreated == true ? .accentColor : nil)
            }

            if vm.defenderRetreated == true {
                Text("Defender Retreated — NO Battle Back.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if vm.defenderRetreated == false {
                // Defender's remaining blocks after losses. Bounded 1...original
                // (0 = eliminated is represented by not pressing Battle Back).
                let upper = vm.defenderBlocksUpperBound
                Stepper(value: Binding(get: { vm.defenderRemainingBlocks ?? upper },
                                       set: { vm.defenderRemainingBlocks = $0 }), in: 1...upper) {
                    LabeledContent("Defender blocks remaining",
                                   value: "\(vm.defenderRemainingBlocks ?? upper) / \(upper)")
                }
                Text("Important: Update the (original) defender's block strength, then battle back. If the defender is eliminated, it cannot battle back.")
                    .font(.caption).foregroundStyle(.secondary)

                Button("Battle Back") { vm.performBattleBack() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.canBattleBack)

                if let b = vm.battleBackBreakdown {
                    if b.isAllowed {
                        Text("Defender battles back (melee, 1 hex):")
                            .font(.caption).foregroundStyle(.secondary)
                        ResultBreakdownView(breakdown: b)
                    } else {
                        Label("Battle back not allowed", systemImage: "xmark.octagon")
                            .foregroundStyle(.red)
                        ForEach(b.reasons, id: \.self) { reason in
                            Text(reason).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    
    // Supporting countries come from the non-French side of the battle.
    // In Napoleonics the allies may mix support nations on the same side, so
    // combined-attack support cannot be restricted to the artillery unit's own country.
    private var supportingCountryOptions: [CombatPickItem] {
        CombatEntryCatalog.countries().filter { $0.id != "france" }
    }

    // Supporting units for a combined artillery attack come from the same side
    // as the artillery and are limited to infantry or cavalry. We intentionally
    // exclude artillery here because the evaluator treats only infantry/cavalry
    // as valid melee support for this feature.  Changed to supportingCountry instead of attacker country
    private var supportingUnitOptions: [CombatPickItem] {
        guard let country = vm.supportingCountry else { return [] }
        let infantry = CombatEntryCatalog.unitTypes(in: country.id, classID: "infantry")
        let cavalry = CombatEntryCatalog.unitTypes(in: country.id, classID: "cavalry")
        return infantry + cavalry
    }

    // Used only to decide whether the extra "in square" question should appear.
    // If the chosen support unit is infantry, we ask it; cavalry does not need it.
    private var supportingUnitClass: UnitClass? {
        guard let unitID = vm.supportingUnit?.id else { return nil }
        return NapoleonicsUnitLibrary.unit(for: unitID)?.unitClass
    }
    
    // Only Spanish infantry currently needs the extra yes/no movement question
    // in the combined-attack support flow. We keep this narrow on purpose so
    // rare combined attacks do not ask extra questions unless the answer can
    // actually change the dice.
    private var showsSupportingUnitMovedIntoMeleeToggle: Bool {
        guard let unitID = vm.supportingUnit?.id,
        let unit = NapoleonicsUnitLibrary.unit(for: unitID) else { return false }
        
        return unit.countryID == "spain" && unit.unitClass == .infantry
        }

    // The support-unit blocks stepper uses the selected unit's own max blocks,
    // just like the main attacker/defender block steppers do elsewhere.
    private var supportingUnitMaxBlocks: Int {
        vm.supportingUnit.map { CombatEntryCatalog.maxBlocks(forUnit: $0.id) } ?? 8
    }

    
    // MARK: - DEBUG bar (compile-time gated)
    @ViewBuilder private var debugBar: some View {
        #if DEBUG
        Button {
            showDebug = true
        } label: {
            Label("DEBUG", systemImage: "ladybug")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .padding(.horizontal)
        .padding(.bottom, 8)
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Result breakdown --------------------------------------------------

/// Compact, phone-friendly dice breakdown. Shows the base block count, one tight
/// line per signed modifier, a total, and a bold final. When nothing modifies
/// the base it collapses to a single "<Mode>: Final Dice: N" line. Display only
/// — every number comes straight from the engine via the view model.
struct ResultBreakdownView: View {
    let breakdown: CombatEntryViewModel.ResultBreakdown
    @State private var expanded = false

    var body: some View {
        if breakdown.isTrivial {
            // No modifiers and base == final: one line is enough, plus any
            // text-only rule note (e.g. the plateau hill-to-hill explanation).
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("\(breakdown.mode): Final Dice: ")
                    Text("\(breakdown.final)").bold()
                }
                .font(.subheadline)

                if let note = breakdown.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let reminder = breakdown.unitReminder {
                    Text(reminder)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        } else {
            VStack(alignment: .leading, spacing: 0) {
                DisclosureGroup(isExpanded: $expanded) {
                    VStack(alignment: .leading, spacing: 2) {
                        // Artillery shows a table-derived base ("Base Dice: 3 at 2 hexes");
                        // everything else shows the raw block count ("Base Dice: N blocks").
                        if let artilleryBase = breakdown.artilleryBaseDescription {
                            Text("Base Dice: \(artilleryBase)")
                                .font(.caption)
                        } else {
                            Text("Base Dice: \(breakdown.baseBlocks) block\(breakdown.baseBlocks == 1 ? "" : "s")")
                                .font(.caption)
                        }

                        if let combinedArmsBonusNote = breakdown.combinedArmsBonusNote {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Combined Arms bonus") // Label aligned with other modifier rows.
                                    Spacer()
                                    if let v = breakdown.combinedArmsBonusValue {
                                        Text(v >= 0 ? "+\(v)" : "\(v)")
                                            .monospacedDigit()
                                    }
                                }
                                .font(.caption)

                                Text(combinedArmsBonusNote)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }


                        ForEach(breakdown.lines) { line in
                            HStack {
                                Text(line.label)
                                Spacer()
                                Text(line.signed).monospacedDigit()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }


                        if !breakdown.lines.isEmpty {
                            HStack {
                                Text("total modifiers")
                                Spacer()
                                Text(breakdown.total >= 0 ? "+\(breakdown.total)" : "\(breakdown.total)")
                                    .monospacedDigit()
                            }
                            .font(.caption)
                        }

                        if let note = breakdown.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let reminder = breakdown.unitReminder {
                            Text(reminder)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    // Let DisclosureGroup provide the single built-in chevron.
                    // We keep the summary line compact and use the same soft grouped
                    // worksheet styling as the distance block above.
                    HStack(spacing: 6) {
                        Text("\(breakdown.mode): Final Dice:")
                        Text("\(breakdown.final)").bold()

                        Spacer()
                    }
                    .font(.subheadline)
                }
            }
            .padding(12) // Match the worksheet-style grouped treatment used for Distance to Target.
            .background(Color.accentColor.opacity(0.08)) // Subtle tint keeps the result readable but visually important.
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) // Soft rounded box, matching the newer Ancients-inspired UI direction.
        }

    }
}


// MARK: - Reusable rows -----------------------------------------------------

/// Shared row body. Image-ready: shows `imageName` when present, otherwise a
/// neutral placeholder, so unit/terrain art drops in later untouched.
struct CombatPickRowContent: View {
    let item: CombatPickItem
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let name = item.imageName {
                    Image(name).resizable().scaledToFit()
                } else {
                    Image(systemName: "square.dashed").foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                if let sub = item.subtitle {
                    Text(sub).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, item.colorKey == nil ? 0 : 6)
        .padding(.horizontal, item.colorKey == nil ? 0 : 8)
        .background(unitColor(for: item.colorKey).opacity(item.colorKey == nil ? 0 : 0.22))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func unitColor(for key: String?) -> Color {
        switch key?.lowercased() {
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        default: return .clear
        }
    }
}




/// Collapsed summary for a whole side. Stands in for Country + Unit class +
/// Unit type + Blocks + (Moved) + Terrain once the side is complete: the unit
/// type as the title with a compact detail line (e.g. "4 blocks • Moved 1 hex •
/// Clear"), tinted to the unit's country (gray fallback). Tapping re-expands
/// every field with its current value preselected. Image-ready via
/// CombatPickRowContent.
///
/// `trailingCallout` is for contextual reminders that belong to the current
/// combat state, not to the static colored unit chip itself. Example: Ancients
/// defender-only MAY EVADE / MAY NOT EVADE text.
struct SideSummaryRow: View {
    let unit: CombatPickItem
    let countryID: String?
    let detail: String
    let trailingCallout: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    CombatPickRowContent(item: unit)

                    // Put the contextual reminder on the same lower line as the
                    // gray summary detail so it reads against this combat state's
                    // blocks / terrain facts instead of competing with the colored
                    // unit capability chip above.
                    if !detail.isEmpty || (trailingCallout?.isEmpty == false) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            if let trailingCallout, !trailingCallout.isEmpty {
                                Text(trailingCallout)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.battleCalcCountry(countryID ?? "").opacity(0.30))
    }
}


/// Core progressive-disclosure primitive: collapsed summary when a value is
/// chosen (tap to re-open), expanded picker otherwise; collapses on selection.
struct CombatDisclosureRow: View {
    let label: String
    let selection: CombatPickItem?
    let options: [CombatPickItem]
    let onSelect: (CombatPickItem) -> Void

    @State private var expanded = false

    var body: some View {
        if let chosen = selection, !expanded {
            Button { expanded = true } label: {
                HStack {
                    Text(label).foregroundStyle(.secondary)
                    Spacer()
                    CombatPickRowContent(item: chosen)
                    Image(systemName: "chevron.down").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } else {
            DisclosureGroup(label, isExpanded: Binding(
                get: { selection == nil || expanded },
                set: { expanded = $0 })) {
                    if options.isEmpty {
                        Text("No options").foregroundStyle(.secondary)
                    } else {
                        ForEach(options) { opt in
                            Button {
                                onSelect(opt)
                                expanded = false
                            } label: {
                                HStack {
                                    CombatPickRowContent(item: opt)
                                    Spacer()
                                    if opt.id == selection?.id {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
        }
    }
}

/// Blocks entry. The value is pre-seeded to the unit's maxBlocks the moment the
/// unit type is chosen (see the view model), so there is no "Set" step: the row
/// is always a bounded stepper. Pass 1 removes the max-block display and lets
/// callers supply a short helper line with more useful play information.
struct CombatBlocksRow: View {
    let label: String
    let value: Int
    let maxBlocks: Int
    var helperText: String? = nil
    let onChange: (Int) -> Void

    var body: some View {
        let upper = max(1, maxBlocks)

        VStack(alignment: .leading, spacing: 4) {
            Stepper(value: Binding(get: { value }, set: { onChange($0) }), in: 1...upper) {
                LabeledContent(label, value: "\(value)")
            }

            if let helperText {
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Moved entry, prompted as "Moved This Turn?". First choice is No/Yes; "Yes"
/// stores 1 hex and (when `distanceAdjustable`) reveals a stepper for the exact
/// number of hexes moved (maps to movedHexes). Cavalry passes
/// `distanceAdjustable: false`, so "Yes" stores 1 (meaning "moved") with no
/// distance stepper — the value still feeds terrain-entry legality checks.
struct CombatMovedRow: View {
    let label: String
    let hexes: Int?
    let maxMoved: Int
    var distanceAdjustable: Bool = true
    let onChange: (Int) -> Void

    var body: some View {
        if let h = hexes {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(label, isOn: Binding(get: { h > 0 },
                                            set: { onChange($0 ? max(1, h) : 0) }))
                if distanceAdjustable, h > 0 {
                    Stepper(value: Binding(get: { h }, set: { onChange($0) }), in: 1...max(1, maxMoved)) {
                        LabeledContent("Hexes moved", value: "\(h)")
                    }
                }
            }
        } else {
            HStack {
                Text(label)
                Spacer()
                Button("No")  { onChange(0) }.buttonStyle(.bordered)
                Button("Yes") { onChange(1) }.buttonStyle(.bordered)
            }
        }
    }
}
