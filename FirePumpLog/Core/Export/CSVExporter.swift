import Foundation

/// One row per test — and one row per flow point on an annual test, since that is the level a
/// chief engineer actually wants to chart. Every column exists for every kind, blank where a
/// kind does not use it, so the sheet reconciles a mixed fleet history in one file.
enum CSVExporter {
    static let header = [
        "pump", "building", "location", "driver", "rated_flow_gpm", "rated_pressure_psi", "rated_rpm",
        "kind", "date", "cadence", "technician", "company", "finding",
        "suction_psi", "discharge_psi", "net_psi", "time_to_start_sec", "run_min", "started_automatically",
        "fuel_percent", "battery1_v", "battery2_v", "oil_psi", "coolant_f", "observed_rpm", "reached_rated_speed",
        "flow_position", "flow_gpm", "percent_rated_capacity", "percent_nameplate",
        "jockey_cut_in_psi", "jockey_cut_out_psi", "checked_signals", "total_signals",
        "signed", "notes",
    ]

    static func export(_ pumps: [Pump]) throws -> URL {
        let url = ExportFile.temporaryURL(extension: "csv")
        try csv(for: pumps).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func csv(for pumps: [Pump]) -> String {
        var lines = [header.joined(separator: ",")]
        for pump in pumps.sorted(by: { $0.designation < $1.designation }) {
            for test in pump.sortedTests {
                lines.append(contentsOf: rows(for: test, pump: pump))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// One test becomes one row, except an annual flow test with readings becomes one row per
    /// flow point that actually has readings, so a rollover with only the churn point filled in
    /// still shows up rather than being silently skipped.
    private static func rows(for test: PumpTest, pump: Pump) -> [String] {
        let identity = [
            pump.designation, pump.building, pump.location, pump.driver.name,
            numberOrBlank(pump.ratedFlowGPM), numberOrBlank(pump.ratedPressurePSI), numberOrBlank(pump.ratedRPM),
        ]
        let common = [
            test.kind.name, ISO8601DateFormatter.day.string(from: test.date),
            test.kind == .noFlow ? test.cadence.name : "",
            test.technicianName, test.company, test.finding.name,
        ]
        let noFlow = [
            optional(test.suctionPSI), optional(test.dischargePSI), optional(test.netPressurePSI),
            optional(test.timeToStartSeconds), optional(test.runMinutes),
            test.kind == .noFlow ? (test.startedAutomatically ? "yes" : "no") : "",
        ]
        let engine = test.driver.asksEngineReadings ? [
            optional(test.fuelLevelPercent), optional(test.batteryOneVolts), optional(test.batteryTwoVolts),
            optional(test.oilPressurePSI), optional(test.coolantTempF), optional(test.observedRPM),
            test.kind == .noFlow ? (test.reachedRatedSpeed ? "yes" : "no") : "",
        ] : ["", "", "", "", "", "", ""]
        let jockey = [
            optional(test.jockeyCutInPSI), optional(test.jockeyCutOutPSI),
            test.kind == .jockeyAlarm ? "\(test.checkedSignalCount)" : "",
            test.kind == .jockeyAlarm ? "\(test.signalItems.count)" : "",
        ]
        let tail = [test.kind.needsSignature ? (test.signature == nil ? "no" : "yes") : "", test.notes]

        if test.kind == .annualFlow {
            let points = test.pointsWithReadings
            guard !points.isEmpty else {
                let cells = identity + common + noFlow + engine + ["", "", "", ""] + jockey + tail
                return [cells.map(escape).joined(separator: ",")]
            }
            return points.map { point in
                let flow = [
                    point.position.name, optional(point.flowGPM),
                    optional(point.percentOfRatedCapacity(pump: pump)),
                    optional(point.percentOfNameplateCurve(pump: pump)),
                ]
                let pointReadings = [optional(point.suctionPSI), optional(point.dischargePSI), optional(point.netPressurePSI),
                                     "", "", ""]
                let cells = identity + common + pointReadings + engine + flow + jockey + tail
                return cells.map(escape).joined(separator: ",")
            }
        }

        let cells = identity + common + noFlow + engine + ["", "", "", ""] + jockey + tail
        return [cells.map(escape).joined(separator: ",")]
    }

    private static func optional(_ value: Double?) -> String {
        guard let value else { return "" }
        return value == value.rounded() ? String(Int(value)) : String(value)
    }

    private static func numberOrBlank(_ value: Double) -> String {
        value == 0 ? "" : optional(value)
    }

    private static func escape(_ value: String) -> String {
        value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
            ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            : value
    }

    static func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(extension ext: String) -> URL {
        let stamp = DateFormatter.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(stamp)")
            .appendingPathExtension(ext)
    }
}

extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()
}

extension ISO8601DateFormatter {
    static let day: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
