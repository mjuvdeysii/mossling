import SwiftUI
import UniformTypeIdentifiers

/// The family's record file: everything recorded, in the same format as the Android app ("app": "mossling"), so it
/// moves between the two. Also a table of entries and measurements for a spreadsheet or the doctor.
enum RecordFile {
    static func json(_ app: AppModel, _ j: JournalFile.Body) -> Data {
        var settings: [String: Any] = ["companion": app.companion.rawValue]
        if let b = app.birth { settings["birth"] = String(format: "%04d-%02d-%02d", b.y, b.m, b.d) }
        if let s = app.sex { settings["sex"] = s }
        if !app.nickname.isEmpty { settings["nickname"] = app.nickname }
        let ticks = app.ticks.values.map { ["key": $0.key, "month": $0.month, "kind": $0.kind, "label": $0.label, "at": Int64($0.at)] as [String: Any] }
        let logs = j.logs.map { e -> [String: Any] in
            var o: [String: Any] = ["type": e.type, "start": Int64(e.start)]
            if let v = e.end { o["end"] = Int64(v) }; if let v = e.amount { o["amount"] = v }; if let v = e.side { o["side"] = v }; if let v = e.detail { o["detail"] = v }
            return o
        }
        let measures = j.measures.map { m -> [String: Any] in
            var o: [String: Any] = ["at": Int64(m.at)]
            if let v = m.weightG { o["weightG"] = v }; if let v = m.lengthMm { o["lengthMm"] = v }; if let v = m.headMm { o["headMm"] = v }
            return o
        }
        let root: [String: Any] = ["app": "mossling", "v": 1, "at": ISO8601DateFormatter().string(from: Date()),
                                   "mossling": ["v": 1, "settings": settings, "ticks": ticks, "logs": logs, "measures": measures]]
        return (try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])) ?? Data()
    }

    enum Failure: Error { case notOurs }

    /// Reads a record file and replaces what is on the phone with it.
    static func load(_ data: Data, into app: AppModel, journal: JournalStore) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["app"] as? String == "mossling",
              let m = root["mossling"] as? [String: Any] else { throw Failure.notOurs }
        func num(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }
        let s = m["settings"] as? [String: Any] ?? [:]
        if let b = s["birth"] as? String {
            let p = b.split(separator: "-").compactMap { Int($0) }
            if p.count == 3 { app.birth = Day(y: p[0], m: p[1], d: p[2]) }
        }
        app.sex = s["sex"] as? String
        app.nickname = s["nickname"] as? String ?? ""
        if let c = s["companion"] as? String, let k = Kind(rawValue: c) { app.companion = k }
        let ticks = (m["ticks"] as? [[String: Any]] ?? []).compactMap { t -> Tick? in
            guard let key = t["key"] as? String, let mo = num(t["month"]), let kind = t["kind"] as? String else { return nil }
            return Tick(key: key, month: Int(mo), kind: kind, label: t["label"] as? String ?? "", at: num(t["at"]) ?? 0)
        }
        app.replaceTicks(ticks)
        var body = JournalFile.Body()
        body.logs = (m["logs"] as? [[String: Any]] ?? []).compactMap { o in
            guard let type = o["type"] as? String, let start = num(o["start"]) else { return nil }
            return LogEntry(type: type, start: start, end: num(o["end"]), amount: num(o["amount"]).map { Int($0) }, side: o["side"] as? String, detail: o["detail"] as? String)
        }
        body.measures = (m["measures"] as? [[String: Any]] ?? []).compactMap { o in
            guard let at = num(o["at"]) else { return nil }
            return Measure(at: at, weightG: num(o["weightG"]).map { Int($0) }, lengthMm: num(o["lengthMm"]).map { Int($0) }, headMm: num(o["headMm"]).map { Int($0) })
        }
        if !body.logs.isEmpty || !body.measures.isEmpty { app.journal = true }
        journal.replaceAll(body)
    }

    static func csv(_ j: JournalFile.Body) -> Data {
        func day(_ ms: Double) -> String { let d = Day(Date(timeIntervalSince1970: ms / 1000)); return String(format: "%04d-%02d-%02d", d.y, d.m, d.d) }
        func t(_ ms: Double) -> String { hm(Date(timeIntervalSince1970: ms / 1000)) }
        func q(_ v: String) -> String { v.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : v }
        var s = "\u{FEFF}日期,开始,结束,时长（分钟）,类型,数量,单位,侧,详情\n"
        for e in j.logs.sorted(by: { $0.start < $1.start }) {
            let (amt, unit): (String, String) = e.type == LogType.bottle ? ("\(e.amount ?? 0)", "毫升") : e.type == LogType.temp ? (e.amount.map { String(format: "%.1f", Double($0) / 10) } ?? "", "°C") : ("", "")
            let side = e.side == "l" ? "左" : e.side == "r" ? "右" : ""
            let detail = e.type == LogType.diaper ? (["wet": "湿", "dirty": "便", "both": "湿和便"][e.detail ?? ""] ?? "") : (e.detail ?? "")
            s += [day(e.start), t(e.start), e.end.map(t) ?? "", e.end.map { "\(Int(($0 - e.start) / 60_000))" } ?? "", LogType.name(e.type), amt, unit, side, q(detail)].joined(separator: ",") + "\n"
        }
        for m in j.measures {
            if let w = m.weightG { s += [day(m.at), t(m.at), "", "", "体重", String(format: "%.2f", Double(w) / 1000), "千克", "", ""].joined(separator: ",") + "\n" }
            if let l = m.lengthMm { s += [day(m.at), t(m.at), "", "", "身长", String(format: "%.1f", Double(l) / 10), "厘米", "", ""].joined(separator: ",") + "\n" }
            if let h = m.headMm { s += [day(m.at), t(m.at), "", "", "头围", String(format: "%.1f", Double(h) / 10), "厘米", "", ""].joined(separator: ",") + "\n" }
        }
        return Data(s.utf8)
    }
}

/// A file to hand to the system's save dialog.
struct DataFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
