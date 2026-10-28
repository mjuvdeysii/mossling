import XCTest

/// How smoothly the home scrolls, measured the way Instruments does (hitch time ratio while dragging and while the
/// scroll decelerates), in the 3D world and in the 2D world. Run on demand (the "perf" input of the iOS workflow); the
/// numbers go to the run's notices so a change can be compared with the last one.
final class ScrollPerfTests: XCTestCase {
    private func launch(_ style: String) -> XCUIApplication {
        let app = XCUIApplication()
        let birth = Int(Date().timeIntervalSince1970 / 86_400) - 186
        app.launchArguments = ["-onboarded", "YES", "-birth", "\(birth)", "-journal", "YES", "-nickname", "小满", "-sex", "girl", "-lock", "NO",
                               "-artStyle", style, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        sleep(2)
        return app
    }

    private func scroll(_ style: String) {
        let app = launch(style)
        let opts = XCTMeasureOptions(); opts.iterationCount = 5
        measure(metrics: [XCTOSSignpostMetric.scrollDraggingMetric, XCTOSSignpostMetric.scrollDecelerationMetric], options: opts) {
            app.swipeUp(velocity: .fast)
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }

    func testHomeScroll3D() { scroll("3d") }
    func testHomeScroll2D() { scroll("2d") }
}
