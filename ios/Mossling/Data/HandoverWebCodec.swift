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
    var fts: Int64?
    var s1: String
    var s2: String
    var sts: Int64?
    var p1: String
    var p2: String
    var pts: Int64?
    var r1: String
    var r2: String
    var no: String?
}

/// Pure, testable URL-fragment encoder/decoder enabling instant Android & browser shift previews
/// without sending any baby care data to a backend server.
enum HandoverWebCodec {
    static let defaultOrigin = "https://mossotto.pages.dev/"

    private static func sanitizedBeaconText(_ raw: String, limit: Int, english: Bool, isNote: Bool) -> String {
        let lower = raw.lowercased()
        let sensitiveTokens = [
            LogType.name(LogType.temp).lowercased(),
            LogType.name(LogType.medicine).lowercased(),
            "°c", "°f", "体温", "发烧", "发热", "退烧", "用药", "药物", "维生素",
            "布洛芬", "美林", "泰诺", "对乙酰氨基酚",
            "temp", "fever", "medication", "medicine", "med ", "vitamin",
            "ibuprofen", "tylenol", "paracetamol", "acetaminophen", "motrin", "advil"
        ]
        if sensitiveTokens.contains(where: { lower.contains($0) }) {
            if isNote {
                return english ? "See family card for care notes" : "体征与用药详情请见当面交接卡"
            }
            return english ? "See family card for care notes" : "详细体征请见交接卡"
        }
        return String(raw.prefix(limit))
    }

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
            fts: snapshot.feedTimestampSec,
            s1: String(snapshot.lastSleepHeadline.prefix(32)),
            s2: String(snapshot.lastSleepDetail.prefix(48)),
            sts: snapshot.sleepTimestampSec,
            p1: String(snapshot.lastDiaperHeadline.prefix(32)),
            p2: String(snapshot.lastDiaperDetail.prefix(48)),
            pts: snapshot.diaperTimestampSec,
            r1: String(snapshot.todayHeadline.prefix(36)),
            r2: sanitizedBeaconText(snapshot.todayDetail, limit: 48, english: english, isNote: false),
            no: snapshot.extraNote.isEmpty ? nil : sanitizedBeaconText(snapshot.extraNote, limit: 120, english: english, isNote: true)
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

/// Compact JSON payload embedded inside URL fragments (`#d=<base64url>`) for zero-server grandparent H5 Exploration Cards.
struct CardWebPayload: Codable, Equatable, Sendable {
    var v: Int
    var l: String
    var k: String   // "lamp" or "play"
    var id: String
    var st: String  // Stage title or age/domain badge
    var ti: String  // Headline or play title
    var sa: String  // Say-aloud line or gentle observation cue
    var ac: String  // Micro-action or setup cue
    var steps: [String]?
    var tr: String  // Plain-language translation / rhythm cue
    var gp: String  // Grandparent tip or calm pause cue
    var src: String // Clinical/curriculum source summary
    var mo: Int
    var b: String?  // Optional baby nickname
    var n: String?  // Optional family note
}

/// Pure, zero-server URL-fragment codec targeting `/card#d=<base64url>` for one-tap WeChat/Messages family sharing.
enum CardWebCodec {
    static let defaultOrigin = HandoverWebCodec.defaultOrigin

    @MainActor
    static func makePayload(
        from card: LampCard,
        babyName: String = "",
        month: Int? = nil,
        note: String? = nil,
        isEnglish: Bool? = nil
    ) -> CardWebPayload {
        let english = isEnglish ?? L10n.isEnglish
        let trimmedBaby = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CardWebPayload(
            v: 1,
            l: english ? "en" : "zh",
            k: "lamp",
            id: card.id,
            st: english ? card.stageTitleEn : card.stageTitleZh,
            ti: english ? card.headlineEn : card.headlineZh,
            sa: english ? card.sayAloudEn : card.sayAloudZh,
            ac: english ? card.microActionEn : card.microActionZh,
            steps: nil,
            tr: english ? card.translationEn : card.translationZh,
            gp: english ? card.grandparentNoteEn : card.grandparentNoteZh,
            src: card.meta.sources.map { src in
                "\(src.org) · \(english ? src.docEn : src.docZh) (\(src.year))"
            }.joined(separator: english ? "; " : "；"),
            mo: max(0, min(36, month ?? card.minMonth)),
            b: trimmedBaby.isEmpty ? nil : String(trimmedBaby.prefix(20)),
            n: (trimmedNote?.isEmpty == false) ? String(trimmedNote!.prefix(120)) : nil
        )
    }

    @MainActor
    static func makePayload(
        from play: Play,
        babyName: String = "",
        note: String? = nil,
        isEnglish: Bool? = nil
    ) -> CardWebPayload {
        let english = isEnglish ?? L10n.isEnglish
        let trimmedBaby = babyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let domainLabel = play.domains.prefix(2).joined(separator: " · ")
        let stage = domainLabel.isEmpty ? play.age : "\(play.age) · \(domainLabel)"
        return CardWebPayload(
            v: 1,
            l: english ? "en" : "zh",
            k: "play",
            id: play.code,
            st: String(stage.prefix(48)),
            ti: play.name,
            sa: play.observe,
            ac: play.prepare,
            steps: Array(play.steps.prefix(4)),
            tr: play.pause,
            gp: play.safety,
            src: english ? "Moss & Otto Play Library (\(play.code))" : "摸索台灯线下游戏卡（\(play.code)）",
            mo: max(0, min(36, play.from)),
            b: trimmedBaby.isEmpty ? nil : String(trimmedBaby.prefix(20)),
            n: (trimmedNote?.isEmpty == false) ? String(trimmedNote!.prefix(120)) : nil
        )
    }

    @MainActor
    static func encodeURL(
        _ payload: CardWebPayload,
        baseURLString: String? = nil
    ) -> URL? {
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
        components.path = trimmedPath.isEmpty ? "/card" : "/\(trimmedPath)/card"
        components.query = nil
        components.fragment = "d=\(base64)"
        return components.url
    }

    @MainActor
    static func encodeURL(
        from card: LampCard,
        babyName: String = "",
        month: Int? = nil,
        note: String? = nil,
        isEnglish: Bool? = nil,
        baseURLString: String? = nil
    ) -> URL? {
        encodeURL(
            makePayload(from: card, babyName: babyName, month: month, note: note, isEnglish: isEnglish),
            baseURLString: baseURLString
        )
    }

    @MainActor
    static func encodeURL(
        from play: Play,
        babyName: String = "",
        note: String? = nil,
        isEnglish: Bool? = nil,
        baseURLString: String? = nil
    ) -> URL? {
        encodeURL(
            makePayload(from: play, babyName: babyName, note: note, isEnglish: isEnglish),
            baseURLString: baseURLString
        )
    }

    static func decode(from url: URL) -> CardWebPayload? {
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
        return try? JSONDecoder().decode(CardWebPayload.self, from: data)
    }
}

