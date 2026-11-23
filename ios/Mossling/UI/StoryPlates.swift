import SwiftUI
import UIKit

/// Handcrafted miniature stop-motion diorama & storybook plates bundled inside `Resources/Illustrations/`.
enum StoryPlate: String, CaseIterable, Sendable {
    case handoverLantern = "plate_handover_lantern"
    case stageSound = "plate_stage_sound"
    case stageMirror = "plate_stage_mirror"
    case stageHold = "plate_stage_hold"
    case stageTummy = "plate_stage_tummy"
    case stageGrasp = "plate_stage_grasp"
    case stageContainer = "plate_stage_container"
    case stageBlocks = "plate_stage_blocks"
    case stageBook = "plate_stage_book"
    case landMeadow = "plate_land_meadow"
    case landForest = "plate_land_forest"
    case landRiver = "plate_land_river"
    case storybookCover = "plate_storybook_cover"
    case capsuleDesk = "plate_capsule_desk"

    static let corePlates: [StoryPlate] = [
        .handoverLantern,
        .stageSound,
        .stageMirror,
        .stageHold,
        .stageTummy,
        .stageGrasp,
        .stageContainer,
        .stageBlocks,
        .stageBook
    ]

    var fallbackPlate: StoryPlate? {
        switch self {
        case .landMeadow: .stageTummy
        case .landForest: .stageBlocks
        case .landRiver: .stageBook
        case .storybookCover: .stageBook
        case .capsuleDesk: .stageHold
        default: nil
        }
    }

    static func forTemplate(_ template: ActivityMotionTemplate) -> StoryPlate {
        switch template {
        case .soundWave: .stageSound
        case .faceMirror: .stageMirror
        case .gentleHold: .stageHold
        case .tummyExplore: .stageTummy
        case .graspPass: .stageGrasp
        case .tapContainer: .stageContainer
        case .stackBuild: .stageBlocks
        case .bookMatch: .stageBook
        }
    }

    static func forLand(_ land: Land) -> StoryPlate {
        switch land {
        case .meadow: .landMeadow
        case .forest: .landForest
        case .river: .landRiver
        }
    }
}

/// Synchronous in-memory image loader for storyboard plates so both live views and 3× `ImageRenderer` exports draw on frame 1.
enum StoryPlateLoader {
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 24
        return c
    }()

    static func image(for plate: StoryPlate) -> UIImage? {
        if let direct = image(named: plate.rawValue) {
            return direct
        }
        if let fb = plate.fallbackPlate {
            return image(named: fb.rawValue)
        }
        return nil
    }

    static func image(named rawName: String) -> UIImage? {
        let key = rawName as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let bundles = [Bundle.main] + Bundle.allBundles
        let extensions = ["jpg", "jpeg", "webp", "png"]
        for bundle in bundles {
            for ext in extensions {
                if let url = bundle.url(forResource: rawName, withExtension: ext, subdirectory: "Illustrations"),
                   let img = UIImage(contentsOfFile: url.path) {
                    cache.setObject(img, forKey: key)
                    return img
                }
                if let url = bundle.url(forResource: rawName, withExtension: ext),
                   let img = UIImage(contentsOfFile: url.path) {
                    cache.setObject(img, forKey: key)
                    return img
                }
            }
        }
        return nil
    }
}

/// Renders a genuine miniature picture-book plate with gentle optical warmth, optional slow dust motes & interactive golden tap ripple.
struct LivingStoryPlateView: View {
    let plate: StoryPlate
    var dark: Bool = false
    var alive: Bool = true
    var pulseAt: Date = .distantPast
    var accessibilityLabel: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let img = StoryPlateLoader.image(for: plate)
        GeometryReader { geo in
            ZStack {
                if let img {
                    if alive && !reduce && !Perf.still {
                        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { tl in
                            let t = tl.date.timeIntervalSinceReferenceDate
                            let breathe = 1.0 + 0.016 * (0.5 + 0.5 * sin(t * 0.78))
                            let panX = CGFloat(sin(t * 0.42) * 3.0)
                            let pulseAge = max(0, tl.date.timeIntervalSince(pulseAt))
                            let pulseStrength = pulseAt == .distantPast ? 0.0 : max(0.0, 1.0 - pulseAge / 1.0)

                            ZStack {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .scaleEffect(breathe)
                                    .offset(x: panX)

                                if dark {
                                    Color(hex: 0x0B1126).opacity(0.24)
                                }

                                // Soft sunlit / lamplight motes + interactive tap ripple (zero state mutation)
                                Canvas { ctx, size in
                                    let cx = size.width * 0.5
                                    let cy = size.height * 0.48
                                    for i in 0..<7 {
                                        let seed = Double(i) * 1.93
                                        let cycle = (t * 0.14 + seed * 0.37).truncatingRemainder(dividingBy: 1.0)
                                        let mx = size.width * (0.18 + 0.64 * ((sin(seed * 3.1 + t * 0.25) + 1) * 0.5))
                                        let my = size.height * (0.85 - cycle * 0.72)
                                        let r: CGFloat = 1.5 + CGFloat(i % 3) * 0.7
                                        let alpha = sin(cycle * .pi) * (dark ? 0.55 : 0.45)
                                        var mote = Path()
                                        mote.addEllipse(in: CGRect(x: mx - r, y: my - r, width: r * 2, height: r * 2))
                                        ctx.fill(mote, with: .color(Palette.beadLight.opacity(alpha)))
                                    }
                                    if pulseStrength > 0.01 {
                                        let rad = CGFloat((1.0 - pulseStrength) * Double(min(size.width, size.height) * 0.44) + 16)
                                        var ring = Path()
                                        ring.addEllipse(in: CGRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2))
                                        ctx.stroke(ring, with: .color(Palette.bead.opacity(pulseStrength * 0.75)), lineWidth: 2.8)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                        }
                    } else {
                        ZStack {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                            if dark {
                                Color(hex: 0x0B1126).opacity(0.24)
                            }
                        }
                    }
                } else {
                    LinearGradient(
                        colors: dark ? [Color(hex: 0x161E3C), Color(hex: 0x0E1430)] : [Palette.paper, Crayon.sunflower.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .accessibilityLabel(accessibilityLabel)
    }
}
