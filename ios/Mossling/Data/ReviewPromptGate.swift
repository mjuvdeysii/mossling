import Foundation
import StoreKit

/// Gentle daytime-only App Store review request gate (never interrupts midnight feeds or bedside lamp use).
enum ReviewPromptGate {
    static let versionKey = "mossling.reviewPromptedVersion"
    static let dateKey = "mossling.reviewPromptedAt"

    /// Pure deterministic eligibility check shared between runtime keepsake triggers and unit tests.
    static func shouldRequestReview(
        now: Date = Date(),
        isDarkMode: Bool,
        isBedsideLamp: Bool,
        keepsakeCount: Int,
        currentVersion: String,
        lastPromptedVersion: String?,
        lastPromptedAt: Date?
    ) -> Bool {
        let hour = Day.cal.component(.hour, from: now)
        guard (8..<19).contains(hour) else { return false }
        guard !isDarkMode, !isBedsideLamp else { return false }
        guard keepsakeCount >= 3 else { return false }
        let ver = currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ver.isEmpty, lastPromptedVersion != ver else { return false }
        if let lastPromptedAt, now.timeIntervalSince(lastPromptedAt) < 60 * 86_400 {
            return false
        }
        return true
    }

    static func appVersion(bundle: Bundle = .main) -> String {
        (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.3.2"
    }

    /// Requests an in-app review calmly after a joyful daytime keepsake confirmation (at most once per version / 60 days).
    @MainActor
    static func tryTrigger(
        perform: () -> Void,
        isDarkMode: Bool,
        isBedsideLamp: Bool,
        keepsakeCount: Int,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let currentVer = appVersion()
        let lastVer = defaults.string(forKey: versionKey)
        let lastTs = defaults.object(forKey: dateKey) as? Double
        let lastDate = lastTs.map { Date(timeIntervalSince1970: $0) }
        guard shouldRequestReview(
            now: now,
            isDarkMode: isDarkMode,
            isBedsideLamp: isBedsideLamp,
            keepsakeCount: keepsakeCount,
            currentVersion: currentVer,
            lastPromptedVersion: lastVer,
            lastPromptedAt: lastDate
        ) else { return }

        defaults.set(currentVer, forKey: versionKey)
        defaults.set(now.timeIntervalSince1970, forKey: dateKey)
        perform()
    }
}
