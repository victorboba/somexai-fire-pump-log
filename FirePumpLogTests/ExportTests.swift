import XCTest
import PDFKit
@testable import FirePumpLog

final class ExportTests: XCTestCase {

    private func electricPump() -> Pump {
        let p = Pump(designation: "Fire Pump 1", make: "Peerless", model: "8x6x11.5G")
        p.building = "North Tower"
        p.ratedFlowGPM = 1000
        p.ratedPressurePSI = 125
        p.ratedRPM = 1760
        p.driver = .electric
        return p
    }

    private func dieselPump() -> Pump {
        let p = Pump(designation: "Fire Pump 2", make: "Clarke", model: "JU6H")
        p.ratedFlowGPM = 1500
        p.ratedPressurePSI = 150
        p.driver = .diesel
        return p
    }

    private func noFlowTest(on pump: Pump) -> PumpTest {
        let t = PumpTest(date: Date(timeIntervalSince1970: 1_700_000_000), kind: .noFlow)
        t.pump = pump
        t.cadence = .weekly
        t.technicianName = "R. Alvarez"
        t.suctionPSI = 60
        t.dischargePSI = 140
        t.runMinutes = 10
        pump.tests = (pump.tests ?? []) + [t]
        return t
    }

    private func annualTest(on pump: Pump, signed: Bool = true) -> PumpTest {
        let t = PumpTest(date: Date(timeIntervalSince1970: 1_700_000_000), kind: .annualFlow)
        t.pump = pump
        t.technicianName = "R. Alvarez"
        t.company = "Meridian Fire Protection"
        t.seedFlowPoints()
        t.point(.churn)?.suctionPSI = 64
        t.point(.churn)?.dischargePSI = 171
        t.point(.rated)?.flowGPM = 1000
        t.point(.rated)?.suctionPSI = 58
        t.point(.rated)?.dischargePSI = 152
        t.point(.overload)?.flowGPM = 1500
        t.point(.overload)?.suctionPSI = 52
        t.point(.overload)?.dischargePSI = 108
        if signed { t.signature = Data([0x1, 0x2, 0x3]) }
        pump.tests = (pump.tests ?? []) + [t]
        return t
    }

    // MARK: - CSV

    func testCSVForNoPumpsIsJustTheHeader() {
        let text = CSVExporter.csv(for: [])
        let lines = Array(text.split(separator: "\n", omittingEmptySubsequences: true))
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(String(lines[0]), CSVExporter.header.joined(separator: ","))
    }

    func testCSVHasOneRowPerNoFlowTest() {
        let pump = electricPump()
        _ = noFlowTest(on: pump)
        let text = CSVExporter.csv(for: [pump])
        let lines = Array(text.split(separator: "\n", omittingEmptySubsequences: true))
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains("Fire Pump 1"))
        XCTAssertTrue(lines[1].contains("No-flow test"))
    }

    func testCSVDistinguishesANilReadingFromAZeroReading() {
        let pump = electricPump()
        let t = noFlowTest(on: pump)
        t.timeToStartSeconds = nil // never recorded
        t.suctionPSI = 0 // a real zero-psi suction reading
        let text = CSVExporter.csv(for: [pump])
        let row = Array(text.split(separator: "\n", omittingEmptySubsequences: true))[1]
        let cells = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let suctionIndex = CSVExporter.header.firstIndex(of: "suction_psi")!
        let startIndex = CSVExporter.header.firstIndex(of: "time_to_start_sec")!
        XCTAssertEqual(cells[suctionIndex], "0")
        XCTAssertEqual(cells[startIndex], "")
    }

    func testAnAnnualTestWithThreeFlowPointsProducesThreeRows() {
        let pump = electricPump()
        _ = annualTest(on: pump)
        let text = CSVExporter.csv(for: [pump])
        let lines = Array(text.split(separator: "\n", omittingEmptySubsequences: true))
        XCTAssertEqual(lines.count, 4, "header plus one row per flow point")
    }

    func testAnAnnualTestWithNoFlowPointsYetStillProducesOneRow() {
        let pump = electricPump()
        let t = PumpTest(kind: .annualFlow)
        t.pump = pump
        pump.tests = [t]
        let text = CSVExporter.csv(for: [pump])
        let lines = Array(text.split(separator: "\n", omittingEmptySubsequences: true))
        XCTAssertEqual(lines.count, 2, "an untouched annual test is not silently dropped from the sheet")
    }

    func testEngineColumnsAreBlankForAnElectricPump() {
        let pump = electricPump()
        _ = noFlowTest(on: pump)
        let text = CSVExporter.csv(for: [pump])
        let row = Array(text.split(separator: "\n", omittingEmptySubsequences: true))[1]
        let cells = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let fuelIndex = CSVExporter.header.firstIndex(of: "fuel_percent")!
        XCTAssertEqual(cells[fuelIndex], "")
    }

    func testEngineColumnsCarryDieselReadings() {
        let pump = dieselPump()
        let t = noFlowTest(on: pump)
        t.fuelLevelPercent = 92
        let text = CSVExporter.csv(for: [pump])
        let row = Array(text.split(separator: "\n", omittingEmptySubsequences: true))[1]
        let cells = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let fuelIndex = CSVExporter.header.firstIndex(of: "fuel_percent")!
        XCTAssertEqual(cells[fuelIndex], "92")
    }

    func testAFieldContainingACommaIsQuoted() {
        let pump = electricPump()
        let t = noFlowTest(on: pump)
        t.notes = "Noisy, needs lube"
        let text = CSVExporter.csv(for: [pump])
        XCTAssertTrue(text.contains("\"Noisy, needs lube\""))
    }

    // MARK: - PDF

    /// PDFKit wraps text at the column width and hands columns back out of order, so every
    /// assertion normalises whitespace and checks a phrase, never adjacent columns.
    private func text(of url: URL) throws -> String {
        let doc = try XCTUnwrap(PDFDocument(url: url))
        return (doc.string ?? "").replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    func testTheNoFlowPDFNamesThePumpAndTheCadence() throws {
        let pump = electricPump()
        let t = noFlowTest(on: pump)
        let text = try text(of: try PDFExporter.export(t))
        XCTAssertTrue(text.contains("Fire Pump 1"))
        XCTAssertTrue(text.contains("Weekly no-flow test"))
        XCTAssertTrue(text.contains("R. Alvarez"))
    }

    func testTheNoFlowPDFOmitsEngineReadingsForAnElectricPumpAndIncludesThemForADiesel() throws {
        let electric = electricPump()
        let electricText = try text(of: try PDFExporter.export(noFlowTest(on: electric)))
        XCTAssertFalse(electricText.contains("Battery 1"))

        let diesel = dieselPump()
        let dieselTest = noFlowTest(on: diesel)
        dieselTest.batteryOneVolts = 12.8
        let dieselText = try text(of: try PDFExporter.export(dieselTest))
        XCTAssertTrue(dieselText.contains("Battery 1"))
    }

    func testTheAnnualFlowPDFListsAllThreePointsAndTheirPercentages() throws {
        let pump = electricPump()
        let t = annualTest(on: pump)
        let text = try text(of: try PDFExporter.export(t))
        XCTAssertTrue(text.contains("Churn, no flow"))
        XCTAssertTrue(text.contains("100% of rated flow"))
        XCTAssertTrue(text.contains("150% of rated flow"))
        XCTAssertTrue(text.contains("% of nameplate at this point"))
    }

    func testTheAnnualFlowPDFSaysWhenItIsUnsigned() throws {
        let pump = electricPump()
        let t = annualTest(on: pump, signed: false)
        let text = try text(of: try PDFExporter.export(t))
        XCTAssertTrue(text.contains("Not signed"))
    }

    func testEveryExportCarriesTheJudgementDisclaimer() throws {
        let pump = electricPump()
        let t = noFlowTest(on: pump)
        let testText = try text(of: try PDFExporter.export(t))
        let historyText = try text(of: try PDFExporter.exportHistory(pump))
        XCTAssertTrue(testText.contains("does not decide whether a pump passed"))
        XCTAssertTrue(historyText.contains("does not decide whether a pump passed"))
    }

    func testThePDFNeverClaimsToJudgeThePump() throws {
        let pump = electricPump()
        let t = annualTest(on: pump)
        t.finding = .unacceptable
        let text = try text(of: try PDFExporter.export(t))
        // The app states the technician's own finding; it must not say the app itself decided.
        XCTAssertTrue(text.contains("FINDING: NOT ACCEPTABLE"))
        XCTAssertTrue(text.contains("that judgement belongs to the person who ran the test"))
    }

    func testAnEmptyPumpsHistoryPDFSaysSo() throws {
        let pump = Pump(designation: "Fresh Pump")
        let text = try text(of: try PDFExporter.exportHistory(pump))
        XCTAssertTrue(text.contains("No tests have been recorded"))
    }
}
