import Foundation
import SwiftData
import UIKit

#if DEBUG
/// Debug-only sample data for screenshots and manual testing.
/// Launch with `-sampleData` to insert it on first run, or use Settings → Debug → Insert sample data.
enum SampleData {
    static func insert(into context: ModelContext) {
        let calendar = Calendar.current
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: .now) ?? .now }

        // An electric jockey-backed pump whose weekly no-flow test is overdue — the one the
        // board should lead with.
        let electric = Pump(designation: "Fire Pump 1", make: "Peerless", model: "8x6x11.5G")
        electric.building = "North Tower"
        electric.location = "Basement pump room"
        electric.serialNumber = "PL-40218"
        electric.ratedFlowGPM = 1000
        electric.ratedPressurePSI = 125
        electric.ratedRPM = 1760
        electric.driver = .electric
        electric.controllerMake = "Firetrol"
        electric.controllerModel = "FTA1100"
        electric.churnCadence = .weekly
        electric.hasJockeyPump = true
        electric.jockeyCutInSetpointPSI = 120
        electric.jockeyCutOutSetpointPSI = 135
        context.insert(electric)

        let overdueNoFlow = PumpTest(date: daysAgo(11), kind: .noFlow)
        overdueNoFlow.pump = electric
        overdueNoFlow.cadence = .weekly
        overdueNoFlow.technicianName = "R. Alvarez"
        overdueNoFlow.suctionPSI = 62
        overdueNoFlow.dischargePSI = 141
        overdueNoFlow.timeToStartSeconds = 8
        overdueNoFlow.runMinutes = 10
        for item in overdueNoFlow.observationItems { overdueNoFlow.set(.ok, for: item) }
        overdueNoFlow.finding = .satisfactory
        context.insert(overdueNoFlow)

        let annual = PumpTest(date: daysAgo(40), kind: .annualFlow)
        annual.pump = electric
        annual.technicianName = "R. Alvarez"
        annual.company = "Meridian Fire Protection"
        annual.seedFlowPoints()
        if let churn = annual.point(.churn) { churn.suctionPSI = 64; churn.dischargePSI = 171 }
        if let rated = annual.point(.rated) { rated.flowGPM = 1000; rated.suctionPSI = 58; rated.dischargePSI = 152; rated.rpm = 1760 }
        if let overload = annual.point(.overload) { overload.flowGPM = 1500; overload.suctionPSI = 52; overload.dischargePSI = 108; overload.rpm = 1755 }
        annual.finding = .satisfactory
        annual.signature = signatureImage()
        context.insert(annual)

        let jockey = PumpTest(date: daysAgo(200), kind: .jockeyAlarm)
        jockey.pump = electric
        jockey.technicianName = "R. Alvarez"
        jockey.jockeyCutInPSI = 121
        jockey.jockeyCutOutPSI = 134
        for signal in jockey.signalItems { jockey.set(.ok, for: signal) }
        jockey.finding = .satisfactory
        context.insert(jockey)

        // A diesel pump, current on everything, so the board shows a healthy machine too.
        let diesel = Pump(designation: "Fire Pump 2", make: "Clarke", model: "JU6H-UF60")
        diesel.building = "Central Plant"
        diesel.location = "Pump house"
        diesel.serialNumber = "CJ-91027"
        diesel.ratedFlowGPM = 1500
        diesel.ratedPressurePSI = 150
        diesel.ratedRPM = 2100
        diesel.driver = .diesel
        diesel.controllerMake = "Metron"
        diesel.controllerModel = "M200"
        diesel.churnCadence = .weekly
        diesel.hasJockeyPump = false
        context.insert(diesel)

        let dieselRun = PumpTest(date: daysAgo(2), kind: .noFlow)
        dieselRun.pump = diesel
        dieselRun.cadence = .weekly
        dieselRun.technicianName = "K. Nwosu"
        dieselRun.suctionPSI = 58
        dieselRun.dischargePSI = 210
        dieselRun.timeToStartSeconds = 12
        dieselRun.runMinutes = 30
        dieselRun.fuelLevelPercent = 92
        dieselRun.batteryOneVolts = 12.9
        dieselRun.batteryTwoVolts = 12.7
        dieselRun.oilPressurePSI = 48
        dieselRun.coolantTempF = 168
        dieselRun.observedRPM = 2098
        dieselRun.reachedRatedSpeed = true
        for item in dieselRun.observationItems { dieselRun.set(.ok, for: item) }
        dieselRun.finding = .satisfactory
        context.insert(dieselRun)
    }

    /// A short pre-drawn stroke so sample records show a signed annual test.
    private static func signatureImage() -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 200, height: 60), format: format).pngData { ctx in
            ctx.cgContext.setStrokeColor(UIColor.label.cgColor)
            ctx.cgContext.setLineWidth(2.5)
            ctx.cgContext.setLineCap(.round)
            ctx.cgContext.move(to: CGPoint(x: 10, y: 40))
            ctx.cgContext.addCurve(to: CGPoint(x: 190, y: 20), control1: CGPoint(x: 70, y: 5), control2: CGPoint(x: 130, y: 55))
            ctx.cgContext.strokePath()
        }
    }
}
#endif
