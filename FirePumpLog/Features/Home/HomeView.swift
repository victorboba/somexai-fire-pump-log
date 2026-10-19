import SwiftUI
import SwiftData

/// The due board: every pump's three clocks at once, worst pump first.
///
/// A building engineer with four pumps does not want a list of records — they want to know which
/// pump needs something today. So the board sorts pumps by their worst clock, and each row shows
/// all three clocks side by side rather than hiding two of them behind a tap.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Pump.designation) private var pumps: [Pump]

    @State private var openPump: Pump?
    @State private var editingPump: Pump?
    @State private var autoStartKind: TestKind?
    @State private var showingSettings = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var sortedPumps: [Pump] {
        pumps.sorted { $0.worstStatus().urgency > $1.worstStatus().urgency }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pumps.isEmpty {
                    ContentUnavailableView {
                        Label("No Pumps Yet", systemImage: "gauge.with.dots.needle.33percent")
                    } description: {
                        Text("Add a pump and the board starts its no-flow, annual flow and jockey/alarm clocks.")
                    } actions: {
                        Button("Add a Pump") { addPump() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(sortedPumps) { pump in
                            Button { openPump = pump } label: { PumpRow(pump: pump) }
                                .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle(AppConfig.appName)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { HowToView() } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("How do I use this app")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { addPump() } label: { Label("Add a Pump", systemImage: "plus") }
                        if !pumps.isEmpty {
                            Button { exportCSV() } label: { Label("Every Test as CSV", systemImage: "tablecells") }
                        }
                        Divider()
                        Button { showingSettings = true } label: { Label("Settings", systemImage: "gear") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
            .navigationDestination(item: $openPump) { pump in
                PumpView(pump: pump, autoStartKind: autoStartKind)
                    .onDisappear { autoStartKind = nil }
            }
            .sheet(item: $editingPump) { PumpEditorView(pump: $0) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
        }
        .task { WidgetSync.update(with: pumps) }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            openWorstPumpIfRequestedByShortcut()
        }
    }

    private func addPump() {
        let pump = Pump()
        context.insert(pump)
        try? context.save()
        editingPump = pump
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(sortedPumps[index]) }
        try? context.save()
        WidgetSync.update(with: pumps)
    }

    private func exportCSV() {
        do { exportFile = ExportFile(url: try CSVExporter.export(pumps)) }
        catch { exportError = error.localizedDescription }
    }

    /// "Start a no-flow test in Fire Pump Log", from Siri, Spotlight or the widget: open the pump
    /// whose clocks are worst, ready on its no-flow test.
    private func openWorstPumpIfRequestedByShortcut() {
        let defaults = WidgetSnapshot.defaults
        guard defaults.bool(forKey: StartNoFlowTestIntent.pendingKey) else { return }
        defaults.removeObject(forKey: StartNoFlowTestIntent.pendingKey)
        guard let worst = sortedPumps.first else { return }
        autoStartKind = .noFlow
        openPump = worst
    }
}

private struct PumpRow: View {
    let pump: Pump

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pump.title).font(.headline)
            if !pump.whereItIs.isEmpty {
                Text(pump.whereItIs).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(pump.nameplateLine).font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(pump.clocks(), id: \.kind) { clock in
                    ClockChip(kind: clock.kind, status: clock.status)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ClockChip: View {
    let kind: TestKind
    let status: DueStatus

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: kind.symbol).font(.caption)
            Text(kind.shortName).font(.caption2.weight(.medium))
            Text(status.pillText).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(tint)
    }

    private var tint: Color {
        switch status {
        case .overdue, .neverRun: .red
        case .dueToday, .dueSoon: .orange
        case .scheduled: .green
        }
    }
}
