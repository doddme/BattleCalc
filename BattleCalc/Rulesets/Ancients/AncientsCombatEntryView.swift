//
//  AncientsCombatEntryView.swift
//  BattleCalc
//
//  Draft Ancients combat entry screen. This is intentionally separate from the
//  Napoleonics combat entry flow, but follows the same progressive disclosure
//  behavior so game systems feel consistent.
//

import SwiftUI

struct AncientsCombatEntryView: View {
    let onChangeGame: (() -> Void)?

    init(onChangeGame: (() -> Void)? = nil) {
        self.onChangeGame = onChangeGame
    }

    @StateObject private var vm = AncientsCombatEntryViewModel()
    @State private var editingAttacker = true
    @State private var editingDefender = true
    @State private var attackerHasBeenCompleted = false
    @State private var showChangeGameConfirmation = false

   #if DEBUG
    @State private var showNapoleonicsDataDebug = false
    @State private var showAncientsDataDebug = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                draftNotice
                attackerSection
                if attackerHasBeenCompleted {
                    distanceBanner
                    defenderSection
                } else if vm.attackerComplete && !editingAttacker {
                    distanceBanner
                    defenderSection
                }

                if let result = vm.result, vm.defenderComplete, !editingDefender {
                    resultSection(result, title: "Result")
                }
                if vm.showsBattleBackControls, vm.defenderComplete, !editingDefender {
                    battleBackSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ancients")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Reset") { resetScreen() }
                        if onChangeGame != nil {
                            Button("Change Game") { showChangeGameConfirmation = true }
                        }
                        #if DEBUG
                        Button("Napoleonics Data") { showNapoleonicsDataDebug = true }
                        Button("Ancients Data") { showAncientsDataDebug = true }
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
                Text("This will leave the current combat entry screen and return to main game selection page.")
            }
            #if DEBUG
            .sheet(isPresented: $showNapoleonicsDataDebug) {
                NapoleonicsDataDebugView()
            }
            .sheet(isPresented: $showAncientsDataDebug) {
                AncientsDataDebugView()
            }
            #endif
        }
    }

    private var draftNotice: some View {
        Section {
            Text("Ancients is still being worked on. Currently we're updating the interface to give consistent feel between the apps. testing is still needed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var distanceBanner: some View {
        Section {
            Button {
                editingAttacker = true // Reopen attacker because distance is edited from the attacker workflow.
                editingDefender = false // Keep only one major section expanded at a time.

            } label: {
                HStack(spacing: 8) {
                    Image(systemName: vm.isMelee ? "shield.lefthalf.filled" : "scope")
                        .foregroundStyle(.tint)
                    Text(vm.distanceHeadline)
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

    private var attackerSection: some View {
        Section("Attacker") {
            if let unit = vm.attackerUnit, vm.attackerComplete, !editingAttacker {
                SideSummaryRow(
                    unit: unit,
                    countryID: nil,
                    detail: vm.attackerSummaryDetail,
                    trailingCallout: nil // Attacker never shows the defender-only evade reminder.
                ) {
                    editingAttacker = true // Reopen attacker for worksheet-style editing.
                    editingDefender = false // Collapse defender when switching back to attacker.
                }

            } else {

                CombatDisclosureRow(label: "Unit class", selection: vm.attackerClass, options: vm.classOptions) { vm.attackerClass = $0 }
                if vm.attackerClass != nil {
                    CombatDisclosureRow(label: "Unit type", selection: vm.attackerUnit, options: vm.attackerUnitOptions) { vm.attackerUnit = $0 }
                }
                if vm.attackerUnit != nil {
                    CombatBlocksRow(label: "Blocks", value: vm.attackerBlocks, maxBlocks: vm.attackerMaxBlocks) { vm.attackerBlocks = $0 }
                    CombatMovedRow(label: "Moved This Turn?", hexes: vm.attackerMovedHexes, maxMoved: vm.maxMovedHexes) { vm.attackerMovedHexes = $0 }
                    AncientsLeaderSupportRow(label: "Leader support", support: vm.attackerLeaderSupport) { vm.attackerLeaderSupport = $0 }
                }
                if vm.attackerMovedHexes != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        Stepper(value: $vm.targetDistance, in: 1...6) {
                            LabeledContent(
                                "Distance to target",
                                value: "\(vm.targetDistance) hex\(vm.targetDistance == 1 ? "" : "es")"
                            )
                        }

                        HStack(spacing: 8) {
                            Image(systemName: vm.isMelee ? "shield.lefthalf.filled" : "scope")
                                .foregroundStyle(.tint)
                            Text(vm.distanceHeadline)
                                .font(.headline)
                        }

                        Text("Range 1 is Close Combat. Range 2 or more is ranged combat if the unit can fire that far.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12) // Group distance controls into a more visible, worksheet-style box.
                    .background(Color.accentColor.opacity(0.08)) // Add a subtle tint so Distance to Target stands out without looking like an alert.  Raise or lower to change tint.
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) // Keep the highlighted distance area soft and Apple-like.

                    CombatDisclosureRow(label: "Terrain (occupies)", selection: vm.attackerTerrain, options: vm.terrainOptions) {
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

 
    private var defenderSection: some View {
        Section("Defender") {
            if let unit = vm.defenderUnit, vm.defenderComplete, !editingDefender {
                SideSummaryRow(
                    unit: unit,
                    countryID: nil,
                    detail: vm.defenderSummaryDetail,
                    trailingCallout: vm.defenderContextCallout
                ) {
                    editingAttacker = false // Collapse attacker when switching to defender so only one section stays open.
                    editingDefender = true // Reopen defender for worksheet-style editing.
                }

            } else {

                CombatDisclosureRow(label: "Unit class", selection: vm.defenderClass, options: vm.classOptions) { vm.defenderClass = $0 }
                if vm.defenderClass != nil {
                    CombatDisclosureRow(label: "Unit type", selection: vm.defenderUnit, options: vm.defenderUnitOptions) { vm.defenderUnit = $0 }
                }
                if vm.defenderUnit != nil {
                    CombatBlocksRow(label: "Blocks", value: vm.defenderBlocks, maxBlocks: vm.defenderMaxBlocks) { vm.defenderBlocks = $0 }
                    AncientsLeaderSupportRow(label: "Leader support", support: vm.defenderLeaderSupport) { vm.defenderLeaderSupport = $0 }
                    Toggle("Is defender supported?", isOn: $vm.defenderSupported)
                    if vm.defenderUnit?.id == "elephant" {
                        Text("Elephants do not receive support, but they do provide support.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    CombatDisclosureRow(label: "Terrain (occupies)", selection: vm.defenderTerrain, options: vm.terrainOptions) {
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

    private var battleBackSection: some View {
        Section("After Close Combat") {
            Text("Battle Back happens only if the defender survived and did not retreat out of its hex. If the defender was eliminated or forced to retreat, check MOMENTUM ADVANCE (take ground) instead.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Was defender eliminated or forced to retreat?")
                Spacer()

                if vm.defenderStayedInHex == true {
                    Button("No") { vm.setDefenderStayedInHex(true) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("No") { vm.setDefenderStayedInHex(true) }
                        .buttonStyle(.bordered)
                }

                if vm.defenderStayedInHex == false {
                    Button("Yes") { vm.setDefenderStayedInHex(false) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Yes") { vm.setDefenderStayedInHex(false) }
                        .buttonStyle(.bordered)
                }
            }


            if vm.defenderStayedInHex == true {
                Text("Defender remained in their hex, so it may Battle Back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Resolve Battle Back") { vm.performBattleBack() }
                    .disabled(!vm.canBattleBack)
            } else if vm.defenderStayedInHex == false {
                Text("No Battle Back: the defender was eliminated or retreated out of its hex.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AncientsMarkdownCaption(vm.momentumAdvanceGuidance)
            }

            if let battleBackResult = vm.battleBackResult {
                AncientsResultRows(result: battleBackResult)
            }
        }
    }

    private func resultSection(_ result: CombatResult, title: String) -> some View {
        Section(title) {
            AncientsResultRows(result: result)
        }
    }

    private func resetScreen() {
        vm.reset()
        editingAttacker = true
        editingDefender = true
        attackerHasBeenCompleted = false
    }
}

private struct AncientsMarkdownCaption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        Text(attributed)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AncientsLeaderSupportRow: View {
    let label: String
    let support: CombatLeaderSupport
    let onChange: (CombatLeaderSupport) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.purple)

            Picker(label, selection: Binding(get: { support }, set: { onChange($0) })) {
                ForEach(CombatLeaderSupport.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(.purple)

            Text(helperText)
                .font(.caption2)
                .foregroundStyle(.purple)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var helperText: String {
        switch support {
        case .none:
            return "No leader benefits selected."
        case .adjacent:
            return "Adjacent leader: helmets can hit in Close Combat for non-elephants."
        case .attached:
            return "Attached leader: helmets can hit in Close Combat for non-elephants, and the unit may ignore one flag."
        }
    }
}

private struct AncientsLeaderInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Attached leader") {
                    Text("An attached leader means Helmet Symbols count as hits in Close Combat for a friendly non-elephant unit.")
                    Text("A unit with an attached leader may ignore one flag.")
                    Text("For an attacking foot unit, an attached leader may allow a bonus Close Combat after Momentum Advance (Take Ground).")
                }

                Section("Important limits") {
                    Text("Leaders do not affect Ranged Combat hit symbols.")
                    Text("Elephants do not receive Close Combat benefits from leaders.")
                    Text("Battle Back does not create Momentum Advance or bonus Close Combat follow-up.")
                }
            }
            .navigationTitle("Leader Info")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Ancients result breakdown -------------------------------------------

// Display-only dice line for the expandable Ancients result trace. This mirrors
// the Napoleonics result breakdown pattern so the UI shape can be standardized
// later without changing combat math here.
private struct AncientsDiceModifierLine: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Int

    var signed: String { value >= 0 ? "+\(value)" : "\(value)" } // Show the modifier with an explicit sign so the arithmetic is easy to follow.
}

// Everything the expandable Ancients result trace needs. This is presentation
// only — it does not alter evaluator output, it just explains it more clearly.
private struct AncientsResultBreakdown {
    let base: Int
    let lines: [AncientsDiceModifierLine]
    let total: Int
    let final: Int

    var isTrivial: Bool { lines.isEmpty && base == final } // Allow the trace to stay compact when nothing changes the base.
}



private struct AncientsResultRows: View {
    let result: CombatResult
    @State private var showingLeaderInfo = false
    @State private var showingDiceTrace = false // Controls expansion of the Final dice trace without changing combat math.

    private var breakdown: AncientsResultBreakdown? {
        guard result.validation.isAllowed,
              let base = result.baseDice,
              let final = result.finalDice
        else { return nil }

        let lines = result.modifiers.map {
            AncientsDiceModifierLine(label: shortModifierLabel(for: $0), value: $0.value)
        } // Convert engine modifiers into compact signed display lines for the player-facing dice trace.

        return AncientsResultBreakdown(
            base: base,
            lines: lines,
            total: result.modifierTotal, // Use the engine-provided modifier total so the display matches the evaluated result exactly.
            final: final
        )
    }

    private func shortModifierLabel(for modifier: CombatModifier) -> String {
        if let detail = modifier.detail, !detail.isEmpty {
            return modifier.label.isEmpty ? detail : modifier.label // Prefer the short label, but keep detail available when the label alone would be too vague.
        }
        return modifier.label.isEmpty ? "modifier" : modifier.label
    }

    var body: some View {

        if result.validation.isAllowed {
            if let baseDice = result.baseDice, let finalDice = result.finalDice {
                VStack(alignment: .leading, spacing: 6) { // Keep the answer row visually distinct while leaving the supporting trace rows plain.
                    // Keep the result compact by default, but allow players to open a dice trace when they want to verify the arithmetic.
                    Button {
                        showingDiceTrace.toggle() // Expand or collapse the dice trace from the Final dice row itself.
                    } label: {
                        HStack(spacing: 8) {
                            Text("Final Dice:")
                                .font(.headline.weight(.bold)) // Make the main result label read like the primary answer, not supporting detail.
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(finalDice)")
                                .font(.headline.weight(.bold)) // Match the label emphasis so the total reads as one strong headline result.
                                .foregroundStyle(.primary)
                            Image(systemName: showingDiceTrace ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(12) // Highlight only the Final Dice row so it stands apart from the supporting trace.
                        .background(Color.accentColor.opacity(0.08)) // Use the subtle tint only on the main answer row.
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) // Keep the highlighted answer row visually consistent with the distance styling.
                    }
                    .buttonStyle(.plain)

                    if showingDiceTrace, let breakdown {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Base Dice: \(breakdown.base)")
                                .font(.caption) // Start the expanded trace with the engine base before any modifiers are applied.

                            ForEach(breakdown.lines) { line in
                                HStack {
                                    Text(line.label)
                                    Spacer()
                                    Text(line.signed)
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            if !breakdown.lines.isEmpty {
                                HStack {
                                    Text("Total Modifiers")
                                    Spacer()
                                    Text(breakdown.total >= 0 ? "+\(breakdown.total)" : "\(breakdown.total)")
                                        .monospacedDigit()
                                }
                                .font(.caption) // Show the combined modifier total so players can quickly verify the arithmetic.
                            }

                            ForEach(result.appliedRules) { rule in
                                let isLeaderRule = rule.ruleID.contains(".leader")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(isLeaderRule ? .purple : .primary)
                                    Text(rule.outcome)
                                        .font(.caption)
                                        .foregroundStyle(isLeaderRule ? .purple : .secondary)
                                    if rule.ruleID == "ancients.post-roll.leader.attached" {
                                        Button("Leader Info") { showingLeaderInfo = true }
                                            .font(.caption)
                                            .buttonStyle(.bordered)
                                            .tint(.purple)
                                    }
                                }
                                .padding(.vertical, 2) // Keep rule explanations inside the Final Dice disclosure so all result reasoning lives in one place.
                            }
                            .sheet(isPresented: $showingLeaderInfo) {
                                AncientsLeaderInfoSheet() // Keep the Leader Info sheet attached to a concrete view inside the disclosure.
                            }

                            ForEach(result.notes, id: \.self) { note in

                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 0) {
                                Text("Final Dice: ")
                                Text("\(breakdown.final)").bold()
                            }
                            .font(.caption) // End the expanded trace with Final Dice so the arithmetic lands on the answer after all explanation text.
                        }
                        .padding(.top, 4) // Give the expanded trace a little breathing room under the highlighted answer row.
                    }

                }

            }

        } else {
            ForEach(result.validation.reasons, id: \.self) { reason in
                Text(reason)
                    .foregroundStyle(.red)
            }
        }
    }
}
