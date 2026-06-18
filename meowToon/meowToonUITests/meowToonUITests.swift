//
//  meowToonUITests.swift
//  meowToonUITests
//
//  App Store screenshot automation (Fastlane snapshot).
//

import XCTest

@MainActor
final class meowToonUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "YES"]
        setupSnapshot(app)
        app.launch()
    }

    func testCaptureScreenshots() throws {
        // ── 01 — Home (favorites grid) ──────────────────────────────────
        let favorite = app.buttons["favoriteCard"].firstMatch
        XCTAssertTrue(favorite.waitForExistence(timeout: 15),
                      "Home screen with seeded favorites should appear")
        snapshot("01_Home")

        // ── 02 — Browser (open the Famelack favorite) ───────────────────
        favorite.tap()
        // Give the WebView time to render its chrome / page content
        Thread.sleep(forTimeInterval: 4.0)
        snapshot("02_Browser")

        // ── 03 — Settings ───────────────────────────────────────────────
        let settings = app.buttons["nav.settings"].firstMatch
        if settings.waitForExistence(timeout: 8) {
            settings.tap()
            Thread.sleep(forTimeInterval: 1.5)
            snapshot("03_Settings")
        }
    }
}
