import SwiftUI

/// The four canonical top-level tabs of Moss & Otto:
/// Explore (`摸索`, Moss), Lamp (`台灯`, Otto), Keepsakes (`留念`, Moss x Otto), Studio (`工坊`).
enum AppTab: Int, CaseIterable, Hashable, Sendable {
    case explore = 0
    case lamp = 1
    case keepsakes = 2
    case studio = 3
}

/// Routes pushed strictly inside Tab 0 (`摸索 / Explore`).
enum ExploreRoute: Hashable, Sendable {
    case play(String, Int)
    case plan
    case toybox(ToyboxMode)
    case foodAtlas
    case search
}

/// Routes pushed strictly inside Tab 1 (`台灯 / Lamp`).
enum LampRoute: Hashable, Sendable {
    case rhythm(Int)
    case stats
}

/// Routes pushed strictly inside Tab 2 (`留念 / Keepsakes`).
enum KeepsakesRoute: Hashable, Sendable {
    case month(Int)
    case observe(Int)
    case areas(Int)
    case care(Int)
    case notes(Int)
    case topic(String)
    case firsts
    case growth
    case capsules
}

/// Routes pushed strictly inside Tab 3 (`工坊 / Studio`).
enum StudioRoute: Hashable, Sendable {
    case story
    case sources
    case releaseNotes
    case data
    case doc(String)
    case licenses
}

/// Canonical Single-Source-of-Truth destination used by Global Search and URL deep links.
/// Every destination maps deterministically to its ONE owning tab rather than pushing onto foreign stacks.
enum CanonicalDestination: Hashable, Sendable {
    case exploreRoot
    case play(String, Int)
    case plan
    case toybox(ToyboxMode)
    case foodAtlas
    case search

    case lampRoot
    case bedsideLamp
    case lampLedger
    case rhythm(Int)
    case stats

    case keepsakesRoot
    case storybook
    case month(Int)
    case observe(Int)
    case areas(Int)
    case care(Int)
    case notes(Int)
    case topic(String)
    case firsts
    case growth
    case capsules

    case studioRoot
    case story
    case sources
    case releaseNotes
    case data
    case doc(String)
    case licenses

    /// Strictly disjoint canonical ownership map across the four top-level tabs.
    /// Retired duplicate routes (`about`, `fullJournal`, `book`, `journey`) are intentionally absent.
    static let ownedFeatureKeysByTab: [AppTab: Set<String>] = [
        .explore: ["play", "plan", "toybox", "foodAtlas", "search"],
        .lamp: ["bedsideLamp", "rhythm", "stats", "careLedger", "handover"],
        .keepsakes: ["month", "observe", "areas", "care", "notes", "topic", "storybook", "firsts", "growth", "capsules"],
        .studio: ["story", "sources", "releaseNotes", "data", "doc", "licenses"]
    ]

    static func owner(of destination: CanonicalDestination) -> AppTab {
        switch destination {
        case .exploreRoot, .play, .plan, .toybox, .foodAtlas, .search:
            return .explore
        case .lampRoot, .bedsideLamp, .lampLedger, .rhythm, .stats:
            return .lamp
        case .keepsakesRoot, .storybook, .month, .observe, .areas, .care, .notes, .topic, .firsts, .growth, .capsules:
            return .keepsakes
        case .studioRoot, .story, .sources, .releaseNotes, .data, .doc, .licenses:
            return .studio
        }
    }

    var exploreRoute: ExploreRoute? {
        switch self {
        case let .play(code, month): .play(code, month)
        case .plan: .plan
        case let .toybox(mode): .toybox(mode)
        case .foodAtlas: .foodAtlas
        case .search: .search
        default: nil
        }
    }

    var lampRoute: LampRoute? {
        switch self {
        case let .rhythm(month): .rhythm(month)
        case .stats: .stats
        default: nil
        }
    }

    var keepsakesRoute: KeepsakesRoute? {
        switch self {
        case let .month(month): .month(month)
        case let .observe(month): .observe(month)
        case let .areas(month): .areas(month)
        case let .care(month): .care(month)
        case let .notes(month): .notes(month)
        case let .topic(id): .topic(id)
        case .firsts: .firsts
        case .growth: .growth
        case .capsules: .capsules
        default: nil
        }
    }

    var studioRoute: StudioRoute? {
        switch self {
        case .story: .story
        case .sources: .sources
        case .releaseNotes: .releaseNotes
        case .data: .data
        case let .doc(name): .doc(name)
        case .licenses: .licenses
        default: nil
        }
    }
}

/// Central tab-switching & stack coordinator ensuring Single-Source-of-Truth spatial clarity.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: Int = AppTab.explore.rawValue
    var explorePath = NavigationPath()
    var lampPath = NavigationPath()
    var keepsakesPath = NavigationPath()
    var studioPath = NavigationPath()
    var showingBedsideLamp = false
    var showingStorybook = false
    var expandLampLedgerToken: Int = 0
    private var pendingRouteTask: Task<Void, Never>?

    func resetToRoot() {
        pendingRouteTask?.cancel()
        pendingRouteTask = nil
        showingBedsideLamp = false
        showingStorybook = false
        explorePath = NavigationPath()
        lampPath = NavigationPath()
        keepsakesPath = NavigationPath()
        studioPath = NavigationPath()
        selectedTab = AppTab.explore.rawValue
    }

    func openExplore(_ route: ExploreRoute? = nil) {
        pendingRouteTask?.cancel()
        pendingRouteTask = nil
        let needsSwitch = selectedTab != AppTab.explore.rawValue
        selectedTab = AppTab.explore.rawValue
        guard let route else {
            explorePath = NavigationPath()
            return
        }
        if needsSwitch {
            explorePath = NavigationPath()
            pendingRouteTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(90))
                guard !Task.isCancelled else { return }
                self?.explorePath = NavigationPath([route])
            }
        } else {
            explorePath.append(route)
        }
    }

    func openLamp(_ route: LampRoute? = nil, expandLedger: Bool = false) {
        pendingRouteTask?.cancel()
        pendingRouteTask = nil
        let needsSwitch = selectedTab != AppTab.lamp.rawValue
        selectedTab = AppTab.lamp.rawValue
        if expandLedger {
            expandLampLedgerToken &+= 1
        }
        guard let route else {
            lampPath = NavigationPath()
            return
        }
        if needsSwitch {
            lampPath = NavigationPath()
            pendingRouteTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(90))
                guard !Task.isCancelled else { return }
                self?.lampPath = NavigationPath([route])
            }
        } else {
            lampPath.append(route)
        }
    }

    func openBedsideLamp() {
        showingBedsideLamp = true
    }

    func openKeepsakes(_ route: KeepsakesRoute? = nil) {
        pendingRouteTask?.cancel()
        pendingRouteTask = nil
        let needsSwitch = selectedTab != AppTab.keepsakes.rawValue
        selectedTab = AppTab.keepsakes.rawValue
        guard let route else {
            keepsakesPath = NavigationPath()
            return
        }
        if needsSwitch {
            keepsakesPath = NavigationPath()
            pendingRouteTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(90))
                guard !Task.isCancelled else { return }
                self?.keepsakesPath = NavigationPath([route])
            }
        } else {
            keepsakesPath.append(route)
        }
    }

    func openStorybook() {
        showingStorybook = true
    }

    func openStudio(_ route: StudioRoute? = nil) {
        pendingRouteTask?.cancel()
        pendingRouteTask = nil
        let needsSwitch = selectedTab != AppTab.studio.rawValue
        selectedTab = AppTab.studio.rawValue
        guard let route else {
            studioPath = NavigationPath()
            return
        }
        if needsSwitch {
            studioPath = NavigationPath()
            pendingRouteTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(90))
                guard !Task.isCancelled else { return }
                self?.studioPath = NavigationPath([route])
            }
        } else {
            studioPath.append(route)
        }
    }

    func open(_ destination: CanonicalDestination) {
        switch destination {
        case .exploreRoot:
            openExplore(nil)
        case let .play(code, month):
            openExplore(.play(code, month))
        case .plan:
            openExplore(.plan)
        case let .toybox(mode):
            openExplore(.toybox(mode))
        case .foodAtlas:
            openExplore(.foodAtlas)
        case .search:
            openExplore(.search)

        case .lampRoot:
            openLamp(nil)
        case .bedsideLamp:
            pendingRouteTask?.cancel()
            pendingRouteTask = nil
            selectedTab = AppTab.lamp.rawValue
            openBedsideLamp()
        case .lampLedger:
            openLamp(nil, expandLedger: true)
        case let .rhythm(month):
            openLamp(.rhythm(month))
        case .stats:
            openLamp(.stats)

        case .keepsakesRoot:
            openKeepsakes(nil)
        case .storybook:
            pendingRouteTask?.cancel()
            pendingRouteTask = nil
            selectedTab = AppTab.keepsakes.rawValue
            openStorybook()
        case let .month(month):
            openKeepsakes(.month(month))
        case let .observe(month):
            openKeepsakes(.observe(month))
        case let .areas(month):
            openKeepsakes(.areas(month))
        case let .care(month):
            openKeepsakes(.care(month))
        case let .notes(month):
            openKeepsakes(.notes(month))
        case let .topic(id):
            openKeepsakes(.topic(id))
        case .firsts:
            openKeepsakes(.firsts)
        case .growth:
            openKeepsakes(.growth)
        case .capsules:
            openKeepsakes(.capsules)

        case .studioRoot:
            openStudio(nil)
        case .story:
            openStudio(.story)
        case .sources:
            openStudio(.sources)
        case .releaseNotes:
            openStudio(.releaseNotes)
        case .data:
            openStudio(.data)
        case let .doc(name):
            openStudio(.doc(name))
        case .licenses:
            openStudio(.licenses)
        }
    }
}
