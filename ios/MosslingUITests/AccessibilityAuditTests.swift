import XCTest

/// Runs Xcode's accessibility audit (the same checks as Accessibility Inspector: labels, contrast, hit regions,
/// clipped text under Dynamic Type, traits) on each tab and on the pages most used, at the default text size and at
/// the largest accessibility size. Issues are written to $SNAPSHOT_DIR/ios_a11y_<size>.txt (published with the
/// screenshots) so every build leaves a reviewable list; the test itself does not fail on them.
final class AccessibilityAuditTests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    /// The look is pinned, so a run in the evening is not silently audited by lamplight (自动 turns the lamp on
    /// 19:00–06:00): 日光 at both sizes, and 夜灯 at the default size as its own list.
    private func launch(_ size: String?, theme: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        // a six-month-old, records on; settings come in through the argument domain of UserDefaults
        let birth = Int(Date().timeIntervalSince1970 / 86_400) - 186
        app.launchArguments = ["-onboarded", "YES", "-consent", "2026-10-31", "-birth", "\(birth)", "-journal", "YES", "-nickname", "小满", "-sex", "girl", "-lock", "NO", "-auditStill", "YES", "-theme", theme, "-nightLight", "NO",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if let size { app.launchArguments += ["-UIPreferredContentSizeCategoryName", size] }
        app.launch()
        return app
    }

    private var lines: [String] = [], unlabeled: [String] = []

    /// The bars, and what they hold. Page text that has scrolled under a bar, or into the fade beside it, is drawn through its glass, so a contrast
    /// reading there measures the bar, not the page; those are skipped (and counted). The bars' own titles, buttons and
    /// tab labels are kept: their contrast is real.
    private func bars(_ app: XCUIApplication) -> (frames: [CGRect], own: Set<String>) {
        let nav = app.navigationBars.firstMatch, tab = app.tabBars.firstMatch
        var frames: [CGRect] = [], own = Set<String>()
        // each bar with the strip where iOS 26 fades the page into it (the scroll edge effect): from the top of the
        // screen to 8 points under the navigation bar, and from 24 points above the tab bar to the bottom
        if nav.exists { frames.append(CGRect(x: 0, y: 0, width: app.frame.width, height: nav.frame.maxY + 8)) }
        if tab.exists { frames.append(CGRect(x: 0, y: tab.frame.minY - 24, width: app.frame.width, height: app.frame.maxY - tab.frame.minY + 24)) }
        for bar in [nav, tab] where bar.exists {
            for e in bar.descendants(matching: .any).allElementsBoundByIndex { own.insert(Self.key(e.label, e.frame)) }
        }
        return (frames, own)
    }
    private static func key(_ label: String, _ f: CGRect) -> String { "\(label)@\(Int(f.minX)),\(Int(f.minY))" }
    private var skipped = 0
    /// Text heights by label, measured on each audited screen: the default-size run keeps them, the largest-size run
    /// compares — a text that has not grown to at least 1.3× its default height does not follow Dynamic Type. This is
    /// the measured check beside Apple's heuristic one.
    private var heights: [String: CGFloat] = [:]
    private static var defaultHeights: [String: CGFloat] = [:]
    private func measure(_ app: XCUIApplication) {
        for t in app.staticTexts.allElementsBoundByIndex where !t.label.trimmingCharacters(in: .whitespaces).isEmpty && t.frame.height > 0 {
            if heights[t.label] == nil { heights[t.label] = t.frame.height }
        }
    }

    private func audit(_ app: XCUIApplication, _ place: String, again: Bool = true) {
        let under = bars(app)
        shoot(app, place)
        measure(app)
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let e = issue.element
                if issue.auditType == .contrast, let e, under.frames.contains(where: { $0.intersects(e.frame) }),
                   !under.own.contains(Self.key(e.label, e.frame)) { self.skipped += 1; return true }
                let who = e.map { "\($0.elementType.rawValue) “\($0.label)” id=\($0.identifier) \(Int($0.frame.minX)),\(Int($0.frame.minY)) \(Int($0.frame.width))×\(Int($0.frame.height))" } ?? "—"
                self.lines.append("[\(place)] \(Self.name(issue.auditType)): \(issue.compactDescription) — \(who) · \(issue.detailedDescription)")
                if issue.auditType == .sufficientElementDescription, (e?.label ?? "").isEmpty { self.unlabeled.append("[\(place)] \(who)") }
                return true   // recorded, reviewed from the list
            }
        } catch {
            // the audit gives up when the page does not settle in time; once more after a pause
            if again { sleep(3); audit(app, place, again: false) } else { lines.append("[\(place)] audit failed: \((error as NSError).localizedDescription)") }
        }
    }

    /// A picture of each audited screen, published beside the list, so an issue can be found by its coordinates.
    private func shoot(_ app: XCUIApplication, _ place: String) {
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let slug = place.replacingOccurrences(of: " ↓", with: "_down")
        let name = "ios_a11y_\(sizeTag)_\(slug).png"
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: (dir as NSString).appendingPathComponent(name)))
    }
    private var sizeTag = "default"

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

    private func run(_ size: String?, file: String, theme: String = "light") {
        let app = launch(size, theme: theme)
        lines = []; unlabeled = []; skipped = 0; heights = [:]
        sizeTag = (size == nil ? "default" : "xxxl") + (theme == "dark" ? "_dark" : "")
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
        if size == nil && theme == "light" { Self.defaultHeights = heights }
        var measured: [String] = []
        if size != nil {
            for (label, h) in heights.sorted(by: { $0.key < $1.key }) {
                if let base = Self.defaultHeights[label], h < base * 1.3 { measured.append("measured: “\(label)” \(Int(base))pt → \(Int(h))pt") }
            }
            order += measured
        }
        let text = "\(order.count) issues (\(measured.count) by measurement; \(size ?? "default size"), \(theme == "dark" ? "夜灯" : "日光")); \(skipped) contrast readings skipped for page text under a bar; decorative motion stilled (as with Reduce Motion)\n\n" + order.map { b in "\(b)  @ \(seen[b]?.joined(separator: ", ") ?? "")" }.joined(separator: "\n") + "\n"
        try? text.write(toFile: (dir as NSString).appendingPathComponent(file), atomically: true, encoding: .utf8)
        // reported, not failed: the list is reviewed from the published file (a missing label is fixed in the next build)
        if !unlabeled.isEmpty { print("A11Y unlabeled: \(unlabeled.count)") }
    }

    func testAuditDefaultSize() { run(nil, file: "ios_a11y_default.txt") }
    func testAuditLamplight() { run(nil, file: "ios_a11y_dark.txt", theme: "dark") }
    func testAuditLargestText() { run("UICTContentSizeCategoryAccessibilityXXXL", file: "ios_a11y_xxxl.txt") }
}
