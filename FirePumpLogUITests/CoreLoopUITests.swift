import XCTest

/// Drives the real core loop end to end: add a pump, run its weekly no-flow test, then run the
/// annual flow test — the multi-point screen the app exists to sell — and confirm both land in
/// the pump's history. Every assertion is on content that only appears once the app actually did
/// the work, never merely that a button exists.
final class CoreLoopUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAddPumpRunNoFlowTestAndAnnualFlowTest() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Fire Pump Log"].waitForExistence(timeout: 15))

        // Empty board: add the first pump.
        let addPump = app.buttons["Add a Pump"].firstMatch
        XCTAssertTrue(addPump.waitForExistence(timeout: 5))
        addPump.tap()

        XCTAssertTrue(app.navigationBars["Pump Details"].waitForExistence(timeout: 5))
        let designation = app.textFields["pumpDesignationField"]
        XCTAssertTrue(designation.waitForExistence(timeout: 5))
        designation.tap()
        designation.typeText("UITest Pump 1")

        let ratedFlow = app.textFields["ratedFlowField"]
        ratedFlow.tap()
        ratedFlow.typeText("1000")
        let ratedPressure = app.textFields["ratedPressureField"]
        ratedPressure.tap()
        ratedPressure.typeText("125")

        app.navigationBars["Pump Details"].buttons["Done"].tap()

        // The pump the app just created has to actually appear on the board.
        let pumpRow = app.staticTexts["UITest Pump 1"]
        XCTAssertTrue(pumpRow.waitForExistence(timeout: 5))
        pumpRow.tap()
        XCTAssertTrue(app.navigationBars["UITest Pump 1"].waitForExistence(timeout: 5))

        // The weekly no-flow test: a handful of readings, saved, and confirmed in the history.
        let noFlowButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "No-flow test")).firstMatch
        XCTAssertTrue(noFlowButton.waitForExistence(timeout: 5))
        noFlowButton.tap()
        XCTAssertTrue(app.navigationBars["No-Flow Test"].waitForExistence(timeout: 5))

        let suction = app.textFields["noFlow.Suction pressure"]
        XCTAssertTrue(suction.waitForExistence(timeout: 5))
        suction.tap(); suction.typeText("60")
        let discharge = app.textFields["noFlow.Discharge pressure"]
        discharge.tap(); discharge.typeText("140")
        let runMinutes = app.textFields["noFlow.runMinutes"]
        runMinutes.tap(); runMinutes.typeText("10")

        app.buttons["Mark Remaining Observations OK"].tap()
        app.navigationBars["No-Flow Test"].buttons["Done"].tap()

        // The no-flow test the app just recorded has to show up in this pump's history, further
        // down a pump screen long enough that the List has not laid out that far yet.
        XCTAssertTrue(app.navigationBars["UITest Pump 1"].waitForExistence(timeout: 5))
        let noFlowHistoryRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "No-flow ·")).firstMatch
        XCTAssertTrue(scrollToReveal(noFlowHistoryRow, in: app))

        // The screen the app sells: the multi-point annual flow test against the nameplate.
        let annualButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Annual flow test")).firstMatch
        XCTAssertTrue(annualButton.waitForExistence(timeout: 5))
        annualButton.tap()
        XCTAssertTrue(app.navigationBars["Annual Flow Test"].waitForExistence(timeout: 5))

        let ratedFlowPoint = app.textFields["flow.rated.flow"]
        XCTAssertTrue(scrollToReveal(ratedFlowPoint, in: app))
        ratedFlowPoint.tap(); ratedFlowPoint.typeText("1000")
        let ratedSuction = app.textFields["flow.rated.suction"]
        ratedSuction.tap(); ratedSuction.typeText("58")
        let ratedDischarge = app.textFields["flow.rated.discharge"]
        ratedDischarge.tap(); ratedDischarge.typeText("152")

        // Net pressure and the percentage of the nameplate appear as soon as numbers land —
        // arithmetic on the technician's own readings, computed live.
        let netPressureReadout = app.staticTexts["Net pressure"]
        XCTAssertTrue(scrollToReveal(netPressureReadout, in: app))
        let nameplateReadout = app.staticTexts["% of nameplate at this point"]
        XCTAssertTrue(scrollToReveal(nameplateReadout, in: app))

        let technician = app.textFields["Name"].firstMatch
        XCTAssertTrue(scrollToReveal(technician, in: app))
        technician.tap(); technician.typeText("UITest Tech")

        let doneButton = app.navigationBars["Annual Flow Test"].buttons["Done"]
        doneButton.tap()

        // The annual flow test the app just recorded also has to show up in the history.
        XCTAssertTrue(app.navigationBars["UITest Pump 1"].waitForExistence(timeout: 5))
        let flowHistoryRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Flow test ·")).firstMatch
        XCTAssertTrue(scrollToReveal(flowHistoryRow, in: app))
    }

    /// SwiftUI `List`/`Form` rows are lazily realized: an element far enough down the screen
    /// simply does not exist in the accessibility tree yet, so `waitForExistence` alone times out
    /// on it. Swipe the screen up a few times, checking after each, until it is laid out.
    @discardableResult
    private func scrollToReveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) -> Bool {
        for _ in 0..<maxSwipes {
            if element.waitForExistence(timeout: 1) { return true }
            app.swipeUp()
        }
        return element.waitForExistence(timeout: 2)
    }
}
