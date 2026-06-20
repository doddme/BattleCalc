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
    @State private var editingAttackDetails = true
    @State private var editingDefender = true
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
                if vm.attackerComplete && !editingAttacker {
                    attackDetailsSection
                }
                if vm.attackDetailsComplete && !editingAttacker && !editingAttackDetails {
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
            Text("Ancients draft: core dice are available. Support, Evade, retreats, and some post-roll reminders still need review.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var attackerSection: some View {
        Section("Attacker") {
            if let unit = vm.attackerUnit, vm.attackerComplete, !editingAttacker {
                SideSummaryRow(unit: unit, countryID: nil, detail: vm.attackerSummaryDetail) {
                    editingAttacker = true
                    editingAttackDetails = true
                    editingDefender = true
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
                    CombatDisclosureRow(label: "Terrain (occupies)", selection: vm.attackerTerrain, options: vm.terrainOptions) {
                        vm.attackerTerrain = $0
                        editingAttacker = false
                    }
                }
            }
        }
    }

    private var attackDetailsSection: some View {
        Section("Attack") {
            if !editingAttackDetails {
                Button { editingAttackDetails = true } label: {
                    HStack {
                        Text("Range").foregroundStyle(.secondary)
                        Spacer()
                        Text(vm.attackSummaryDetail)
                        Image(systemName: "chevron.down").font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Stepper(value: $vm.targetDistance, in: 1...6) {
                    LabeledContent("Distance to target", value: "\(vm.targetDistance) hex\(vm.targetDistance == 1 ? "" : "es")")
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
                Button("Done") { editingAttackDetails = false }
            }
        }
    }

    private var defenderSection: some View {
        Section("Defender") {
            if let unit = vm.defenderUnit, vm.defenderComplete, !editingDefender {
                SideSummaryRow(unit: unit, countryID: nil, detail: vm.defenderSummaryDetail) {
                    editingDefender = true
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
                        editingDefender = false
                    }
                }
            }
        }
    }

    private var battleBackSection: some View {
        Section("After Close Combat") {
            Text("Battle Back happens only if the defender survived and did not retreat out of its hex. If the defender was eliminated or forced to retreat, check Momentum Advance instead.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Was defender eliminated or forced to retreat?")
                Spacer()
                Button("No") { vm.setDefenderStayedInHex(true) }
                    .buttonStyle(.bordered)
                Button("Yes") { vm.setDefenderStayedInHex(false) }
                    .buttonStyle(.borderedProminent)
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
        editingAttackDetails = true
        editingDefender = true
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

private struct AncientsResultRows: View {
    let result: CombatResult
    @State private var showingLeaderInfo = false

    var body: some View {
        if result.validation.isAllowed {
            if let baseDice = result.baseDice, let finalDice = result.finalDice {
                LabeledContent("Base dice", value: "\(baseDice)")
                LabeledContent("Final dice", value: "\(finalDice)")
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
                .padding(.vertical, 2)
            }
            .sheet(isPresented: $showingLeaderInfo) {
                AncientsLeaderInfoSheet()
            }
            ForEach(result.notes, id: \.self) { note in
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(result.validation.reasons, id: \.self) { reason in
                Text(reason)
                    .foregroundStyle(.red)
            }
        }
    }
}
