import Foundation
import SwiftData

/// One test of one pump, at one of the three cadences NFPA 25 Chapter 8 runs.
///
/// The three are deliberately different shapes rather than one checklist wearing three hats:
/// the no-flow test is a handful of readings taken in two minutes standing in a pump room, the
/// annual flow test is a small table of readings at several points on the pump's curve, and the
/// jockey and alarm check is a set of signals plus two setpoints.
///
/// Every reading is an optional. On a pressure record "not recorded" and "zero psi" are two
/// different statements, and a suction gauge reading zero is an ordinary thing to write down, so
/// the model refuses to collapse them into one another.
///
/// The app computes arithmetic on the numbers the technician entered — a net pressure is a
/// subtraction, a percentage is a division — and stops there. Whether the pump is acceptable is
/// the technician's own call, recorded in `finding`, and the app neither makes it nor overrides it.
@Model
final class PumpTest {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = TestKind.noFlow.rawValue

    /// The cadence that was in force when this no-flow test was run, recorded on the test so a
    /// history still reads correctly after somebody changes the pump's cadence.
    var cadenceRaw: String = ChurnCadence.weekly.rawValue

    var technicianName: String = ""
    var company: String = ""

    // MARK: No-flow readings
    var suctionPSI: Double? = nil
    var dischargePSI: Double? = nil
    var timeToStartSeconds: Double? = nil
    var runMinutes: Double? = nil
    var startedAutomatically: Bool = true

    // MARK: Diesel-only readings. An electric pump is never asked for any of these.
    var fuelLevelPercent: Double? = nil
    var batteryOneVolts: Double? = nil
    var batteryTwoVolts: Double? = nil
    var oilPressurePSI: Double? = nil
    var coolantTempF: Double? = nil
    var observedRPM: Double? = nil
    var reachedRatedSpeed: Bool = true

    // MARK: Jockey pump setpoints, as measured
    var jockeyCutInPSI: Double? = nil
    var jockeyCutOutPSI: Double? = nil

    /// Observation items and alarm signals, keyed by their raw value.
    var observationsRaw: [String: String] = [:]
    var signalsRaw: [String: String] = [:]
    var itemNotes: [String: String] = [:]

    /// The technician's own call. Nothing in the app sets this.
    var findingRaw: String = Finding.notStated.rawValue
    var correctiveAction: String = ""
    var notes: String = ""

    /// NFPA 25 records are signed documents, so the annual test carries a real signature.
    @Attribute(.externalStorage) var signature: Data? = nil
    @Attribute(.externalStorage) var photoData: Data? = nil

    @Relationship(deleteRule: .cascade, inverse: \FlowPoint.test)
    var flowPoints: [FlowPoint]? = nil

    var pump: Pump? = nil

    init(date: Date = .now, kind: TestKind = .noFlow) {
        self.id = UUID()
        self.date = date
        self.kindRaw = kind.rawValue
    }

    var kind: TestKind {
        get { TestKind(rawValue: kindRaw) ?? .noFlow }
        set { kindRaw = newValue.rawValue }
    }

    var cadence: ChurnCadence {
        get { ChurnCadence(rawValue: cadenceRaw) ?? .weekly }
        set { cadenceRaw = newValue.rawValue }
    }

    var finding: Finding {
        get { Finding(rawValue: findingRaw) ?? .notStated }
        set { findingRaw = newValue.rawValue }
    }

    var driver: DriverType { pump?.driver ?? .electric }

    // MARK: - No-flow arithmetic

    /// Discharge minus suction: the pressure the pump itself is making, which is the only number
    /// on a churn test that means anything on its own.
    var netPressurePSI: Double? {
        FlowMath.netPressure(discharge: dischargePSI, suction: suctionPSI)
    }

    /// How far the measured jockey setpoints sit from the ones written on the pump's profile.
    /// A subtraction, printed next to both numbers, and nothing else.
    func jockeyDrift(_ pump: Pump) -> (cutIn: Double?, cutOut: Double?) {
        let cutIn = jockeyCutInPSI.flatMap { pump.jockeyCutInSetpointPSI > 0 ? $0 - pump.jockeyCutInSetpointPSI : nil }
        let cutOut = jockeyCutOutPSI.flatMap { pump.jockeyCutOutSetpointPSI > 0 ? $0 - pump.jockeyCutOutSetpointPSI : nil }
        return (cutIn, cutOut)
    }

    // MARK: - The observation list and the alarm list

    var observationItems: [ObservationItem] { ObservationItem.items(for: driver) }
    var signalItems: [AlarmSignal] { AlarmSignal.items(for: driver) }

    func result(_ item: ObservationItem) -> ItemResult {
        ItemResult(rawValue: observationsRaw[item.rawValue] ?? "") ?? .notChecked
    }

    func set(_ result: ItemResult, for item: ObservationItem) {
        observationsRaw[item.rawValue] = result.rawValue
    }

    func result(_ signal: AlarmSignal) -> ItemResult {
        ItemResult(rawValue: signalsRaw[signal.rawValue] ?? "") ?? .notChecked
    }

    func set(_ result: ItemResult, for signal: AlarmSignal) {
        signalsRaw[signal.rawValue] = result.rawValue
    }

    func note(forKey key: String) -> String { itemNotes[key] ?? "" }

    func setNote(_ text: String, forKey key: String) {
        if text.isEmpty { itemNotes.removeValue(forKey: key) } else { itemNotes[key] = text }
    }

    var faultedObservations: [ObservationItem] {
        observationItems.filter { result($0) == .fault }
    }

    var faultedSignals: [AlarmSignal] {
        signalItems.filter { result($0) == .fault }
    }

    var checkedSignalCount: Int {
        signalItems.filter { result($0) != .notChecked }.count
    }

    // MARK: - The annual flow test

    var sortedFlowPoints: [FlowPoint] {
        (flowPoints ?? []).sorted { $0.position.order < $1.position.order }
    }

    /// Creates the churn, 100% and 150% rows the annual test is made of, with the target flow at
    /// each already worked out from the nameplate so the technician is not doing sums on a wall.
    func seedFlowPoints() {
        guard (flowPoints ?? []).isEmpty else { return }
        var seeded: [FlowPoint] = []
        for position in FlowPosition.allCases {
            let point = FlowPoint(position: position)
            point.test = self
            seeded.append(point)
        }
        flowPoints = seeded
    }

    var pointsWithReadings: [FlowPoint] {
        sortedFlowPoints.filter(\.hasReadings)
    }

    func point(_ position: FlowPosition) -> FlowPoint? {
        sortedFlowPoints.first { $0.position == position }
    }

    /// The one line a chief engineer reads first: what the pump made at 150% of rated flow, as a
    /// percentage of its nameplate. Arithmetic on entered numbers, labelled as such.
    var overloadSummary: String? {
        guard let pump,
              let point = point(.overload),
              let percent = point.percentOfNameplateCurve(pump: pump) else { return nil }
        return "\(Reading.oneDecimal(percent))% of nameplate at 150% of rated flow"
    }

    // MARK: - Completeness

    /// A record the app is willing to call finished. The annual test is a signed document, so it
    /// is not finished without a name and a signature on it.
    var isComplete: Bool {
        switch kind {
        case .noFlow:
            return dischargePSI != nil && suctionPSI != nil && runMinutes != nil
        case .annualFlow:
            return !pointsWithReadings.isEmpty && signature != nil && !technicianName.isEmpty
        case .jockeyAlarm:
            return checkedSignalCount == signalItems.count
                && jockeyCutInPSI != nil && jockeyCutOutPSI != nil
        }
    }

    /// What is still missing, said plainly, so the screen never just refuses to finish.
    var missingPieces: [String] {
        var missing: [String] = []
        switch kind {
        case .noFlow:
            if suctionPSI == nil { missing.append("suction pressure") }
            if dischargePSI == nil { missing.append("discharge pressure") }
            if runMinutes == nil { missing.append("how long it ran") }
        case .annualFlow:
            if pointsWithReadings.isEmpty { missing.append("readings at a flow point") }
            if technicianName.isEmpty { missing.append("the technician's name") }
            if signature == nil { missing.append("a signature") }
        case .jockeyAlarm:
            if jockeyCutInPSI == nil { missing.append("the measured cut-in pressure") }
            if jockeyCutOutPSI == nil { missing.append("the measured cut-out pressure") }
            let unchecked = signalItems.count - checkedSignalCount
            if unchecked > 0 {
                missing.append(unchecked == 1 ? "1 alarm signal" : "\(unchecked) alarm signals")
            }
        }
        return missing
    }

    /// Nothing was entered at all, so closing the screen should throw the record away rather
    /// than leave a blank test in a legal file.
    var isEmpty: Bool {
        switch kind {
        case .noFlow:
            return suctionPSI == nil && dischargePSI == nil && runMinutes == nil
                && timeToStartSeconds == nil && observationsRaw.isEmpty
                && notes.isEmpty && finding == .notStated
        case .annualFlow:
            return pointsWithReadings.isEmpty && notes.isEmpty && technicianName.isEmpty
                && signature == nil && finding == .notStated
        case .jockeyAlarm:
            return signalsRaw.isEmpty && jockeyCutInPSI == nil && jockeyCutOutPSI == nil
                && notes.isEmpty && finding == .notStated
        }
    }

    var summaryLine: String {
        switch kind {
        case .noFlow:
            var parts = ["\(Reading.optional(suctionPSI)) / \(Reading.optional(dischargePSI)) psi"]
            if let net = netPressurePSI { parts.append("net \(Reading.pressure(net)) psi") }
            if let minutes = runMinutes { parts.append("ran \(Reading.pressure(minutes)) min") }
            return parts.joined(separator: "  ·  ")
        case .annualFlow:
            if let summary = overloadSummary { return summary }
            return "\(pointsWithReadings.count) of 3 flow points recorded"
        case .jockeyAlarm:
            var parts: [String] = []
            if jockeyCutInPSI != nil || jockeyCutOutPSI != nil {
                parts.append("cut-in \(Reading.optional(jockeyCutInPSI)), cut-out \(Reading.optional(jockeyCutOutPSI)) psi")
            }
            if checkedSignalCount > 0 {
                parts.append("\(checkedSignalCount) of \(signalItems.count) signals checked")
            }
            return parts.isEmpty ? "Nothing recorded yet" : parts.joined(separator: "  ·  ")
        }
    }
}

/// One row of the annual flow test: what the pump did at one point on its curve.
@Model
final class FlowPoint {
    var id: UUID = UUID()
    var positionRaw: String = FlowPosition.churn.rawValue
    var flowGPM: Double? = nil
    var suctionPSI: Double? = nil
    var dischargePSI: Double? = nil
    var rpm: Double? = nil
    var test: PumpTest? = nil

    init(position: FlowPosition = .churn) {
        self.id = UUID()
        self.positionRaw = position.rawValue
    }

    var position: FlowPosition {
        get { FlowPosition(rawValue: positionRaw) ?? .churn }
        set { positionRaw = newValue.rawValue }
    }

    var hasReadings: Bool { dischargePSI != nil || suctionPSI != nil || flowGPM != nil }

    /// Discharge minus suction. Under a vacuum the suction reading is negative and the net
    /// pressure gets larger, not smaller, which is why this is a subtraction and never an
    /// absolute difference.
    var netPressurePSI: Double? {
        FlowMath.netPressure(discharge: dischargePSI, suction: suctionPSI)
    }

    func percentOfRatedCapacity(pump: Pump) -> Double? {
        FlowMath.percentOfRated(value: flowGPM, rated: pump.ratedFlowGPM)
    }

    func percentOfRatedPressure(pump: Pump) -> Double? {
        FlowMath.percentOfRated(value: netPressurePSI, rated: pump.ratedPressurePSI)
    }

    /// The net pressure as a percentage of what this pump's nameplate holds at this point on the
    /// curve. A reference figure and a division, nothing more.
    func percentOfNameplateCurve(pump: Pump) -> Double? {
        FlowMath.percentOfCurve(net: netPressurePSI,
                                ratedPressure: pump.ratedPressurePSI,
                                curvePercent: position.curvePressurePercent)
    }

    func targetFlow(pump: Pump) -> Double? {
        guard pump.ratedFlowGPM > 0 else { return nil }
        return pump.ratedFlowGPM * position.capacityPercent / 100
    }

    func nameplatePressure(pump: Pump) -> Double? {
        guard pump.ratedPressurePSI > 0 else { return nil }
        return pump.ratedPressurePSI * position.curvePressurePercent / 100
    }
}

/// The arithmetic, kept out of SwiftData so it can be reasoned about and tested on its own.
enum FlowMath {
    static func netPressure(discharge: Double?, suction: Double?) -> Double? {
        guard let discharge, let suction else { return nil }
        return discharge - suction
    }

    static func percentOfRated(value: Double?, rated: Double) -> Double? {
        guard let value, rated > 0 else { return nil }
        return value / rated * 100
    }

    static func percentOfCurve(net: Double?, ratedPressure: Double, curvePercent: Double) -> Double? {
        guard let net, ratedPressure > 0, curvePercent > 0 else { return nil }
        return net / (ratedPressure * curvePercent / 100) * 100
    }
}

/// The points on the curve the annual test takes readings at.
enum FlowPosition: String, CaseIterable, Identifiable {
    case churn, rated, overload
    var id: String { rawValue }

    var order: Int {
        switch self {
        case .churn: return 0
        case .rated: return 1
        case .overload: return 2
        }
    }

    var name: String {
        switch self {
        case .churn: return "Churn, no flow"
        case .rated: return "100% of rated flow"
        case .overload: return "150% of rated flow"
        }
    }

    /// Short enough for a column head, and still a whole word.
    var shortName: String {
        switch self {
        case .churn: return "Churn"
        case .rated: return "100%"
        case .overload: return "150%"
        }
    }

    var capacityPercent: Double {
        switch self {
        case .churn: return 0
        case .rated: return 100
        case .overload: return 150
        }
    }

    /// Where the nameplate curve sits at this point, as a percentage of rated pressure.
    var curvePressurePercent: Double {
        switch self {
        case .churn: return 140
        case .rated: return 100
        case .overload: return 65
        }
    }

    /// At churn the nameplate figure is a ceiling; at the other two points it is a floor. The app
    /// says which, without saying whether the reading is acceptable.
    var curveIsCeiling: Bool { self == .churn }

    var curveNote: String {
        switch self {
        case .churn:
            return "A nameplate curve at no flow is normally no more than 140% of rated pressure."
        case .rated:
            return "A nameplate curve at rated flow is 100% of rated pressure, by definition."
        case .overload:
            return "A nameplate curve at 150% of rated flow is normally not less than 65% of rated pressure."
        }
    }
}

// MARK: - Kinds, results and findings

enum TestKind: String, CaseIterable, Identifiable {
    case noFlow, annualFlow, jockeyAlarm
    var id: String { rawValue }

    static var scheduled: [TestKind] { [.noFlow, .annualFlow, .jockeyAlarm] }

    var order: Int {
        switch self {
        case .noFlow: return 0
        case .annualFlow: return 1
        case .jockeyAlarm: return 2
        }
    }

    var name: String {
        switch self {
        case .noFlow: return "No-flow test"
        case .annualFlow: return "Annual flow test"
        case .jockeyAlarm: return "Jockey and alarm check"
        }
    }

    var shortName: String {
        switch self {
        case .noFlow: return "No-flow"
        case .annualFlow: return "Flow test"
        case .jockeyAlarm: return "Alarms"
        }
    }

    var symbol: String {
        switch self {
        case .noFlow: return "gauge.with.dots.needle.33percent"
        case .annualFlow: return "chart.xyaxis.line"
        case .jockeyAlarm: return "bell.badge"
        }
    }

    func warnWithinDays(for pump: Pump) -> Int {
        switch self {
        case .noFlow: return pump.churnCadence.warnWithinDays
        case .annualFlow, .jockeyAlarm: return 30
        }
    }

    func cadenceLine(for pump: Pump) -> String {
        switch self {
        case .noFlow: return "\(pump.churnCadence.name), \(pump.churnCadence.everyLabel)"
        case .annualFlow, .jockeyAlarm: return "Annually"
        }
    }

    var requirement: String {
        switch self {
        case .noFlow:
            return "Start the pump and run it without flowing water. Record suction and discharge pressure, how long the pump took to start and how long it ran. NFPA 25 Chapter 8 sets the frequency, and your authority having jurisdiction or your insurer may ask for it more often."
        case .annualFlow:
            return "Flow water at the churn point and at 100% and 150% of rated capacity, recording flow, suction, discharge and speed at each. The readings are compared with the manufacturer's certified nameplate curve."
        case .jockeyAlarm:
            return "Record the jockey pump's cut-in and cut-out pressures against its setpoints, and make each alarm and supervisory signal the controller transmits actually happen, one at a time, and watch it arrive."
        }
    }

    /// The annual flow test is the signed document of the three.
    var needsSignature: Bool { self == .annualFlow }
}

enum ItemResult: String, CaseIterable, Identifiable {
    case notChecked, ok, fault, notApplicable
    var id: String { rawValue }

    var name: String {
        switch self {
        case .notChecked: return "Not checked"
        case .ok: return "OK"
        case .fault: return "Fault"
        case .notApplicable: return "N/A"
        }
    }

    var symbol: String {
        switch self {
        case .notChecked: return "circle"
        case .ok: return "checkmark.circle.fill"
        case .fault: return "exclamationmark.triangle.fill"
        case .notApplicable: return "minus.circle"
        }
    }
}

/// The technician's conclusion. The app never sets this and never changes it.
enum Finding: String, CaseIterable, Identifiable {
    case notStated, satisfactory, investigate, unacceptable
    var id: String { rawValue }

    var name: String {
        switch self {
        case .notStated: return "Not stated"
        case .satisfactory: return "Satisfactory"
        case .investigate: return "Investigate"
        case .unacceptable: return "Not acceptable"
        }
    }

    var symbol: String {
        switch self {
        case .notStated: return "questionmark.circle"
        case .satisfactory: return "checkmark.seal.fill"
        case .investigate: return "magnifyingglass.circle.fill"
        case .unacceptable: return "exclamationmark.octagon.fill"
        }
    }

    var isConcern: Bool { self == .investigate || self == .unacceptable }
}
