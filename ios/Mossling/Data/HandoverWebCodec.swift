import Foundation

/// Compact JSON payload embedded inside URL fragments (`#d=<base64url>`) for zero-server Care Handover Beacons.
struct HandoverWebPayload: Codable, Equatable, Sendable {
    var v: Int
    var l: String
    var n: String
    var a: String
    var d: String
    var t: String
    var ts: Int64
    var ac: String?
    var f1: String
    var f2: String
    var s1: String
    var s2: String
    var p1: String
    var p2: String
    var r1: String
    var r2: String
    var no: String?
}

/// Pure, testable URL-fragment encoder/decoder enabling instant Android & browser shift previews
/// without sending any baby care data to a backend server.
enum HandoverWebCodec {
    static let defaultOrigin = "https://mossotto.pages.dev/"

    @MainActor
    static func makePayload(
        from snapshot: HandoverSnapshot,
        now: Date = Date(),
        isEnglish: Bool? = nil
    ) -> HandoverWebPayload {
        let english = isEnglish ?? L10n.isEnglish
        return HandoverWebPayload(
            v: 1,
            l: english ? "en" : "zh",
            n: String(snapshot.babyName.prefix(24)),
            a: String(snapshot.ageText.prefix(28)),
            d: String(snapshot.dateLabel.prefix(24)),
            t: String(snapshot.timeLabel.prefix(12)),
            ts: Int64(now.timeIntervalSince1970 * 1000),
            ac: snapshot.activeTimerLine.map { String($0.prefix(60)) },
            f1: String(snapshot.lastFeedHeadline.prefix(32)),
            f2: String(snapshot.lastFeedDetail.prefix(48)),
            s1: String(snapshot.lastSleepHeadline.prefix(32)),
            s2: String(snapshot.lastSleepDetail.prefix(48)),
            p1: String(snapshot.lastDiaperHeadline.prefix(32)),
            p2: String(snapshot.lastDiaperDetail.prefix(48)),
            r1: String(snapshot.todayHeadline.prefix(36)),
            r2: String(snapshot.todayDetail.prefix(48)),
            no: snapshot.extraNote.isEmpty ? nil : String(snapshot.extraNote.prefix(120))
        )
    }

    @MainActor
    static func encodeURL(
        from snapshot: HandoverSnapshot,
        now: Date = Date(),
        isEnglish: Bool? = nil,
        baseURLString: String? = nil
    ) -> URL? {
        let payload = makePayload(from: snapshot, now: now, isEnglish: isEnglish)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let json = try? encoder.encode(payload) else { return nil }

        let base64 = json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let originRaw = (baseURLString ?? (Owner.website.isEmpty ? defaultOrigin : Owner.website))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: originRaw) else { return nil }
        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = trimmedPath.isEmpty ? "/handover" : "/\(trimmedPath)/handover"
        components.query = nil
        components.fragment = "d=\(base64)"
        return components.url
    }

    static func decode(from url: URL) -> HandoverWebPayload? {
        guard let fragment = url.fragment, !fragment.isEmpty else { return nil }
        let pairs = fragment.split(separator: "&")
        guard let rawToken = pairs.first(where: { $0.hasPrefix("d=") })?.dropFirst(2), !rawToken.isEmpty else {
            return nil
        }
        var b64 = String(rawToken)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = b64.count % 4
        if remainder > 0 {
            b64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONDecoder().decode(HandoverWebPayload.self, from: data)
    }
}
