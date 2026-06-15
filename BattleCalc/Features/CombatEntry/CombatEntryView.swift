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
    @StateObject private var vm = CombatEntryViewModel()
    // Once a unit type is chosen, that side collapses to a single colored
    // unit-type summary row. Tapping the summary flips the matching flag back on
    // to re-expand Country / Unit class / Unit type for editing.
    @State private var editingAttacker = false
    @State private var editingDefender = false
    // Battle-wide extras (range/mode) collapse into a compact summary too.
    @State private var editingExtras = false
    #if DEBUG
    @State private var showDebug = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                attackerSection
                if vm.attackerTerrain != nil { defenderSection }
                // PLAYTEST: distance now lives inline in the attacker flow
                // (`targetDistanceRow`), so the standalone extras section is not
                // shown. To revert to the old "Battle details" placement, restore
                // `if vm.defenderTerrain != nil { extrasSection }` here and remove
                // the `targetDistanceRow` call in `attackerSection`.
                if vm.result != nil { resultSection }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Combat")
            .safeAreaInset(edge: .bottom) { debugBar }
            #if DEBUG
            .sheet(isPresented: $showDebug) {
                CombatEntryDebugView(trace: vm.lastTrace, context: vm.buildContext())
            }
            #endif
        }
    }

    // MARK: - Attacker
    @ViewBuilder private var attackerSection: some View {
        Section("Attacker") {
            if let unit = vm.attackerUnit, vm.attackerComplete, !editingAttacker {
                // Fully collapsed: one colored box with unit type + blocks /
                // moved / terrain chips. Separate rows below are hidden.
                SideSummaryRow(unit: unit, countryID: vm.attackerCountry?.id,
                               detail: vm.attackerSummaryDetail) {
                    editingAttacker = true
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
                    CombatBlocksRow(label: "Blocks", value: vm.attackerBlocks ?? vm.attackerMaxBlocks,
                                    maxBlocks: vm.attackerMaxBlocks) { vm.attackerBlocks = $0 }
                }
                if vm.attackerBlocks != nil {
                    CombatMovedRow(label: "Moved This Turn?", hexes: vm.attackerMovedHexes,
                                   maxMoved: vm.attackerMaxBlocks) { vm.attackerMovedHexes = $0 }
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
                    // Selecting it completes the side, which auto-collapses it.
                    CombatDisclosureRow(label: "Terrain (fires from)", selection: vm.attackerTerrain,
                                        options: vm.terrainOptions) {
                        vm.attackerTerrain = $0
                        editingAttacker = false
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
                // terrain chips (defender has no movement).
                SideSummaryRow(unit: unit, countryID: vm.defenderCountry?.id,
                               detail: vm.defenderSummaryDetail) {
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
                    CombatBlocksRow(label: "Blocks", value: vm.defenderBlocks ?? vm.defenderMaxBlocks,
                                    maxBlocks: vm.defenderMaxBlocks) { vm.defenderBlocks = $0 }
                }
                if vm.defenderBlocks != nil {
                    // Terrain the defender OCCUPIES — chosen independently because
                    // the two units are at least one hex apart. Completing it
                    // auto-collapses this side.
                    CombatDisclosureRow(label: "Terrain (occupies)", selection: vm.defenderTerrain,
                                        options: vm.terrainOptions) {
                        vm.defenderTerrain = $0
                        editingDefender = false
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
        Stepper(value: Binding(get: { vm.targetDistance },
                               set: { vm.targetDistance = $0 }), in: 1...4) {
            LabeledContent("Range to target (hexes)", value: "\(vm.targetDistance)")
        }
        Text(vm.targetDistance == 1 ? "Adjacent — resolved as melee."
                                    : "\(vm.targetDistance) hexes — resolved as ranged fire.")
            .font(.caption)
            .foregroundStyle(.secondary)
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

    var body: some View {
        if breakdown.isTrivial {
            // No modifiers and base == final: one line is enough.
            HStack(spacing: 0) {
                Text("\(breakdown.mode): Final Dice: ")
                Text("\(breakdown.final)").bold()
            }
            .font(.subheadline)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Base Dice: \(breakdown.baseBlocks) block\(breakdown.baseBlocks == 1 ? "" : "s")")
                    .font(.caption)

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

                HStack(spacing: 0) {
                    Text("Final Dice: ")
                    Text("\(breakdown.final)").bold()
                }
                .font(.subheadline)
                .padding(.top, 1)
            }
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
    }
}

/// Collapsed summary for a whole side. Stands in for Country + Unit class +
/// Unit type + Blocks + (Moved) + Terrain once the side is complete: the unit
/// type as the title with a compact detail line (e.g. "4 blocks • Moved 1 hex •
/// Clear"), tinted to the unit's country (gray fallback). Tapping re-expands
/// every field with its current value preselected. Image-ready via
/// CombatPickRowContent.
struct SideSummaryRow: View {
    let unit: CombatPickItem
    let countryID: String?
    let detail: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    CombatPickRowContent(item: unit)
                    if !detail.isEmpty {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.tertiary)
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
/// is always a bounded stepper. Shows "N / max" and clamps to 1...maxBlocks.
struct CombatBlocksRow: View {
    let label: String
    let value: Int
    let maxBlocks: Int
    let onChange: (Int) -> Void

    var body: some View {
        let upper = max(1, maxBlocks)
        Stepper(value: Binding(get: { value }, set: { onChange($0) }), in: 1...upper) {
            LabeledContent(label, value: "\(value) / \(upper)")
        }
    }
}

/// Moved entry, prompted as "Moved This Turn?". First choice is No/Yes; "Yes"
/// stores 1 hex and reveals a stepper for the exact number of hexes moved (maps
/// to movedHexes). Boolean/hex behavior is unchanged — only the label differs.
struct CombatMovedRow: View {
    let label: String
    let hexes: Int?
    let maxMoved: Int
    let onChange: (Int) -> Void

    var body: some View {
        if let h = hexes {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(label, isOn: Binding(get: { h > 0 },
                                            set: { onChange($0 ? max(1, h) : 0) }))
                if h > 0 {
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
