import SwiftUI

/// Three seasonal picture-book lands spanning Months 0–36.
enum LivingMonthLand: String, CaseIterable, Sendable {
    case meadow
    case woodland
    case stream

    static func land(for month: Int) -> LivingMonthLand {
        if month < 12 { return .meadow }
        if month < 24 { return .woodland }
        return .stream
    }

    var accentColor: Color {
        switch self {
        case .meadow: Crayon.leaf
        case .woodland: Crayon.tangerine
        case .stream: Crayon.sky
        }
    }
}

/// Eighteen handcrafted Montessori & nature milestone props curated for individual months `0...36`.
enum MonthMilestoneProp: String, CaseIterable, Sendable {
    case leafNest
    case sunMirror
    case woodRing
    case rattle
    case firstFoodBowl
    case peekScarf
    case boardBook
    case blockTower
    case openCup
    case rollingBall
    case beeswaxCrayon
    case pocketDoll
    case ringStacker
    case woodBridge
    case botanicalLeaf
    case paperBoat
    case steppingStones
    case birthdayLantern
}

/// Declarative script for one chapter of `LivingMonthCoverStage`.
struct LivingMonthCoverScript: Equatable, Sendable {
    let month: Int
    let land: LivingMonthLand
    let growthStage: Int
    let prop: MonthMilestoneProp
    let secondaryProp: MonthMilestoneProp?
    let mossMood: Mood
    let mossLid: Double?
    let mossScale: CGFloat
    let mossX: CGFloat
    let ottoX: CGFloat
    let skyWarmth: Double
    let isBirthday: Bool
    let posterPhase: Double
}

/// Complete curated living chapter catalog covering every month `0...36`.
enum LivingMonthCoverCatalog {
    private static func stage(for month: Int) -> Int {
        month < 3 ? 0 : month < 6 ? 1 : month < 9 ? 2 : month < 12 ? 3 : month < 18 ? 4 : month < 24 ? 5 : 6
    }

    private static func make(
        _ month: Int,
        prop: MonthMilestoneProp,
        secondary: MonthMilestoneProp? = nil,
        mood: Mood = .happy,
        lid: Double? = nil,
        mossX: CGFloat = 0.30,
        ottoX: CGFloat = 0.72,
        warmth: Double = 0.55,
        poster: Double = 0.35
    ) -> LivingMonthCoverScript {
        let clamped = max(0, min(36, month))
        let scale = CGFloat(0.78 + 0.30 * (Double(clamped) / 36.0))
        return LivingMonthCoverScript(
            month: clamped,
            land: LivingMonthLand.land(for: clamped),
            growthStage: stage(for: clamped),
            prop: prop,
            secondaryProp: secondary,
            mossMood: mood,
            mossLid: lid,
            mossScale: scale,
            mossX: mossX,
            ottoX: ottoX,
            skyWarmth: warmth,
            isBirthday: clamped == 12 || clamped == 24 || clamped == 36,
            posterPhase: poster
        )
    }

    static let allScripts: [LivingMonthCoverScript] = [
        // Meadow (0–11m)
        make(0,  prop: .leafNest,       secondary: .birthdayLantern, mood: .happy, lid: 0.68, mossX: 0.31, ottoX: 0.70, warmth: 0.72, poster: 0.25),
        make(1,  prop: .woodRing,       secondary: .leafNest,        mood: .open,  lid: nil,  mossX: 0.30, ottoX: 0.71, warmth: 0.62, poster: 0.32),
        make(2,  prop: .rattle,         secondary: .botanicalLeaf,   mood: .wow,   lid: nil,  mossX: 0.30, ottoX: 0.72, warmth: 0.58, poster: 0.38),
        make(3,  prop: .sunMirror,      secondary: .woodRing,        mood: .wow,   lid: nil,  mossX: 0.29, ottoX: 0.72, warmth: 0.52, poster: 0.34),
        make(4,  prop: .rattle,         secondary: .boardBook,       mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.56, poster: 0.42),
        make(5,  prop: .peekScarf,      secondary: .rattle,          mood: .wow,   lid: nil,  mossX: 0.28, ottoX: 0.72, warmth: 0.64, poster: 0.44),
        make(6,  prop: .firstFoodBowl,  secondary: .sunMirror,       mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.60, poster: 0.36),
        make(7,  prop: .woodRing,       secondary: .rollingBall,     mood: .wow,   lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.54, poster: 0.40),
        make(8,  prop: .peekScarf,      secondary: .openCup,         mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.58, poster: 0.42),
        make(9,  prop: .rollingBall,    secondary: .peekScarf,       mood: .wow,   lid: nil,  mossX: 0.27, ottoX: 0.75, warmth: 0.50, poster: 0.36),
        make(10, prop: .botanicalLeaf,  secondary: .openCup,         mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.62, poster: 0.38),
        make(11, prop: .openCup,        secondary: .boardBook,       mood: .wow,   lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.65, poster: 0.34),

        // Woodland (12–23m)
        make(12, prop: .birthdayLantern, secondary: .openCup,        mood: .happy, lid: nil,  mossX: 0.30, ottoX: 0.72, warmth: 0.78, poster: 0.40),
        make(13, prop: .rollingBall,     secondary: .woodRing,       mood: .happy, lid: nil,  mossX: 0.27, ottoX: 0.74, warmth: 0.55, poster: 0.38),
        make(14, prop: .blockTower,      secondary: .boardBook,      mood: .wow,   lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.52, poster: 0.36),
        make(15, prop: .pocketDoll,      secondary: .openCup,        mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.58, poster: 0.32),
        make(16, prop: .rollingBall,     secondary: .beeswaxCrayon,  mood: .wow,   lid: nil,  mossX: 0.27, ottoX: 0.75, warmth: 0.50, poster: 0.42),
        make(17, prop: .boardBook,       secondary: .blockTower,     mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.62, poster: 0.35),
        make(18, prop: .beeswaxCrayon,   secondary: .openCup,        mood: .happy, lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.64, poster: 0.40),
        make(19, prop: .pocketDoll,      secondary: .botanicalLeaf,  mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.56, poster: 0.36),
        make(20, prop: .rollingBall,     secondary: .boardBook,      mood: .wow,   lid: nil,  mossX: 0.27, ottoX: 0.75, warmth: 0.48, poster: 0.38),
        make(21, prop: .ringStacker,     secondary: .pocketDoll,     mood: .open,  lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.54, poster: 0.34),
        make(22, prop: .boardBook,       secondary: .rollingBall,    mood: .wow,   lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.60, poster: 0.42),
        make(23, prop: .steppingStones,  secondary: .pocketDoll,     mood: .happy, lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.66, poster: 0.38),

        // Stream (24–36m)
        make(24, prop: .birthdayLantern, secondary: .pocketDoll,     mood: .happy, lid: nil,  mossX: 0.30, ottoX: 0.72, warmth: 0.78, poster: 0.40),
        make(25, prop: .openCup,         secondary: .botanicalLeaf,  mood: .wow,   lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.54, poster: 0.36),
        make(26, prop: .ringStacker,     secondary: .openCup,        mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.58, poster: 0.34),
        make(27, prop: .woodBridge,      secondary: .steppingStones, mood: .happy, lid: nil,  mossX: 0.27, ottoX: 0.75, warmth: 0.52, poster: 0.40),
        make(28, prop: .rollingBall,     secondary: .boardBook,      mood: .wow,   lid: nil,  mossX: 0.27, ottoX: 0.75, warmth: 0.50, poster: 0.38),
        make(29, prop: .steppingStones,  secondary: .ringStacker,    mood: .happy, lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.56, poster: 0.42),
        make(30, prop: .beeswaxCrayon,   secondary: .boardBook,      mood: .wow,   lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.62, poster: 0.40),
        make(31, prop: .botanicalLeaf,   secondary: .paperBoat,      mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.58, poster: 0.36),
        make(32, prop: .woodBridge,      secondary: .blockTower,     mood: .happy, lid: nil,  mossX: 0.27, ottoX: 0.75, warmth: 0.54, poster: 0.38),
        make(33, prop: .paperBoat,       secondary: .ringStacker,    mood: .wow,   lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.52, poster: 0.44),
        make(34, prop: .blockTower,      secondary: .woodBridge,     mood: .happy, lid: nil,  mossX: 0.28, ottoX: 0.74, warmth: 0.60, poster: 0.36),
        make(35, prop: .boardBook,       secondary: .paperBoat,      mood: .happy, lid: nil,  mossX: 0.29, ottoX: 0.73, warmth: 0.64, poster: 0.40),
        make(36, prop: .birthdayLantern, secondary: .paperBoat,      mood: .happy, lid: nil,  mossX: 0.30, ottoX: 0.72, warmth: 0.82, poster: 0.42),
    ]

    static func script(for month: Int) -> LivingMonthCoverScript {
        let clamped = max(0, min(allScripts.count - 1, month))
        return allScripts[clamped]
    }
}
