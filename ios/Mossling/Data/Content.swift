import Foundation

/// The content, as data: content.json (shared with the Android app).
struct Content: Decodable {
    let version: Int
    let months: [Month]
    let activities: [Play]
    let topics: [Topic]
    let health: [Note]
    let domains: [DomainBoard]
    let who: [WhoRow]
    let sources: [Source]

    private var index: [String: Play] = [:]

    enum CodingKeys: String, CodingKey { case version, months, activities, topics, health, domains, who, sources }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        months = try c.decode([Month].self, forKey: .months)
        activities = try c.decode([Play].self, forKey: .activities)
        topics = try c.decodeIfPresent([Topic].self, forKey: .topics) ?? []
        health = try c.decodeIfPresent([Note].self, forKey: .health) ?? []
        domains = try c.decodeIfPresent([DomainBoard].self, forKey: .domains) ?? []
        who = try c.decodeIfPresent([WhoRow].self, forKey: .who) ?? []
        sources = try c.decodeIfPresent([Source].self, forKey: .sources) ?? []
        index = Dictionary(activities.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func play(_ code: String) -> Play? { index[code] }
    func month(_ m: Int) -> Month { months[max(0, min(m, months.count - 1))] }

    /// The month's plays: its feature first, then its own list.
    func plays(of m: Int) -> [Play] {
        let mo = month(m)
        var seen = Set<String>()
        return ([mo.feature].compactMap { $0 } + mo.activities).filter { seen.insert($0).inserted }.compactMap { play($0) }
    }

    static func load(bundle: Bundle = .main) throws -> Content {
        let url = bundle.url(forResource: "content", withExtension: "json")!
        return try JSONDecoder().decode(Content.self, from: Data(contentsOf: url))
    }
}

struct Month: Decodable {
    let month: Int
    let title: String
    let focus: String?
    let feature: String?
    let highlights: [Highlight]
    let official: String
    let who: String
    let basis: String
    let domains: [Area]
    let activities: [String]
    let observe: [ObserveGroup]
    let vaccines: [String]
    let checkups: [String]
    let notes: [Note]
}

struct Highlight: Decodable { let kind: String; let text: String; let anchor: String?; let tag: String? }
struct Area: Decodable { let key: String; let name: String; let text: String }
struct ObserveGroup: Decodable { let area: String; let items: [String] }
struct Note: Decodable { let topic: String; let text: String }

struct Play: Decodable, Identifiable, Hashable {
    let code: String
    let name: String
    let age: String
    let domains: [String]
    let from: Int
    let to: Int
    let prepare: String
    let steps: [String]
    let observe: String
    let pause: String
    let safety: String
    var id: String { code }
}

struct Block: Decodable {
    let type: String
    let text: String?
    let items: [String]?
    let head: [String]?
    let rows: [[String]]?
}

struct Topic: Decodable, Identifiable {
    let id: String
    let title: String
    let sourceTitle: String
    let blocks: [Block]
    enum CodingKeys: String, CodingKey { case id, title, blocks; case sourceTitle = "source_title" }
}

struct BoardRow: Decodable { let age: String; let action: String; let notice: String
    enum CodingKeys: String, CodingKey { case age, notice; case action = "do" } }
struct DomainBoard: Decodable { let title: String; let key: String; let rows: [BoardRow] }
struct WhoRow: Decodable { let age: String; let act: String; let sleep: String; let screen: String; let restrain: String }
struct Source: Decodable, Identifiable { let code: String; let org: String; let title: String; let date: String?; let url: String?; let checked: String?
    var id: String { code } }

/// The pictures: a picture for each step of each play and a cover for each month (art/index.json).
struct ArtIndex: Decodable {
    let plays: [String: [String]]
    let covers: [String: String]
    let size: [String: [Double]]

    static let shared: ArtIndex = {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "art"),
              let data = try? Data(contentsOf: url), let a = try? JSONDecoder().decode(ArtIndex.self, from: data)
        else { return ArtIndex(plays: [:], covers: [:], size: [:]) }
        return a
    }()

    func steps(_ code: String) -> [String] { plays[code] ?? [] }
    func cover(_ m: Int) -> String? { covers[String(m)] }
    func ratio(_ name: String) -> Double { guard let s = size[name], s.count == 2, s[1] > 0 else { return 4.0 / 3 }; return s[0] / s[1] }
}
