import SwiftUI
import SwiftData

/// The annual flow test: churn, 100% and 150% of rated flow, each point judged against the
/// manufacturer's nameplate curve.
///
/// This is the screen the app exists to build. Three points, each with its own card, each showing
/// its net pressure and its percentage of the nameplate as soon as the technician types a number —
/// arithmetic on their own readings, computed live, never a verdict.
struct AnnualFlowTestView: View {
    @Bindable var test: PumpTest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var exportFile: ExportFile?

    private var pump: Pump? { test.pump }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(TestKind.annualFlow.requirement).font(.caption).foregroundStyle(.secondary)
                    if let pump { Text(pump.nameplateLine).font(.caption2).foregroundStyle(.secondary) }
                }

                ForEach(FlowPosition.allCases) { position in
                    if let point = test.point(position) {
                        Section {
                            FlowPointCard(point: point, pump: pump, position: position)
                        } header: {
                            Text(position.name)
                        } footer: {
                            Text(position.curveNote)
                        }
                    }
                }

                if let summary = test.overloadSummary {
                    Section {
                        Label(summary, systemImage: "chart.xyaxis.line")
                            .font(.subheadline.weight(.semibold))
                    } footer: {
                        Text(AppConfig.judgementDisclaimer)
                    }
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

                Section {
                    SignaturePad(data: $test.signature, name: test.technicianName)
                } header: {
                    Text("Signature")
                } footer: {
                    Text("An annual flow test is a signed record. The record is not complete without a name and a signature.")
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
            .navigationTitle("Annual Flow Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() } }
            }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        }
        .onAppear { test.seedFlowPoints() }
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

/// One row of the flow table: the readings on the left, the arithmetic on the right, updating as
/// soon as a number lands. `position == .churn` has no flow by definition, so its flow field and
/// percent-of-capacity figure are left out rather than shown as a confusing 0%.
private struct FlowPointCard: View {
    @Bindable var point: FlowPoint
    let pump: Pump?
    let position: FlowPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let pump, let target = point.targetFlow(pump: pump), position != .churn {
                Text("Target ≈ \(Reading.whole(target)) gpm")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if position != .churn {
                field("Flow", $point.flowGPM, unit: "gpm", id: "flow.\(position.rawValue).flow")
            }
            field("Suction pressure", $point.suctionPSI, unit: "psi", id: "flow.\(position.rawValue).suction")
            field("Discharge pressure", $point.dischargePSI, unit: "psi", id: "flow.\(position.rawValue).discharge")
            field("Speed", $point.rpm, unit: "rpm", id: "flow.\(position.rawValue).rpm")

            if point.hasReadings {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    if let net = point.netPressurePSI {
                        readout("Net pressure", "\(Reading.pressure(net)) psi")
                    }
                    if let pump, position != .churn, let percentCapacity = point.percentOfRatedCapacity(pump: pump) {
                        readout("% of rated capacity", Reading.percent(percentCapacity))
                    }
                    if let pump, let percentCurve = point.percentOfNameplateCurve(pump: pump) {
                        readout("% of nameplate at this point", Reading.percent(percentCurve))
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func field(_ title: String, _ value: Binding<Double?>, unit: String, id: String) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("—", value: value, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .accessibilityIdentifier(id)
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }

    private func readout(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
        }
    }
}
