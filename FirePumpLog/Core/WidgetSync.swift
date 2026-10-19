import Foundation
import WidgetKit

enum WidgetSync {
    /// Recomputes the widget summary from the current pumps and reloads timelines.
    static func update(with pumps: [Pump], asOf today: Date = .now) {
        var snapshot = WidgetSnapshot()
        snapshot.pumpCount = pumps.count
        snapshot.overdueCount = pumps.filter { $0.worstStatus(asOf: today).needsAttention }.count

        let worst = pumps
            .compactMap { pump -> (Pump, TestKind, DueStatus)? in
                guard let clock = pump.clocks(asOf: today).first else { return nil }
                return (pump, clock.kind, clock.status)
            }
            .max { lhs, rhs in lhs.2.urgency < rhs.2.urgency }

        if let worst {
            snapshot.nextPumpName = worst.0.title
            snapshot.nextTestName = worst.1.shortName
            snapshot.nextStatusText = worst.2.headline
            snapshot.nextDueDate = worst.0.nextDue(worst.1)
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
