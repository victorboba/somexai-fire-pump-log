import SwiftUI
import SwiftData

/// One pump: its three clocks, and the tests run against it.
struct PumpView: View {
    @Bindable var pump: Pump
    var autoStartKind: TestKind?

    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview

    @State private var activeTest: PumpTest?
    @State private var editingPump = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var hasAutoStarted = false

    var body: some View {
        List {
            Section {
                Text(pump.nameplateLine).font(.subheadline).foregroundStyle(.secondary)
                if !pump.controllerMake.isEmpty || !pump.controllerModel.isEmpty {
                    Text("Controller: \([pump.controllerMake, pump.controllerModel].filter { !$0.isEmpty }.joined(separator: " "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Start a Test") {
                ForEach(pump.clockKinds) { kind in
                    Button { start(kind) } label: {
                        HStack {
                            Label(kind.name, systemImage: kind.symbol)
                            Spacer()
                            let status = pump.status(kind)
                            Text(status.headline)
                                .font(.caption)
                                .foregroundStyle(status.needsAttention ? .orange : .secondary)
                        }
                    }
                }
            }

            Section {
                ForEach(pump.clockKinds) { kind in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.name).font(.subheadline.weight(.medium))
                        Text(kind.requirement).font(.caption).foregroundStyle(.secondary)
                        Text(kind.cadenceLine(for: pump)).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("What NFPA 25 asks for")
            } footer: {
                Text(AppConfig.judgementDisclaimer)
            }

            Section("History") {
                if pump.sortedTests.isEmpty {
                    Text("Nothing recorded yet.").foregroundStyle(.secondary)
                }
                ForEach(pump.sortedTests) { test in
                    Button { activeTest = test } label: { HistoryRow(test: test) }
                        .buttonStyle(.plain)
                }
                .onDelete(perform: deleteTests)
            }

            if !pump.sortedTests.isEmpty {
                Section {
                    Button { exportHistory() } label: {
                        Label("Pump History (PDF)", systemImage: "doc.richtext")
                    }
                }
            }
        }
        .navigationTitle(pump.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editingPump = true } label: { Label("Pump Details", systemImage: "info.circle") }
            }
        }
        .sheet(item: $activeTest) { test in
            switch test.kind {
            case .noFlow: NoFlowTestView(test: test)
            case .annualFlow: AnnualFlowTestView(test: test)
            case .jockeyAlarm: JockeyAlarmTestView(test: test)
            }
        }
        .sheet(isPresented: $editingPump) { PumpEditorView(pump: pump) }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK") { exportError = nil }
        } message: { Text(exportError ?? "") }
        .onAppear {
            guard !hasAutoStarted, let autoStartKind else { return }
            hasAutoStarted = true
            start(autoStartKind)
        }
    }

    private func start(_ kind: TestKind) {
        let test = PumpTest(kind: kind)
        test.pump = pump
        test.technicianName = UserDefaults.standard.string(forKey: "technician.name") ?? ""
        test.company = UserDefaults.standard.string(forKey: "technician.company") ?? ""
        if kind == .noFlow { test.cadence = pump.churnCadence }
        if kind == .annualFlow { test.seedFlowPoints() }
        context.insert(test)
        try? context.save()
        activeTest = test
    }

    private func deleteTests(_ offsets: IndexSet) {
        let list = pump.sortedTests
        for index in offsets { context.delete(list[index]) }
        try? context.save()
    }

    private func exportHistory() {
        try? context.save()
        do {
            exportFile = ExportFile(url: try PDFExporter.exportHistory(pump))
            ReviewPrompter.recordSuccess(request: requestReview)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct HistoryRow: View {
    let test: PumpTest

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: test.finding.symbol)
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(test.kind.shortName) · \(test.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.weight(.medium))
                Text(test.summaryLine).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if test.kind.needsSignature && test.signature == nil {
                Label("unsigned", systemImage: "signature")
                    .font(.caption2).foregroundStyle(.orange).labelStyle(.titleOnly)
            }
        }
        .padding(.vertical, 2)
    }

    private var tint: Color {
        switch test.finding {
        case .unacceptable: .red
        case .investigate: .orange
        case .satisfactory: .green
        case .notStated: .secondary
        }
    }
}
