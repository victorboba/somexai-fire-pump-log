import SwiftUI
import SwiftData

/// The jockey pump's cut-in and cut-out pressures against its setpoints, and every alarm and
/// supervisory signal the controller is supposed to transmit — made to happen one at a time, and
/// watched until it arrives.
struct JockeyAlarmTestView: View {
    @Bindable var test: PumpTest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var noteFor: AlarmSignal?
    @State private var exportFile: ExportFile?

    private var pump: Pump? { test.pump }
    private var driver: DriverType { test.driver }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(TestKind.jockeyAlarm.requirement).font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    jockeyField("Measured cut-in", $test.jockeyCutInPSI, setpoint: pump?.jockeyCutInSetpointPSI, drift: pump.map { test.jockeyDrift($0).cutIn } ?? nil)
                    jockeyField("Measured cut-out", $test.jockeyCutOutPSI, setpoint: pump?.jockeyCutOutSetpointPSI, drift: pump.map { test.jockeyDrift($0).cutOut } ?? nil)
                } header: {
                    Text("Jockey Pump")
                } footer: {
                    Text("Drift is the measured pressure minus the pump's own setpoint — arithmetic only. Whether the drift is acceptable is your call.")
                }

                Section {
                    Button {
                        for signal in test.signalItems where test.result(signal) == .notChecked {
                            test.set(.ok, for: signal)
                        }
                    } label: {
                        Label("Mark Remaining Signals OK", systemImage: "checkmark.circle.fill")
                    }
                }

                Section {
                    ForEach(test.signalItems) { signal in
                        SignalRow(signal: signal, result: test.result(signal), note: test.note(forKey: signal.rawValue)) { result in
                            test.set(result, for: signal)
                            if result == .fault { noteFor = signal }
                        } editNote: {
                            noteFor = signal
                        }
                    }
                } header: {
                    Text("Alarm & Supervisory Signals")
                } footer: {
                    Text("\(test.checkedSignalCount) of \(test.signalItems.count) checked. Each signal has to actually happen and be watched arriving, not just be assumed wired.")
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
            .navigationTitle("Jockey & Alarm Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() } }
            }
            .sheet(item: $noteFor) { signal in
                ObservationNoteView(title: signal.name, text: test.note(forKey: signal.rawValue)) { text in
                    test.setNote(text, forKey: signal.rawValue)
                }
            }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        }
    }

    private func jockeyField(_ title: String, _ value: Binding<Double?>, setpoint: Double?, drift: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(title) {
                HStack(spacing: 4) {
                    TextField("—", value: value, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    Text("psi").foregroundStyle(.secondary)
                }
            }
            if let setpoint, setpoint > 0 {
                Text("Setpoint \(Reading.pressure(setpoint)) psi" + (drift.map { " · drift \($0 >= 0 ? "+" : "")\(Reading.pressure($0)) psi" } ?? ""))
                    .font(.caption2).foregroundStyle(.secondary)
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
        } else {
            UserDefaults.standard.set(test.technicianName, forKey: "technician.name")
            UserDefaults.standard.set(test.company, forKey: "technician.company")
            WidgetSync.update(with: (try? context.fetch(FetchDescriptor<Pump>())) ?? [])
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

private struct SignalRow: View {
    let signal: AlarmSignal
    let result: ItemResult
    let note: String
    let setResult: (ItemResult) -> Void
    let editNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(signal.name).font(.subheadline.weight(.medium))
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
