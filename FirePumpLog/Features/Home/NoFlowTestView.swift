import SwiftUI
import SwiftData

/// The weekly (or monthly) no-flow test: the pump runs without flowing water, standing in the
/// pump room for two minutes. Diesel pumps carry a second set of readings electric pumps never see.
struct NoFlowTestView: View {
    @Bindable var test: PumpTest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var noteFor: ObservationItem?
    @State private var exportFile: ExportFile?

    private var pump: Pump? { test.pump }
    private var driver: DriverType { test.driver }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(TestKind.noFlow.requirement).font(.caption).foregroundStyle(.secondary)
                    if let pump { Text(TestKind.noFlow.cadenceLine(for: pump)).font(.caption2).foregroundStyle(.secondary) }
                }

                Section {
                    psiField("Suction pressure", $test.suctionPSI)
                    psiField("Discharge pressure", $test.dischargePSI)
                    if let net = test.netPressurePSI {
                        LabeledContent("Net pressure", value: "\(Reading.pressure(net)) psi")
                    }
                    LabeledContent("Time to start") {
                        HStack(spacing: 4) {
                            TextField("—", value: $test.timeToStartSeconds, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            Text("sec").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Ran for") {
                        HStack(spacing: 4) {
                            TextField("—", value: $test.runMinutes, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("noFlow.runMinutes")
                            Text("min").foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Started automatically", isOn: $test.startedAutomatically)
                } header: {
                    Text("Readings")
                } footer: {
                    Text("Leave a field blank if it was not recorded. A blank reading and a reading of zero are shown differently everywhere in this app.")
                }

                if driver.asksEngineReadings {
                    Section {
                        LabeledContent("Fuel level") {
                            HStack(spacing: 4) {
                                TextField("—", value: $test.fuelLevelPercent, format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                Text("%").foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Battery 1") {
                            HStack(spacing: 4) {
                                TextField("—", value: $test.batteryOneVolts, format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                Text("V").foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Battery 2") {
                            HStack(spacing: 4) {
                                TextField("—", value: $test.batteryTwoVolts, format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                Text("V").foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Oil pressure") {
                            HStack(spacing: 4) {
                                TextField("—", value: $test.oilPressurePSI, format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                Text("psi").foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Coolant temperature") {
                            HStack(spacing: 4) {
                                TextField("—", value: $test.coolantTempF, format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                Text("°F").foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Observed speed") {
                            HStack(spacing: 4) {
                                TextField("—", value: $test.observedRPM, format: .number)
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                Text("rpm").foregroundStyle(.secondary)
                            }
                        }
                        Toggle("Reached and held rated speed", isOn: $test.reachedRatedSpeed)
                    } header: {
                        Text("Diesel engine")
                    } footer: {
                        Text("Electric pumps are never asked for these.")
                    }
                }

                Section {
                    Button {
                        for item in test.observationItems where test.result(item) == .notChecked {
                            test.set(.ok, for: item)
                        }
                    } label: {
                        Label("Mark Remaining Observations OK", systemImage: "checkmark.circle.fill")
                    }
                }

                Section {
                    ForEach(ObservationGroup.allCases) { group in
                        let items = ObservationItem.items(for: driver, in: group)
                        if !items.isEmpty {
                            ForEach(items) { item in
                                ObservationRow(item: item, group: group,
                                              result: test.result(item), note: test.note(forKey: item.rawValue)) { result in
                                    test.set(result, for: item)
                                    if result == .fault { noteFor = item }
                                } editNote: {
                                    noteFor = item
                                }
                            }
                        }
                    }
                } header: {
                    Text("Observations")
                }

                Section {
                    ChoiceChips(options: [.satisfactory, .investigate, .unacceptable], selection: $test.finding,
                               title: \.name, tint: findingTint)
                } header: {
                    Text("Your Finding")
                } footer: {
                    Text(AppConfig.judgementDisclaimer)
                }

                if test.finding.isConcern {
                    Section("Corrective Action") {
                        TextField("What needs doing", text: $test.correctiveAction, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }

                Section("Technician") {
                    TextField("Name", text: $test.technicianName)
                    TextField("Company", text: $test.company)
                    DatePicker("Date", selection: $test.date, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Anything else", text: $test.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if test.isComplete {
                    Section {
                        Button { export() } label: { Label("Test Record (PDF)", systemImage: "doc.richtext") }
                    }
                } else if !test.missingPieces.isEmpty {
                    Section {
                        Text("Still needed: \(test.missingPieces.joined(separator: ", ")).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("No-Flow Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() } }
            }
            .sheet(item: $noteFor) { item in
                ObservationNoteView(title: item.name, text: test.note(forKey: item.rawValue)) { text in
                    test.setNote(text, forKey: item.rawValue)
                }
            }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        }
    }

    private func psiField(_ title: String, _ value: Binding<Double?>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("—", value: value, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("noFlow." + title)
                Text("psi").foregroundStyle(.secondary)
            }
        }
    }

    private func findingTint(_ finding: Finding) -> Color {
        switch finding {
        case .unacceptable: .red
        case .investigate: .orange
        case .satisfactory: .green
        case .notStated: .secondary
        }
    }

    private func cancel() {
        if test.isEmpty { context.delete(test) }
        try? context.save()
        dismiss()
    }

    private func save() {
        if test.isEmpty {
            context.delete(test)
        } else if let pump = test.pump {
            UserDefaults.standard.set(test.technicianName, forKey: "technician.name")
            UserDefaults.standard.set(test.company, forKey: "technician.company")
            WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Pump>())) ?? [pump])
        }
        try? context.save()
        if !test.isEmpty { ReviewPrompter.recordSuccess(request: requestReview) }
        dismiss()
    }

    private func export() {
        try? context.save()
        if let url = try? PDFExporter.export(test) { exportFile = ExportFile(url: url) }
    }
}

private struct ObservationRow: View {
    let item: ObservationItem
    let group: ObservationGroup
    let result: ItemResult
    let note: String
    let setResult: (ItemResult) -> Void
    let editNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name).font(.subheadline.weight(.medium))
            ChoiceChips(options: [.ok, .fault, .notApplicable],
                       selection: Binding(get: { result }, set: setResult),
                       title: \.name,
                       tint: { $0 == .fault ? .red : ($0 == .ok ? .green : .secondary) })
            if result == .fault {
                Button(action: editNote) {
                    Label(note.isEmpty ? "Describe what you found" : note,
                          systemImage: note.isEmpty ? "square.and.pencil" : "text.alignleft")
                        .font(.caption).multilineTextAlignment(.leading)
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

/// A short free-text note attached to one item — a fault, an out-of-range flow point, anything
/// that needs more than a chip can say.
struct ObservationNoteView: View {
    let title: String
    @State var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(title) {
                    TextField("What you found", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(text); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
