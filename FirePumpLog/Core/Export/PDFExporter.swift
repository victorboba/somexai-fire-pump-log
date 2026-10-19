import Foundation
import PDFKit
import UIKit

/// The signed test record.
///
/// NFPA 25 Chapter 8 asks three differently-shaped things to be written down, so the page leads
/// with whichever readings that test kind actually took, then closes every document the same way:
/// the technician's name, their signature if the kind carries one, and the sentence that keeps
/// this app on the right side of the line between arithmetic and a verdict.
enum PDFExporter {
    static func export(_ test: PumpTest) throws -> URL {
        let pump = test.pump
        return try render(named: "\(AppConfig.exportFileStem)-\(ISO8601DateFormatter.day.string(from: test.date))") { draw in
            draw.title("\(pump?.title ?? "Unassigned pump") — \(test.kind.name)")
            draw.line("NFPA 25 Chapter 8" + (test.kind == .noFlow ? " — \(test.cadence.name) no-flow test" : ""),
                      size: 11, colour: .secondaryLabel)
            draw.rule()

            if let pump {
                draw.line(pump.nameplateLine, size: 10, colour: .secondaryLabel, gapAfter: 2)
                if !pump.whereItIs.isEmpty { draw.line(pump.whereItIs, size: 10, colour: .secondaryLabel, gapAfter: 2) }
            }
            draw.line("Tested \(test.date.formatted(date: .long, time: .omitted))", size: 10, colour: .secondaryLabel)
            draw.rule()

            switch test.kind {
            case .noFlow: drawNoFlow(test, draw)
            case .annualFlow: drawAnnualFlow(test, pump, draw)
            case .jockeyAlarm: drawJockeyAlarm(test, draw)
            }

            let tint: UIColor = test.finding.isConcern ? (test.finding == .unacceptable ? .systemRed : .systemOrange) : .systemGreen
            draw.rule()
            draw.line("Finding: \(test.finding.name)".uppercased(), size: 13, weight: .bold,
                      colour: test.finding == .notStated ? .secondaryLabel : tint, gapAfter: 2)
            if !test.correctiveAction.isEmpty {
                draw.line("Corrective action: \(test.correctiveAction)", size: 10, colour: .secondaryLabel)
            }
            if !test.notes.isEmpty {
                draw.rule()
                draw.line("Notes", size: 11, weight: .semibold, gapAfter: 3)
                draw.line(test.notes, size: 10)
            }

            draw.rule()
            draw.line(test.technicianName.isEmpty ? "Technician not named" : test.technicianName,
                      size: 11, weight: .semibold, gapAfter: 2)
            if !test.company.isEmpty { draw.line(test.company, size: 9, colour: .secondaryLabel, gapAfter: 6) }
            if test.kind.needsSignature {
                if let signature = test.signature, let image = UIImage(data: signature) {
                    draw.image(image, maxHeight: 70)
                } else {
                    draw.line("Not signed. \(test.kind.name) records are required to carry the signature "
                              + "of the person who ran the test.", size: 9, colour: .systemRed)
                }
            }

            draw.rule()
            draw.line(AppConfig.judgementDisclaimer, size: 9, colour: .secondaryLabel)
        }
    }

    private static func drawNoFlow(_ test: PumpTest, _ draw: Draw) {
        draw.line("Readings", size: 12, weight: .semibold, gapAfter: 4)
        draw.line("Suction \(Reading.optional(test.suctionPSI)) psi   ·   Discharge \(Reading.optional(test.dischargePSI)) psi"
                  + (test.netPressurePSI.map { "   ·   Net \(Reading.pressure($0)) psi" } ?? ""), size: 10, gapAfter: 2)
        draw.line("Time to start \(Reading.optional(test.timeToStartSeconds)) sec   ·   Ran \(Reading.optional(test.runMinutes)) min"
                  + "   ·   Started \(test.startedAutomatically ? "automatically" : "manually")", size: 10, gapAfter: 4)

        if test.driver.asksEngineReadings {
            draw.line("Fuel \(Reading.optional(test.fuelLevelPercent))%   ·   Battery 1 \(Reading.optional(test.batteryOneVolts)) V"
                      + "   ·   Battery 2 \(Reading.optional(test.batteryTwoVolts)) V", size: 10, gapAfter: 2)
            draw.line("Oil \(Reading.optional(test.oilPressurePSI)) psi   ·   Coolant \(Reading.optional(test.coolantTempF))°F"
                      + "   ·   Speed \(Reading.optional(test.observedRPM)) rpm"
                      + "   ·   \(test.reachedRatedSpeed ? "Reached rated speed" : "Did not reach rated speed")",
                      size: 10, gapAfter: 4)
        }

        let faults = test.faultedObservations
        if !faults.isEmpty {
            draw.rule()
            draw.line("Observations needing attention", size: 11, weight: .semibold, colour: .systemRed, gapAfter: 3)
            for item in faults {
                let note = test.note(forKey: item.rawValue)
                draw.line("\(item.name)\(note.isEmpty ? "" : ": \(note)")", size: 9, colour: .systemRed, gapAfter: 1)
            }
        }
    }

    private static func drawAnnualFlow(_ test: PumpTest, _ pump: Pump?, _ draw: Draw) {
        draw.line("Flow points", size: 12, weight: .semibold, gapAfter: 4)
        for point in test.sortedFlowPoints where point.hasReadings {
            var parts = [point.position.name]
            if let flow = point.flowGPM { parts.append("\(Reading.whole(flow)) gpm") }
            parts.append("suction \(Reading.optional(point.suctionPSI)) psi")
            parts.append("discharge \(Reading.optional(point.dischargePSI)) psi")
            if let net = point.netPressurePSI { parts.append("net \(Reading.pressure(net)) psi") }
            if let rpm = point.rpm { parts.append("\(Reading.whole(rpm)) rpm") }
            draw.line(parts.joined(separator: "   ·   "), size: 10, weight: .semibold, gapAfter: 1)
            if let pump {
                var pct: [String] = []
                if let capacity = point.percentOfRatedCapacity(pump: pump) { pct.append("\(Reading.oneDecimal(capacity))% of rated capacity") }
                if let curve = point.percentOfNameplateCurve(pump: pump) { pct.append("\(Reading.oneDecimal(curve))% of nameplate at this point") }
                if !pct.isEmpty { draw.line(pct.joined(separator: "   ·   "), size: 9, colour: .secondaryLabel, indent: 12, gapAfter: 3) }
            }
        }
        if test.pointsWithReadings.isEmpty {
            draw.line("No flow points were recorded.", size: 10, colour: .secondaryLabel, gapAfter: 4)
        }
    }

    private static func drawJockeyAlarm(_ test: PumpTest, _ draw: Draw) {
        draw.line("Jockey pump", size: 12, weight: .semibold, gapAfter: 4)
        draw.line("Cut-in \(Reading.optional(test.jockeyCutInPSI)) psi   ·   Cut-out \(Reading.optional(test.jockeyCutOutPSI)) psi",
                  size: 10, gapAfter: 4)

        draw.line("Alarm & supervisory signals", size: 12, weight: .semibold, gapAfter: 4)
        draw.line("\(test.checkedSignalCount) of \(test.signalItems.count) signals checked", size: 10, colour: .secondaryLabel, gapAfter: 3)
        let faults = test.faultedSignals
        if !faults.isEmpty {
            for signal in faults {
                let note = test.note(forKey: signal.rawValue)
                draw.line("\(signal.name)\(note.isEmpty ? "" : ": \(note)")", size: 9, colour: .systemRed, gapAfter: 1)
            }
        }
    }

    /// The pump's whole retained file, for the day somebody asks to see it.
    static func exportHistory(_ pump: Pump, asOf today: Date = .now) throws -> URL {
        try render(named: "\(AppConfig.exportFileStem)-history-\(ISO8601DateFormatter.day.string(from: today))") { draw in
            draw.title(pump.title)
            draw.line(pump.nameplateLine, size: 11, colour: .secondaryLabel, gapAfter: 2)
            if !pump.whereItIs.isEmpty { draw.line(pump.whereItIs, size: 10, colour: .secondaryLabel) }
            draw.rule()

            draw.line("Clocks", size: 12, weight: .semibold, gapAfter: 4)
            for kind in pump.clockKinds {
                let status = pump.status(kind, asOf: today)
                draw.line("\(kind.name.padding(toLength: 22, withPad: " ", startingAt: 0))\(status.headline)",
                          size: 10, weight: status.needsAttention ? .semibold : .regular,
                          colour: status.needsAttention ? .systemOrange : .label, gapAfter: 2)
            }

            draw.rule()
            draw.line("Tests", size: 12, weight: .semibold, gapAfter: 6)
            if pump.sortedTests.isEmpty {
                draw.line("No tests have been recorded for this pump.", size: 10, colour: .secondaryLabel)
            }
            for test in pump.sortedTests {
                var parts = [test.kind.name, test.finding.name]
                if !test.technicianName.isEmpty { parts.append(test.technicianName) }
                if test.kind.needsSignature { parts.append(test.signature == nil ? "unsigned" : "signed") }
                let tint: UIColor = test.finding.isConcern ? .systemOrange : .label
                draw.line("\(ISO8601DateFormatter.day.string(from: test.date))   \(parts.joined(separator: "  ·  "))",
                          size: 10, weight: test.finding.isConcern ? .semibold : .regular, colour: tint, gapAfter: 1)
                draw.line(test.summaryLine, size: 9, colour: .secondaryLabel, indent: 12, gapAfter: 3)
            }

            draw.rule()
            draw.line(AppConfig.judgementDisclaimer, size: 9, colour: .secondaryLabel)
        }
    }

    // MARK: - Page plumbing

    private final class Draw {
        let ctx: UIGraphicsPDFRendererContext
        let pageWidth: CGFloat = 612, pageHeight: CGFloat = 792, margin: CGFloat = 48
        var y: CGFloat = 48

        init(_ ctx: UIGraphicsPDFRendererContext) { self.ctx = ctx }

        func title(_ text: String) { line(text, size: 20, weight: .semibold) }

        func line(_ text: String, size: CGFloat = 11, weight: UIFont.Weight = .regular,
                  colour: UIColor = .label, indent: CGFloat = 0, gapAfter: CGFloat = 4) {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
            let width = pageWidth - margin * 2 - indent
            let bounding = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            if y + bounding.height > pageHeight - margin { ctx.beginPage(); y = margin }
            (text as NSString).draw(
                with: CGRect(x: margin + indent, y: y, width: width, height: bounding.height),
                options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
            y += bounding.height + gapAfter
        }

        func image(_ image: UIImage, maxHeight: CGFloat) {
            let scale = min(maxHeight / image.size.height, (pageWidth - margin * 2) / image.size.width, 1)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            if y + size.height > pageHeight - margin { ctx.beginPage(); y = margin }
            image.draw(in: CGRect(origin: CGPoint(x: margin, y: y), size: size))
            y += size.height + 6
        }

        func rule(gap: CGFloat = 10) {
            y += gap / 2
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor.separator.setStroke(); path.lineWidth = 0.5; path.stroke()
            y += gap / 2
        }
    }

    private static func render(named name: String, _ body: (Draw) -> Void) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).pdf")
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            body(Draw(ctx))
        }
        return url
    }
}
