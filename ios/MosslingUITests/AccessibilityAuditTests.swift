import XCTest

/// Runs Xcode's accessibility audit (the same checks as Accessibility Inspector: labels, contrast, hit regions,
/// clipped text under Dynamic Type, traits) on each tab and on the pages most used, at the default text size and at
/// the largest accessibility size. Issues are written to $SNAPSHOT_DIR/ios_a11y_<size>.txt (published with the
/// screenshots) so every build leaves a reviewable list; the test itself does not fail on them.
final class AccessibilityAuditTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    private func launch(_ size: String?) -> XCUIApplication {
        let app = XCUIApplication()
        // a six-month-old, records on; settings come in through the argument domain of UserDefaults
        let birth = Int(Date().timeIntervalSince1970 / 86_400) - 186
        app.launchArguments = ["-onboarded", "YES", "-consent", "2026-10-31", "-birth", "\(birth)", "-journal", "YES", "-nickname", "小满", "-sex", "girl", "-lock", "NO",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
        app.launch()
        return app
    }

    private var lines: [String] = [], unlabeled: [String] = []

    private func audit(_ app: XCUIApplication, _ place: String, again: Bool = true) {
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let e = issue.element
                let who = e.map { "\($0.elementType.rawValue) “\($0.label)” id=\($0.identifier) \(Int($0.frame.minX)),\(Int($0.frame.minY)) \(Int($0.frame.width))×\(Int($0.frame.height))" } ?? "—"
                self.lines.append("[\(place)] \(Self.name(issue.auditType)): \(issue.compactDescription) — \(who)")
                if issue.auditType == .sufficientElementDescription, (e?.label ?? "").isEmpty { self.unlabeled.append("[\(place)] \(who)") }
                return true   // recorded, reviewed from the list
            }
        } catch {
            // the audit gives up when the page does not settle in time; once more after a pause
            if again { sleep(3); audit(app, place, again: false) } else { lines.append("[\(place)] audit failed: \((error as NSError).localizedDescription)") }
        }
    }

    private static func name(_ t: XCUIAccessibilityAuditType) -> String {
        switch t {
        case .contrast: "contrast"
        case .elementDetection: "element"
        case .hitRegion: "hit region"
        case .sufficientElementDescription: "description"
        case .dynamicType: "dynamic type"
        case .textClipped: "clipped"
        case .trait: "trait"
        default: "other(\(t.rawValue))"
        }
    }

    private func run(_ size: String?, file: String) {
        let app = launch(size)
        lines = []; unlabeled = []
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20), "tab bar")
        for tab in ["本月", "记录", "我的"] {
            let b = bar.buttons[tab]
            guard b.exists else { lines.append("[\(tab)] tab missing"); continue }
            b.tap(); sleep(2)
            audit(app, tab)
            // and the next screen of the page (more is too slow on the runner: the page never quite settles)
            app.swipeUp(velocity: .slow); sleep(2)
            audit(app, "\(tab) ↓")
        }
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        // one line per distinct issue, with the places it was seen
        var seen: [String: [String]] = [:], order: [String] = []
        for l in lines {
            guard let r = l.range(of: "] ") else { order.append(l); continue }
            let place = String(l[l.index(after: l.startIndex)..<r.lowerBound]), body = String(l[r.upperBound...])
            if seen[body] == nil { order.append(body) }
            seen[body, default: []].append(place)
        }
        let text = "\(order.count) issues (\(size ?? "default size"))\n\n" + order.map { b in "\(b)  @ \(seen[b]?.joined(separator: ", ") ?? "")" }.joined(separator: "\n") + "\n"
        try? text.write(toFile: (dir as NSString).appendingPathComponent(file), atomically: true, encoding: .utf8)
        // reported, not failed: the list is reviewed from the published file (a missing label is fixed in the next build)
        if !unlabeled.isEmpty { print("A11Y unlabeled: \(unlabeled.count)") }
    }

    func testAuditDefaultSize() { run(nil, file: "ios_a11y_default.txt") }
    func testAuditLargestText() { run("UICTContentSizeCategoryAccessibilityXXXL", file: "ios_a11y_xxxl.txt") }
}
