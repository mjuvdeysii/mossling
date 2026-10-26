import SwiftUI
import UniformTypeIdentifiers

/// The family's record file: everything recorded, in the same format as the Android app ("app": "mossling"), so it
/// moves between the two. Also a table of entries and measurements for a spreadsheet or the doctor.
enum RecordFile {
    static func json(_ app: AppModel, _ j: JournalFile.Body) -> Data {
        // everything set and recorded on this phone: the child, the companion, the appearance, the week's shelf, the
        // month records (observed, played, vaccines and check-ups), every entry, every measurement, and what is being
        // timed right now. Android reads the keys it knows and leaves the rest.
        var settings: [String: Any] = ["companion": app.companion.rawValue, "theme": app.theme.rawValue, "nightLight": app.nightLight,
                                       "journal": app.journal, "shelf": app.shelf]
        if let b = app.birth { settings["birth"] = String(format: "%04d-%02d-%02d", b.y, b.m, b.d) }
        if let s = app.sex { settings["sex"] = s }
        if let l = app.look { settings["look"] = l }
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
        let timers = j.timers.map { t -> [String: Any] in
            var o: [String: Any] = ["type": t.type, "start": Int64(t.start), "pausedTotal": Int64(t.pausedTotal), "carried": Int64(t.carried), "carriedPause": Int64(t.carriedPause)]
            if let v = t.side { o["side"] = v }; if let v = t.pausedAt { o["pausedAt"] = Int64(v) }
            return o
        }
        let root: [String: Any] = ["app": "mossling", "v": 1, "at": ISO8601DateFormatter().string(from: Date()),
                                   "mossling": ["v": 1, "settings": settings, "ticks": ticks, "logs": logs, "measures": measures, "timers": timers]]
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
        if let v = s["look"] as? String { app.look = v }
        if let v = s["theme"] as? String, let t = ThemeMode(rawValue: v) { app.theme = t }
        if let v = s["nightLight"] as? Bool { app.nightLight = v }
        if let v = s["shelf"] as? String { app.shelf = v }
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
        body.timers = (m["timers"] as? [[String: Any]] ?? []).compactMap { o in
            guard let type = o["type"] as? String, let start = num(o["start"]) else { return nil }
            return RunningTimer(type: type, start: start, side: o["side"] as? String, pausedAt: num(o["pausedAt"]), pausedTotal: num(o["pausedTotal"]) ?? 0,
                                carried: num(o["carried"]) ?? 0, carriedPause: num(o["carriedPause"]) ?? 0)
        }
        if let v = s["journal"] as? Bool { app.journal = v }
        if !body.logs.isEmpty || !body.measures.isEmpty { app.journal = true }
        journal.replaceAll(body)
    }

    /// Everything recorded, as a document a paediatrician can read, or that a parent can hand to an AI assistant to look
    /// at: who the child is, the growth measurements with WHO percentiles, a day-by-day summary, what was noted and done
    /// month by month, and every entry in order. The app makes no assessment of its own; this is the record, in words.
    static func summary(_ app: AppModel, _ j: JournalFile.Body) -> Data {
        func date(_ ms: Double) -> String { let d = Day(Date(timeIntervalSince1970: ms / 1000)); return String(format: "%04d-%02d-%02d", d.y, d.m, d.d) }
        func time(_ ms: Double) -> String { hm(Date(timeIntervalSince1970: ms / 1000)) }
        var o = "# 摸索台灯 · 成长与照护记录\n\n"
        o += "导出时间：\(date(JournalFile.now())) \(time(JournalFile.now()))\n\n"
        o += "## 孩子\n\n"
        o += "- 小名：\(app.nickname.isEmpty ? "未填写" : app.nickname)\n"
        o += "- 性别：\(app.sex == "girl" ? "女" : app.sex == "boy" ? "男" : "未填写")\n"
        if let b = app.birth, let a = app.age {
            o += String(format: "- 出生日期：%04d-%02d-%02d\n", b.y, b.m, b.d)
            o += "- 今天：满 \(a.months) 个月 \(a.days) 天\n"
        } else { o += "- 出生日期：未填写\n" }
        o += "\n## 说明\n\n记录由家长在摸索台灯中自行录入，应用不做发育评估或医疗判断。可交给儿科医生参考；也可以交给 AI 助手，请它在说明自身局限的前提下帮助整理和提出值得向医生询问的问题。生长百分位按世界卫生组织儿童生长标准（2006）计算。\n"

        // growth
        let ms = j.measures.sorted { $0.at < $1.at }
        if !ms.isEmpty {
            o += "\n## 生长测量\n\n| 日期 | 月龄 | 体重（千克） | 身长 / 身高（厘米） | 头围（厘米） |\n|---|---|---|---|---|\n"
            for m in ms {
                let months = app.birth.map { Double(Day(Date(timeIntervalSince1970: m.at / 1000)).epochDay - $0.epochDay) / 30.4375 }
                func cell(_ v: Int?, _ i: Indicator, _ k: Double) -> String {
                    guard let v else { return "" }
                    let x = Double(v) / k
                    let p = months.flatMap { mo in mo >= 0 && mo <= 36 && app.sex != nil ? app.growth.percentile(i, girl: app.girl, months: mo, value: x) : nil }
                    return i.fmt(x) + (p.map { "（" + pctText($0) + "）" } ?? "")
                }
                let row: [String] = [date(m.at), months.map { String(format: "%.1f", $0) } ?? "", cell(m.weightG, .weight, 1000), cell(m.lengthMm, .length, 10), cell(m.headMm, .head, 10)]
                o += "| " + row.joined(separator: " | ") + " |\n"
            }
        }

        // day by day
        let logs = j.logs.sorted { $0.start < $1.start }
        if let first = logs.first {
            o += "\n## 每天汇总\n\n| 日期 | 喂奶次数 | 亲喂 | 瓶喂 | 睡眠 | 尿布（湿 / 便） | 体温最高 | 辅食 | 用药 |\n|---|---|---|---|---|---|---|---|---|\n"
            var d = Day(first.startDate); let last = Day.today
            while d.epochDay <= last.epochDay {
                let a0 = d.date.timeIntervalSince1970 * 1000, b0 = d.plus(days: 1).date.timeIntervalSince1970 * 1000
                let day = j.logs.filter { e in (e.start >= a0 && e.start < b0) || (e.start < a0 && (e.end ?? e.start) > a0) }
                if !day.isEmpty {
                    let own = day.filter { !$0.carriedOver(into: d) }
                    let feeds = day.feedCount(from: d.date.timeIntervalSince1970 * 1000)
                    let nursed = day.filter { $0.type == LogType.nurse && $0.end != nil }.reduce(0.0) { $0 + $1.seconds(on: d) }
                    let ml = own.filter { $0.type == LogType.bottle }.reduce(0) { $0 + ($1.amount ?? 0) }
                    let sleep = day.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: d) }
                    let nap = own.filter { $0.type == LogType.diaper }
                    let wet = nap.filter { $0.detail == "wet" || $0.detail == "both" }.count, dirty = nap.filter { $0.detail == "dirty" || $0.detail == "both" }.count
                    let temp = own.filter { $0.type == LogType.temp }.compactMap(\.amount).max().map { String(format: "%.1f °C", Double($0) / 10) } ?? ""
                    let solid = own.filter { $0.type == LogType.solid }.compactMap(\.detail).filter { !$0.isEmpty }.joined(separator: "；")
                    let med = own.filter { $0.type == LogType.medicine }.compactMap(\.detail).filter { !$0.isEmpty }.joined(separator: "；")
                    o += String(format: "| %04d-%02d-%02d ", d.y, d.m, d.d)
                    let cells: [String] = ["\(feeds)", nursed > 0 ? minutesOf(nursed) : "", ml > 0 ? "\(ml) 毫升" : "", sleep > 0 ? minutesOf(sleep) : "",
                                           nap.isEmpty ? "" : "\(nap.count)（\(wet) / \(dirty)）", temp, solid, med]
                    o += "| " + cells.joined(separator: " | ") + " |\n"
                }
                d = d.plus(days: 1)
            }
        }

        // month records
        let ticks = app.ticks.values.sorted { $0.month != $1.month ? $0.month < $1.month : $0.at < $1.at }
        let kinds: [(String, String)] = [(TickKind.observed, "留意到的表现"), (TickKind.vaccine, "已完成的接种"), (TickKind.checkup, "已完成的儿保"), (TickKind.did, "一起玩过的活动")]
        if !ticks.isEmpty {
            o += "\n## 每个月记下的事\n"
            for m in Set(ticks.map(\.month)).sorted() {
                o += "\n### \(m == 0 ? "出生" : "满 \(m) 个月")\n\n"
                for (k, name) in kinds {
                    let items = ticks.filter { $0.month == m && $0.kind == k }
                    if !items.isEmpty { o += "- \(name)：" + items.map { $0.label.isEmpty ? $0.key : $0.label }.joined(separator: "；") + "\n" }
                }
            }
        }

        // every entry
        if !logs.isEmpty {
            o += "\n## 全部记录（按时间）\n\n| 日期 | 开始 | 结束 | 类型 | 内容 |\n|---|---|---|---|---|\n"
            for e in logs {
                var what = e.summary
                if e.type == LogType.play { what = e.detail ?? "" }
                if e.type == LogType.nurse {
                    let side: String? = e.side == "l" ? "左侧" : e.side == "r" ? "右侧" : nil
                    let length: String? = e.end == nil ? nil : minutesOf(e.activeSeconds)
                    what = [side, length].compactMap { $0 }.joined(separator: " · ")
                }
                let row: [String] = [date(e.start), time(e.start), e.end.map(time) ?? "", LogType.name(e.type), what.replacingOccurrences(of: "|", with: "／")]
                o += "| " + row.joined(separator: " | ") + " |\n"
            }
        }
        if !j.timers.isEmpty {
            o += "\n正在计时：" + j.timers.map { LogType.name($0.type) + "，" + date($0.start) + " " + time($0.start) + " 开始" }.joined(separator: "；") + "\n"
        }
        o += "\n—— 来自 摸索台灯 Mossling。应用内容仅供家庭养育参考，不能替代医生的诊断和建议。\n"
        return Data(o.utf8)
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
