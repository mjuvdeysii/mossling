import SwiftUI

// MARK: - Pixar Studio 3D Lighting & Material Rig

/// Applies Pixar-inspired three-point warm key-light wrap, cool opposite bounce fill, volumetric bead light,
/// and tactile soft-vinyl micro-tooth over any full StoryTheater stage.
struct PixarStageGrade: ViewModifier {
    let stageSize: CGSize
    let keyPos: CGPoint
    let beadPos: CGPoint
    let targetPos: CGPoint
    let time: Double
    let dark: Bool
    var keyIntensity: Double = 1.0
    var volumetricIntensity: Double = 1.0
    var enabled: Bool = true

    func body(content: Self.Content) -> some View {
        let active = enabled && stageSize.width >= 80 && stageSize.height >= 60
        return content
            .colorEffect(
                ShaderLibrary.pixarKeyLightWrap(
                    .float2(stageSize),
                    .float2(keyPos),
                    .float(Float(keyIntensity)),
                    .float(Float(dark ? 0.95 : 0.72)),
                    .float(Float(dark ? 1.0 : 0.0))
                ),
                isEnabled: active
            )
            .colorEffect(
                ShaderLibrary.pixarVolumetricBloom(
                    .float2(stageSize),
                    .float2(beadPos),
                    .float2(targetPos),
                    .float(Float(time)),
                    .float(Float(volumetricIntensity)),
                    .float(Float(dark ? 1.0 : 0.0))
                ),
                isEnabled: active
            )
    }
}

/// Canonical 3D matte soft-vinyl Moss / Otto actor rendered with Pixar directional rim shading,
/// double-layer Contact AO under feet, volume-preserving squash & stretch, and volumetric golden bead glow.
struct PixarActorRenderer: View {
    let kind: Kind
    let size: CGFloat
    let mood: Mood
    let look: CGPoint
    var lid: Double? = nil
    var lean: Double = 0
    var hopLift: CGFloat = 0
    var hopping: Bool = false
    var breathTime: Double = 0
    var isStatic: Bool = true
    var dark: Bool = false
    var lightDirection: CGPoint = CGPoint(x: 0.75, y: -0.65)
    var compact: Bool = false
    var postureScale: CGSize = CGSize(width: 1, height: 1)

    var body: some View {
        let period = kind == .moss ? 2.6 : 3.8
        let breath = isStatic ? 0 : (1.0 - cos(breathTime / period * 2.0 * .pi)) * 0.5
        let amp = kind == .moss ? 0.017 : 0.010
        let sx = (1.0 - breath * amp * 0.5) * Double(postureScale.width)
        let sy = (1.0 + breath * amp) * Double(postureScale.height)
        let feetFrac: CGFloat = (kind == .moss ? Sprites.mossFeet : Sprites.ottoFeet) / 100.0
        let st = Creature.state(
            kind,
            face: mood,
            look: look,
            lid: lid ?? 0,
            hopping: hopping,
            yawning: false
        )
        let img = StoryTheaterSpritePool.image(kind: kind, state: st)
        let liftShrink = max(0.55, 1.0 - hopLift * 0.38)
        let rx = (kind == .moss ? 0.30 : 0.22) * size * liftShrink
        let bPt = Sprites.bead[st] ?? Sprites.bead["idle"] ?? CGPoint(x: 0.247, y: 0.4317)
        let glowR = size * (dark ? 0.18 : 0.10)
        let rimTint: Color = dark
            ? Palette.amber.opacity(0.95)
            : Color(hex: kind == .moss ? 0xFFF2C8 : 0xFFE9BA)

        ZStack {
            // Double-layer Contact AO: outer soft ambient ground bounce + tight crisp core under soles
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Palette.ink.opacity((dark ? 0.46 : 0.22) * Double(liftShrink)),
                            Palette.ink.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: rx * 1.18
                    )
                )
                .frame(width: rx * 2.36, height: rx * 0.46)
                .position(x: size * 0.5, y: size * feetFrac + 1.5)

            Ellipse()
                .fill(Palette.ink.opacity((dark ? 0.34 : 0.16) * Double(liftShrink)))
                .frame(width: rx * 1.32, height: rx * 0.22)
                .position(x: size * 0.5, y: size * feetFrac + 0.5)

            ZStack {
                if let img {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .layerEffect(
                            ShaderLibrary.pixarActorRimShade(
                                .float2(lightDirection),
                                .color(rimTint),
                                .float(Float(dark ? 1.05 : 0.78))
                            ),
                            maxSampleOffset: CGSize(width: 4, height: 4),
                            isEnabled: !compact && size >= 36
                        )
                }

                if kind == .otto {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Palette.amber.opacity(dark ? 0.78 : 0.28),
                                    Palette.amber.opacity(0)
                                ],
                                center: .center,
                                startRadius: 1,
                                endRadius: glowR
                            )
                        )
                        .frame(width: glowR * 2, height: glowR * 2)
                        .blendMode(.plusLighter)
                        .position(x: size * bPt.x, y: size * bPt.y)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(x: sx, y: sy, anchor: UnitPoint(x: 0.5, y: feetFrac))
            .rotationEffect(.degrees(lean), anchor: UnitPoint(x: 0.5, y: feetFrac))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pixar Sculpted Prop Canvas Helpers

enum PixarDrawHelpers {
    /// Fills a tactile wooden prop surface with sunlit beech/birch directional volume, specular-free matte rolloff,
    /// subtle chamfer highlight, and curved organic wood grain.
    static func drawBeechwood(
        in ctx: inout GraphicsContext,
        path: Path,
        bounds: CGRect,
        dark: Bool,
        warmth: Double = 0.5,
        grainLines: Int = 3
    ) {
        let topCol = dark ? Color(hex: 0xBA8852) : Color(hex: 0xEFC88F).mix(with: .white, by: 0.14 * warmth)
        let midCol = dark ? Color(hex: 0x9B6E3E) : Color(hex: 0xDFB174)
        let botCol = dark ? Color(hex: 0x6E4B27) : Color(hex: 0xBE884B)

        ctx.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [topCol, midCol, botCol]),
                startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.maxX * 0.2 + bounds.minX * 0.8, y: bounds.maxY)
            )
        )

        var clipped = ctx
        clipped.clip(to: path)
        let grainColor = dark ? Color(hex: 0x452A13).opacity(0.38) : Color(hex: 0x8C5D2E).opacity(0.20)
        for i in 0..<max(0, grainLines) {
            let fy = CGFloat(i + 1) / CGFloat(grainLines + 1)
            let y = bounds.minY + bounds.height * fy
            var g = Path()
            g.move(to: CGPoint(x: bounds.minX - 2, y: y))
            g.addQuadCurve(
                to: CGPoint(x: bounds.maxX + 2, y: y + (i % 2 == 0 ? 1.8 : -1.5)),
                control: CGPoint(x: bounds.midX, y: y + (i % 2 == 0 ? -3.0 : 3.0))
            )
            clipped.stroke(g, with: .color(grainColor), lineWidth: 1.0)
        }

        // Top chamfer highlight rim
        ctx.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [Color.white.opacity(dark ? 0.16 : 0.58), Color.clear]),
                startPoint: CGPoint(x: bounds.midX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
            ),
            lineWidth: 1.1
        )
    }

    /// Soft double-layer Contact AO shadow ellipse under grounded props.
    static func drawContactAO(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        dark: Bool,
        opacity: Double = 1.0
    ) {
        let outerRect = CGRect(x: center.x - rx * 1.25, y: center.y - ry * 1.15, width: rx * 2.5, height: ry * 2.3)
        ctx.fill(
            Path(ellipseIn: outerRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.black.opacity((dark ? 0.36 : 0.16) * opacity),
                    Color.black.opacity(0)
                ]),
                center: center,
                startRadius: 0,
                endRadius: rx * 1.25
            )
        )
        let coreRect = CGRect(x: center.x - rx * 0.72, y: center.y - ry * 0.52, width: rx * 1.44, height: ry * 1.04)
        ctx.fill(
            Path(ellipseIn: coreRect),
            with: .color(Color.black.opacity((dark ? 0.28 : 0.12) * opacity))
        )
    }

    /// Out-of-focus foreground dust bokeh spheres giving cinema camera depth.
    static func drawForegroundBokeh(
        in ctx: inout GraphicsContext,
        points: [(CGPoint, CGFloat, Color)],
        dark: Bool
    ) {
        for (center, r, tint) in points {
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        tint.opacity(dark ? 0.18 : 0.22),
                        tint.opacity(dark ? 0.06 : 0.08),
                        tint.opacity(0)
                    ]),
                    center: center,
                    startRadius: 0,
                    endRadius: r
                )
            )
        }
    }
}
