import XCTest
@testable import FirePumpLog

/// The arithmetic and the schedule: net pressure, percentages of the nameplate, and the three
/// clocks. Every calculation, cadence and boundary the app introduces gets a test here, plus the
/// zero-versus-not-recorded distinction the model exists to keep straight.
final class PumpTests: XCTestCase {

    // MARK: - Reading: nil is not zero

    func testAReadingThatWasNeverTakenPrintsAsADashNeverAZero() {
        XCTAssertEqual(Reading.optional(nil), "—")
        XCTAssertEqual(Reading.optional(0), "0")
        XCTAssertNotEqual(Reading.optional(nil), Reading.optional(0),
                          "a blank suction gauge and a suction gauge reading zero are two different statements")
    }

    func testPressureDropsATrailingZeroButKeepsRealDecimals() {
        XCTAssertEqual(Reading.pressure(140), "140")
        XCTAssertEqual(Reading.pressure(140.5), "140.5")
    }

    // MARK: - FlowMath

    func testNetPressureIsNilWhenEitherReadingIsMissing() {
        XCTAssertNil(FlowMath.netPressure(discharge: nil, suction: 60))
        XCTAssertNil(FlowMath.netPressure(discharge: 140, suction: nil))
    }

    func testNetPressureIsDischargeMinusSuction() {
        XCTAssertEqual(FlowMath.netPressure(discharge: 140, suction: 60), 80)
    }

    func testNetPressureGrowsUnderAVacuumRatherThanShrinking() {
        // A negative suction reading (a vacuum) should make the net pressure larger, which is why
        // this is a subtraction and never an absolute difference.
        XCTAssertEqual(FlowMath.netPressure(discharge: 140, suction: -5), 145)
    }

    func testPercentOfRatedIsNilWithNoNameplateOrNoReading() {
        XCTAssertNil(FlowMath.percentOfRated(value: nil, rated: 1000))
        XCTAssertNil(FlowMath.percentOfRated(value: 1000, rated: 0))
    }

    func testPercentOfRatedIsAStraightDivision() {
        XCTAssertEqual(FlowMath.percentOfRated(value: 1500, rated: 1000)!, 150, accuracy: 0.001)
    }

    func testPercentOfCurveIsNilWithoutACurvePercent() {
        XCTAssertNil(FlowMath.percentOfCurve(net: 80, ratedPressure: 125, curvePercent: 0))
    }

    func testPercentOfCurveComparesNetPressureToTheNameplateAtThatPoint() {
        // At 150% of rated flow the nameplate curve is 65% of rated pressure, so a net pressure of
        // exactly that figure should read 100%.
        let expected = 125 * 65.0 / 100
        XCTAssertEqual(FlowMath.percentOfCurve(net: expected, ratedPressure: 125, curvePercent: 65)!, 100, accuracy: 0.01)
    }

    // MARK: - FlowPosition

    func testChurnHasNoTargetCapacityAndTheOthersDo() {
        XCTAssertEqual(FlowPosition.churn.capacityPercent, 0)
        XCTAssertEqual(FlowPosition.rated.capacityPercent, 100)
        XCTAssertEqual(FlowPosition.overload.capacityPercent, 150)
    }

    func testOnlyChurnTreatsTheCurveAsACeiling() {
        XCTAssertTrue(FlowPosition.churn.curveIsCeiling)
        XCTAssertFalse(FlowPosition.rated.curveIsCeiling)
        XCTAssertFalse(FlowPosition.overload.curveIsCeiling)
    }

    func testTargetFlowIsNilWithoutANameplate() {
        let pump = Pump(designation: "P1")
        let point = FlowPoint(position: .rated)
        point.test = PumpTest(kind: .annualFlow)
        XCTAssertNil(point.targetFlow(pump: pump))
        pump.ratedFlowGPM = 1000
        XCTAssertEqual(point.targetFlow(pump: pump), 1000)
    }

    // MARK: - Driver-aware item lists

    func testADieselAsksForEngineReadingsAndAnElectricPumpNever() {
        XCTAssertTrue(DriverType.diesel.asksEngineReadings)
        XCTAssertFalse(DriverType.electric.asksEngineReadings)
    }

    func testObservationItemsDifferByDriver() {
        let electric = ObservationItem.items(for: .electric)
        let diesel = ObservationItem.items(for: .diesel)
        XCTAssertTrue(electric.contains(.controllerPilotLight))
        XCTAssertFalse(electric.contains(.coolingWaterFlow))
        XCTAssertTrue(diesel.contains(.coolingWaterFlow))
        XCTAssertFalse(diesel.contains(.controllerPilotLight))
    }

    func testAlarmSignalsDifferByDriver() {
        let electric = AlarmSignal.items(for: .electric)
        let diesel = AlarmSignal.items(for: .diesel)
        XCTAssertTrue(electric.contains(.lossOfPhase))
        XCTAssertFalse(electric.contains(.lowOilPressure))
        XCTAssertTrue(diesel.contains(.lowOilPressure))
        XCTAssertTrue(diesel.count > electric.count, "a diesel controller carries roughly twice the electric list")
    }

    // MARK: - Cadence

    func testWeeklyCadenceAdvancesSevenDaysAndMonthlyAdvancesOneMonth() {
        let start = Date(timeIntervalSince1970: 0)
        let weekly = ChurnCadence.weekly.next(after: start)!
        let monthly = ChurnCadence.monthly.next(after: start)!
        XCTAssertEqual(Calendar.current.dateComponents([.day], from: start, to: weekly).day, 7)
        XCTAssertEqual(Calendar.current.dateComponents([.month], from: start, to: monthly).month, 1)
    }

    // MARK: - Clocks and due status

    private func pump(driver: DriverType = .electric, jockey: Bool = true) -> Pump {
        let p = Pump(designation: "Fire Pump 1")
        p.driver = driver
        p.hasJockeyPump = jockey
        p.ratedFlowGPM = 1000
        p.ratedPressurePSI = 125
        return p
    }

    private func test(_ kind: TestKind, daysAgo: Int, on pump: Pump, cadence: ChurnCadence = .weekly) -> PumpTest {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let t = PumpTest(date: date, kind: kind)
        t.cadence = cadence
        t.pump = pump
        pump.tests = (pump.tests ?? []) + [t]
        return t
    }

    func testANeverRunClockReportsNeverRun() {
        XCTAssertEqual(pump().status(.noFlow), .neverRun)
    }

    func testAWeeklyNoFlowTestDueStatusMovesThroughTheWholeCycle() {
        let p = pump()
        p.churnCadence = .weekly
        _ = test(.noFlow, daysAgo: 0, on: p)
        XCTAssertEqual(p.status(.noFlow), .scheduled(inDays: 7))
        p.tests = []
        _ = test(.noFlow, daysAgo: 6, on: p)
        XCTAssertEqual(p.status(.noFlow), .dueSoon(inDays: 1))
        p.tests = []
        _ = test(.noFlow, daysAgo: 7, on: p)
        XCTAssertEqual(p.status(.noFlow), .dueToday)
        p.tests = []
        _ = test(.noFlow, daysAgo: 9, on: p)
        XCTAssertEqual(p.status(.noFlow), .overdue(byDays: 2))
    }

    func testAnnualClocksRunOnTwelveMonthsRegardlessOfKind() {
        let p = pump()
        _ = test(.annualFlow, daysAgo: 100, on: p)
        if case .scheduled = p.status(.annualFlow) {} else { XCTFail("should still be scheduled inside a year") }
        p.tests = []
        _ = test(.jockeyAlarm, daysAgo: 400, on: p)
        if case .overdue = p.status(.jockeyAlarm) {} else { XCTFail("400 days is past the annual interval") }
    }

    func testClocksComeBackWorstFirst() {
        let p = pump()
        _ = test(.noFlow, daysAgo: 0, on: p)
        _ = test(.annualFlow, daysAgo: 400, on: p)
        _ = test(.jockeyAlarm, daysAgo: 10, on: p)
        XCTAssertEqual(p.clocks().first?.kind, .annualFlow, "the overdue one leads")
    }

    func testAPumpWithNoJockeyPumpDoesNotRunTheJockeyClock() {
        let p = pump(jockey: false)
        XCTAssertFalse(p.clockKinds.contains(.jockeyAlarm))
        XCTAssertTrue(pump(jockey: true).clockKinds.contains(.jockeyAlarm))
    }

    func testOverdueByManyDaysReportsInMonths() {
        XCTAssertEqual(DueStatus.overdue(byDays: 61).pillText, "2 mo late")
        XCTAssertEqual(DueStatus.overdue(byDays: 3).pillText, "3 d late")
    }

    // MARK: - Test completeness

    func testANoFlowTestNeedsSuctionDischargeAndRunTime() {
        let t = PumpTest(kind: .noFlow)
        XCTAssertFalse(t.isComplete)
        XCTAssertTrue(t.missingPieces.contains("suction pressure"))
        t.suctionPSI = 60; t.dischargePSI = 140; t.runMinutes = 10
        XCTAssertTrue(t.isComplete)
    }

    func testAnAnnualFlowTestNeedsAtLeastOnePointATechnicianAndASignature() {
        let t = PumpTest(kind: .annualFlow)
        t.seedFlowPoints()
        XCTAssertFalse(t.isComplete)
        t.point(.rated)?.dischargePSI = 150
        t.point(.rated)?.suctionPSI = 60
        t.technicianName = "A. Reyes"
        XCTAssertFalse(t.isComplete, "still not complete without a signature")
        t.signature = Data([0x1])
        XCTAssertTrue(t.isComplete)
    }

    func testAJockeyAlarmTestNeedsBothSetpointsAndEverySignalChecked() {
        let p = pump()
        let t = PumpTest(kind: .jockeyAlarm)
        t.pump = p
        XCTAssertFalse(t.isComplete)
        t.jockeyCutInPSI = 120; t.jockeyCutOutPSI = 135
        XCTAssertFalse(t.isComplete, "signals are still unchecked")
        for signal in t.signalItems { t.set(.ok, for: signal) }
        XCTAssertTrue(t.isComplete)
    }

    func testAnEmptyNoFlowTestReportsEmptySoCancellingThrowsItAway() {
        let t = PumpTest(kind: .noFlow)
        XCTAssertTrue(t.isEmpty)
        t.suctionPSI = 0
        XCTAssertFalse(t.isEmpty, "a recorded zero is not the same as nothing entered")
    }
}
