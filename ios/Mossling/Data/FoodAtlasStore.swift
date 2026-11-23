import Foundation
import SwiftUI
import Observation

/// Six botanical categories in Moss's 「百味食盒 / First Foods Tasting Box」.
enum FoodCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case veggie, fruit, grain, protein, dairySeed, gentle
    var id: String { rawValue }

    var title: String {
        switch self {
        case .veggie: L10n.t("蔬菜", "Veggies")
        case .fruit: L10n.t("水果", "Fruits")
        case .grain: L10n.t("五谷", "Grains")
        case .protein: L10n.t("蛋鱼肉豆", "Proteins")
        case .dairySeed: L10n.t("奶与坚果", "Dairy & Seeds")
        case .gentle: L10n.t("温和食材", "Gentle")
        }
    }

    var color: Color {
        switch self {
        case .veggie: Crayon.leaf
        case .fruit: Crayon.pink
        case .grain: Crayon.sunflower
        case .protein: Crayon.tangerine
        case .dairySeed: Crayon.sky
        case .gentle: Crayon.teal
        }
    }

    var symbol: String {
        switch self {
        case .veggie: "leaf.fill"
        case .fruit: "sun.max.fill"
        case .grain: "sparkles"
        case .protein: "fish.fill"
        case .dairySeed: "drop.fill"
        case .gentle: "laurel.leading"
        }
    }
}

/// Warm, zero-judgment tasting reactions recorded by parents.
enum FoodReaction: String, CaseIterable, Codable, Identifiable, Sendable {
    case loved, tasted, tryAgain
    var id: String { rawValue }

    var title: String {
        switch self {
        case .loved: L10n.t("很喜欢", "Loved")
        case .tasted: L10n.t("尝过啦", "Tasted")
        case .tryAgain: L10n.t("下次再试", "Try Again")
        }
    }

    var symbol: String {
        switch self {
        case .loved: "heart.fill"
        case .tasted: "checkmark.circle.fill"
        case .tryAgain: "arrow.trianglehead.2.clockwise"
        }
    }

    var color: Color {
        switch self {
        case .loved: Crayon.pink
        case .tasted: Crayon.teal
        case .tryAgain: Crayon.sunflower
        }
    }
}

/// One curated whole food entry in the 60-food offline tasting catalog.
struct FoodItem: Identifiable, Hashable, Sendable {
    let id: String
    let zh: String
    let en: String
    let category: FoodCategory
    let isCommonAllergen: Bool

    var name: String { L10n.t(zh, en) }
    var assetId: String { "food.\(id)" }

    /// 60 whole foods across 6 Montessori categories (6–36 months everyday family table).
    static let catalog: [FoodItem] = [
        // 1. Vegetables (12)
        FoodItem(id: "pumpkin",      zh: "南瓜",       en: "Pumpkin",          category: .veggie, isCommonAllergen: false),
        FoodItem(id: "sweetpotato",  zh: "红薯",       en: "Sweet Potato",     category: .veggie, isCommonAllergen: false),
        FoodItem(id: "carrot",       zh: "胡萝卜",     en: "Carrot",           category: .veggie, isCommonAllergen: false),
        FoodItem(id: "broccoli",     zh: "西兰花",     en: "Broccoli",         category: .veggie, isCommonAllergen: false),
        FoodItem(id: "avocado",      zh: "牛油果",     en: "Avocado",          category: .veggie, isCommonAllergen: false),
        FoodItem(id: "spinach",      zh: "菠菜",       en: "Spinach",          category: .veggie, isCommonAllergen: false),
        FoodItem(id: "tomato",       zh: "番茄",       en: "Tomato",           category: .veggie, isCommonAllergen: false),
        FoodItem(id: "pea",          zh: "豌豆",       en: "Green Peas",       category: .veggie, isCommonAllergen: false),
        FoodItem(id: "potato",       zh: "土豆",       en: "Potato",           category: .veggie, isCommonAllergen: false),
        FoodItem(id: "corn",         zh: "甜玉米",     en: "Sweet Corn",       category: .veggie, isCommonAllergen: false),
        FoodItem(id: "cucumber",     zh: "黄瓜",       en: "Cucumber",         category: .veggie, isCommonAllergen: false),
        FoodItem(id: "mushroom",     zh: "香菇",       en: "Mushroom",         category: .veggie, isCommonAllergen: false),

        // 2. Fruits (12)
        FoodItem(id: "banana",       zh: "香蕉",       en: "Banana",           category: .fruit, isCommonAllergen: false),
        FoodItem(id: "apple",        zh: "苹果",       en: "Apple",            category: .fruit, isCommonAllergen: false),
        FoodItem(id: "pear",         zh: "雪梨",       en: "Pear",             category: .fruit, isCommonAllergen: false),
        FoodItem(id: "blueberry",    zh: "蓝莓",       en: "Blueberry",        category: .fruit, isCommonAllergen: false),
        FoodItem(id: "strawberry",   zh: "草莓",       en: "Strawberry",       category: .fruit, isCommonAllergen: false),
        FoodItem(id: "mango",        zh: "芒果",       en: "Mango",            category: .fruit, isCommonAllergen: false),
        FoodItem(id: "peach",        zh: "水蜜桃",     en: "Peach",            category: .fruit, isCommonAllergen: false),
        FoodItem(id: "kiwi",         zh: "猕猴桃",     en: "Kiwi",             category: .fruit, isCommonAllergen: false),
        FoodItem(id: "watermelon",   zh: "西瓜",       en: "Watermelon",       category: .fruit, isCommonAllergen: false),
        FoodItem(id: "orange",       zh: "甜橙",       en: "Orange",           category: .fruit, isCommonAllergen: false),
        FoodItem(id: "grape",        zh: "切瓣葡萄",   en: "Quartered Grape",  category: .fruit, isCommonAllergen: false),
        FoodItem(id: "melon",        zh: "哈密瓜",     en: "Melon",            category: .fruit, isCommonAllergen: false),

        // 3. Grains (10)
        FoodItem(id: "ricecereal",   zh: "铁强化米粉", en: "Iron Rice Cereal", category: .grain, isCommonAllergen: false),
        FoodItem(id: "oatmeal",      zh: "燕麦",       en: "Oats",             category: .grain, isCommonAllergen: false),
        FoodItem(id: "millet",       zh: "小米粥",     en: "Millet",           category: .grain, isCommonAllergen: false),
        FoodItem(id: "rice",         zh: "软米饭",     en: "Soft Rice",        category: .grain, isCommonAllergen: false),
        FoodItem(id: "noodles",      zh: "宝宝面条",   en: "Soft Noodles",     category: .grain, isCommonAllergen: true),
        FoodItem(id: "bread",        zh: "全麦吐司",   en: "Whole Toast",      category: .grain, isCommonAllergen: true),
        FoodItem(id: "pasta",        zh: "螺旋意面",   en: "Soft Pasta",       category: .grain, isCommonAllergen: true),
        FoodItem(id: "quinoa",       zh: "藜麦",       en: "Quinoa",           category: .grain, isCommonAllergen: false),
        FoodItem(id: "yam",          zh: "铁棍山药",   en: "Chinese Yam",      category: .grain, isCommonAllergen: false),
        FoodItem(id: "taro",         zh: "芋头",       en: "Taro",             category: .grain, isCommonAllergen: false),

        // 4. Proteins (12)
        FoodItem(id: "eggyolk",      zh: "蛋黄",       en: "Egg Yolk",         category: .protein, isCommonAllergen: true),
        FoodItem(id: "wholeegg",     zh: "全蛋",       en: "Whole Egg",        category: .protein, isCommonAllergen: true),
        FoodItem(id: "salmon",       zh: "三文鱼",     en: "Salmon",           category: .protein, isCommonAllergen: true),
        FoodItem(id: "cod",          zh: "鳕鱼",       en: "Cod Fish",         category: .protein, isCommonAllergen: true),
        FoodItem(id: "beef",         zh: "嫩牛肉",     en: "Tender Beef",      category: .protein, isCommonAllergen: false),
        FoodItem(id: "pork",         zh: "猪里脊",     en: "Pork Loin",        category: .protein, isCommonAllergen: false),
        FoodItem(id: "chicken",      zh: "鸡胸肉",     en: "Chicken",          category: .protein, isCommonAllergen: false),
        FoodItem(id: "shrimp",       zh: "鲜虾仁",     en: "Shrimp",           category: .protein, isCommonAllergen: true),
        FoodItem(id: "tofu",         zh: "嫩豆腐",     en: "Silken Tofu",      category: .protein, isCommonAllergen: true),
        FoodItem(id: "liver",        zh: "猪肝粉",     en: "Iron Liver",       category: .protein, isCommonAllergen: false),
        FoodItem(id: "lentils",      zh: "红扁豆",     en: "Red Lentils",      category: .protein, isCommonAllergen: false),
        FoodItem(id: "chickpea",     zh: "鹰嘴豆",     en: "Chickpeas",        category: .protein, isCommonAllergen: false),

        // 5. Dairy & Seeds (8)
        FoodItem(id: "yogurt",       zh: "无糖酸奶",   en: "Plain Yogurt",     category: .dairySeed, isCommonAllergen: true),
        FoodItem(id: "cheese",       zh: "原味奶酪",   en: "Mild Cheese",      category: .dairySeed, isCommonAllergen: true),
        FoodItem(id: "sesame",       zh: "黑芝麻酱",   en: "Sesame Paste",     category: .dairySeed, isCommonAllergen: true),
        FoodItem(id: "peanut",       zh: "花生酱薄涂", en: "Thin Peanut",      category: .dairySeed, isCommonAllergen: true),
        FoodItem(id: "walnut",       zh: "核桃粉",     en: "Walnut Powder",    category: .dairySeed, isCommonAllergen: true),
        FoodItem(id: "almond",       zh: "杏仁酱薄涂", en: "Thin Almond",      category: .dairySeed, isCommonAllergen: true),
        FoodItem(id: "chia",         zh: "奇亚籽",     en: "Chia Seeds",       category: .dairySeed, isCommonAllergen: false),
        FoodItem(id: "butter",       zh: "无盐黄油",   en: "Unsalted Butter",  category: .dairySeed, isCommonAllergen: true),

        // 6. Gentle Extras (6)
        FoodItem(id: "seaweed",      zh: "无盐海苔",   en: "Mild Seaweed",     category: .gentle, isCommonAllergen: false),
        FoodItem(id: "oliveoil",     zh: "初榨橄榄油", en: "Olive Oil",        category: .gentle, isCommonAllergen: false),
        FoodItem(id: "jujube",       zh: "去核红枣",   en: "Sweet Date",       category: .gentle, isCommonAllergen: false),
        FoodItem(id: "lotus",        zh: "莲子泥",     en: "Lotus Seed",       category: .gentle, isCommonAllergen: false),
        FoodItem(id: "woodear",      zh: "银耳羹",     en: "Snow Fungus",      category: .gentle, isCommonAllergen: false),
        FoodItem(id: "ginger",       zh: "温和葱姜水", en: "Mild Scallion",    category: .gentle, isCommonAllergen: false),
    ]

    static func item(id: String) -> FoodItem? {
        catalog.first { $0.id == id }
    }
}

/// Parent's local tasting record for a single food item.
struct FoodRecord: Identifiable, Codable, Equatable, Sendable {
    var foodId: String
    var firstTastedEpochDay: Int
    var reaction: FoodReaction
    var note: String = ""
    var watchSkin: Bool = false
    var times: Int = 1

    var id: String { foodId }
    var firstTastedDay: Day { Day(epochDay: firstTastedEpochDay) }
}

/// Strictly local JSON storage for 「百味食盒 / First Foods Tasting Box」 under `Application Support/food_atlas.json`.
@Observable
@MainActor
final class FoodAtlasStore {
    static let shared = FoodAtlasStore()

    private(set) var records: [String: FoodRecord] = [:]
    private let fileURL: URL?

    nonisolated static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("food_atlas.json")
    }

    init(fileURL: URL? = FoodAtlasStore.defaultURL) {
        self.fileURL = fileURL
        reload()
    }

    init(preview list: [FoodRecord]) {
        self.fileURL = nil
        self.records = Dictionary(uniqueKeysWithValues: list.map { ($0.foodId, $0) })
    }

    var tastedCount: Int { records.count }
    var lovedCount: Int { records.values.filter { $0.reaction == .loved }.count }

    func record(for foodId: String) -> FoodRecord? {
        records[foodId]
    }

    func tastedCount(in category: FoodCategory) -> Int {
        FoodItem.catalog.filter { $0.category == category && records[$0.id] != nil }.count
    }

    func totalCount(in category: FoodCategory) -> Int {
        FoodItem.catalog.filter { $0.category == category }.count
    }

    func reload() {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([FoodRecord].self, from: data) else {
            return
        }
        records = Dictionary(uniqueKeysWithValues: list.map { ($0.foodId, $0) })
    }

    func save(_ record: FoodRecord) {
        records[record.foodId] = record
        persist()
    }

    func remove(foodId: String) {
        records.removeValue(forKey: foodId)
        persist()
    }

    func clearAll() {
        records = [:]
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func replaceAll(_ list: [FoodRecord]) {
        records = Dictionary(list.map { ($0.foodId, $0) }, uniquingKeysWith: { _, latest in latest })
        persist()
    }

    private func persist() {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let sorted = records.values.sorted { $0.foodId < $1.foodId }
            let data = try JSONEncoder().encode(sorted)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // Silent resilience on transient I/O errors
        }
    }
}
