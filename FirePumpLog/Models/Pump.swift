import Foundation
import SwiftData

/// One fire pump, and the nameplate everything else in the app is measured against.
///
/// NFPA 25 Chapter 8 does not run one test on a fire pump. It runs a cadence of tests that are
/// shaped differently from one another, and the pump's own nameplate is the yardstick for the
/// biggest of them:
///
/// - **No-flow ("churn") test.** The pump is started and run without flowing water. Suction and
///   discharge pressure are recorded, along with how long it took to start and how long it ran.
///   Electric and diesel drivers have not always been on the same frequency, and an AHJ or an
///   insurer may ask for more, so the cadence is a property of the pump here rather than a
///   constant in the code — and the record says which cadence was in force.
/// - **Annual flow test.** Water is actually flowed, at the churn point and at 100% and 150% of
///   rated capacity, and the readings are compared with the manufacturer's certified curve.
/// - **Jockey pump and alarm checks.** Cut-in and cut-out pressures, and the alarm and
///   supervisory signals the controller is supposed to transmit.
///
/// Everything stored here has a default value and nothing is marked unique, so iCloud sync can be
/// turned on later without a migration.
@Model
final class Pump {
    var id: UUID = UUID()

    // Identity
    var designation: String = ""
    var building: String = ""
    var location: String = ""
    var make: String = ""
    var model: String = ""
    var serialNumber: String = ""
    var installedOn: Date? = nil

    // Nameplate. The annual flow test means nothing without these three numbers.
    var ratedFlowGPM: Double = 0
    var ratedPressurePSI: Double = 0
    var ratedRPM: Double = 0

    // Driver. This decides which fields the tests ask for.
    var driverRaw: String = DriverType.electric.rawValue
    var controllerMake: String = ""
    var controllerModel: String = ""

    /// Set per pump rather than hard-coded, because the required no-flow frequency has moved
    /// between weekly and monthly depending on driver, supervision and edition.
    var churnCadenceRaw: String = ChurnCadence.weekly.rawValue

    // Jockey (pressure maintenance) pump, where one is fitted.
    var hasJockeyPump: Bool = true
    var jockeyCutInSetpointPSI: Double = 0
    var jockeyCutOutSetpointPSI: Double = 0

    @Attribute(.externalStorage) var photoData: Data? = nil
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \PumpTest.pump)
    var tests: [PumpTest]? = nil

    var createdAt: Date = Date()

    init(designation: String = "", make: String = "", model: String = "") {
        self.id = UUID()
        self.designation = designation
        self.make = make
        self.model = model
        self.createdAt = .now
    }

    var driver: DriverType {
        get { DriverType(rawValue: driverRaw) ?? .electric }
        set { driverRaw = newValue.rawValue }
    }

    var churnCadence: ChurnCadence {
        get { ChurnCadence(rawValue: churnCadenceRaw) ?? .weekly }
        set { churnCadenceRaw = newValue.rawValue }
    }

    var title: String {
        let name = designation.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unnamed pump" : name
    }

    var whereItIs: String {
        [building, location].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// "1500 gpm · 125 psi · 1760 rpm · Diesel", the strip that sits under the pump's name.
    var nameplateLine: String {
        var parts: [String] = []
        if ratedFlowGPM > 0 { parts.append("\(Reading.whole(ratedFlowGPM)) gpm") }
        if ratedPressurePSI > 0 { parts.append("\(Reading.whole(ratedPressurePSI)) psi") }
        if ratedRPM > 0 { parts.append("\(Reading.whole(ratedRPM)) rpm") }
        parts.append(driver.name)
        return parts.joined(separator: "  ·  ")
    }

    var hasNameplate: Bool { ratedFlowGPM > 0 && ratedPressurePSI > 0 }

    var sortedTests: [PumpTest] {
        (tests ?? []).sorted { $0.date > $1.date }
    }

    func tests(_ kind: TestKind) -> [PumpTest] {
        sortedTests.filter { $0.kind == kind }
    }

    func latest(_ kind: TestKind) -> PumpTest? {
        tests(kind).first
    }

    /// The kinds that run on a clock, in the order the due board shows them.
    var clockKinds: [TestKind] {
        hasJockeyPump ? TestKind.scheduled : TestKind.scheduled.filter { $0 != .jockeyAlarm }
    }

    func nextDue(_ kind: TestKind, from last: Date) -> Date? {
        switch kind {
        case .noFlow:
            return churnCadence.next(after: last)
        case .annualFlow, .jockeyAlarm:
            return Calendar.current.date(byAdding: .month, value: 12, to: last)
        }
    }

    func nextDue(_ kind: TestKind) -> Date? {
        guard let last = latest(kind)?.date else { return nil }
        return nextDue(kind, from: last)
    }

    func status(_ kind: TestKind, asOf today: Date = .now) -> DueStatus {
        guard let due = nextDue(kind) else { return .neverRun }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: today),
                                           to: calendar.startOfDay(for: due)).day ?? 0
        if days < 0 { return .overdue(byDays: -days) }
        if days == 0 { return .dueToday }
        if days <= kind.warnWithinDays(for: self) { return .dueSoon(inDays: days) }
        return .scheduled(inDays: days)
    }

    /// Every clock this pump runs, worst first. An engineer with four pumps reads the board in
    /// this order and nothing else.
    func clocks(asOf today: Date = .now) -> [(kind: TestKind, status: DueStatus)] {
        clockKinds.map { ($0, status($0, asOf: today)) }
            .sorted { lhs, rhs in
                if lhs.1.urgency != rhs.1.urgency { return lhs.1.urgency > rhs.1.urgency }
                return lhs.0.order < rhs.0.order
            }
    }

    func worstStatus(asOf today: Date = .now) -> DueStatus {
        clocks(asOf: today).first?.status ?? .neverRun
    }

    /// The label for the pump card: the clock that needs attention first, named.
    func headline(asOf today: Date = .now) -> String {
        guard let first = clocks(asOf: today).first else { return "No tests scheduled" }
        return "\(first.kind.shortName): \(first.status.headline)"
    }
}

// MARK: - The vocabulary

enum DriverType: String, CaseIterable, Identifiable {
    case electric, diesel
    var id: String { rawValue }

    var name: String { self == .electric ? "Electric motor" : "Diesel engine" }
    var shortName: String { self == .electric ? "Electric" : "Diesel" }
    var symbol: String { self == .electric ? "bolt.fill" : "fuelpump.fill" }

    /// Diesel drivers bring a whole second set of readings with them: the engine has fuel,
    /// batteries, oil and coolant, and an electric motor has none of those.
    var asksEngineReadings: Bool { self == .diesel }
}

enum ChurnCadence: String, CaseIterable, Identifiable {
    case weekly, monthly
    var id: String { rawValue }

    var name: String { self == .weekly ? "Weekly" : "Monthly" }

    var everyLabel: String { self == .weekly ? "every 7 days" : "every month" }

    func next(after date: Date) -> Date? {
        switch self {
        case .weekly: return Calendar.current.date(byAdding: .day, value: 7, to: date)
        case .monthly: return Calendar.current.date(byAdding: .month, value: 1, to: date)
        }
    }

    var warnWithinDays: Int { self == .weekly ? 2 : 7 }
}

enum DueStatus: Equatable {
    case neverRun
    case overdue(byDays: Int)
    case dueToday
    case dueSoon(inDays: Int)
    case scheduled(inDays: Int)

    var headline: String {
        switch self {
        case .neverRun: return "Never run"
        case .overdue(let days): return days == 1 ? "Overdue by 1 day" : "Overdue by \(days) days"
        case .dueToday: return "Due today"
        case .dueSoon(let days): return days == 1 ? "Due tomorrow" : "Due in \(days) days"
        case .scheduled(let days):
            if days >= 60 { return "Due in \(days / 30) months" }
            return "Due in \(days) days"
        }
    }

    /// The compact form used inside a clock pill, where the whole sentence will not fit.
    var pillText: String {
        switch self {
        case .neverRun: return "never"
        case .overdue(let days): return days >= 60 ? "\(days / 30) mo late" : "\(days) d late"
        case .dueToday: return "today"
        case .dueSoon(let days): return "\(days) d"
        case .scheduled(let days): return days >= 60 ? "\(days / 30) mo" : "\(days) d"
        }
    }

    var urgency: Int {
        switch self {
        case .overdue: return 4
        case .neverRun: return 3
        case .dueToday: return 2
        case .dueSoon: return 1
        case .scheduled: return 0
        }
    }

    var needsAttention: Bool { urgency >= 2 }
}

/// Formatting helpers shared by the screens, the PDF and the CSV so a number never reads one way
/// on screen and another on the record.
enum Reading {
    static func whole(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Pressures are read off a gauge to at most one decimal, and a trailing ".0" is noise.
    static func pressure(_ value: Double) -> String {
        value == value.rounded() ? whole(value) : oneDecimal(value)
    }

    static func percent(_ value: Double) -> String {
        "\(oneDecimal(value))%"
    }

    /// A reading that was never taken prints as an em dash, never as a zero. On a pressure
    /// record those are two different statements.
    static func optional(_ value: Double?) -> String {
        guard let value else { return "—" }
        return pressure(value)
    }

    static func optionalPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return percent(value)
    }
}
