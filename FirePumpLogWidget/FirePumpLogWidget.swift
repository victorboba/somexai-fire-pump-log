import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct FirePumpLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(AppConfig.appName, systemImage: "gauge.with.dots.needle.33percent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            Text(snapshot.headline)
                .font(.system(size: family == .systemSmall ? 20 : 24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .foregroundStyle(snapshot.overdueCount > 0 ? Color.accentColor : Color.primary)

            if let pump = snapshot.nextPumpName, let test = snapshot.nextTestName {
                Divider()
                Text(pump)
                    .font(.footnote.weight(.medium))
                Text("\(test) · \(snapshot.nextStatusText ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Add a pump to start its clocks.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if family != .systemSmall, snapshot.pumpCount > 0 {
                Spacer(minLength: 0)
                Text(snapshot.pumpCount == 1 ? "1 pump on the board" : "\(snapshot.pumpCount) pumps on the board")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct FirePumpLogWidget: Widget {
    let kind = "FirePumpLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            FirePumpLogWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("Which pump is overdue, and what it is overdue for.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FirePumpLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        FirePumpLogWidget()
    }
}
