#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

namespace {

inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

inline float fbm3(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        v += amp * valueNoise(p);
        p = p * 2.07 + float2(13.1, 7.7);
        amp *= 0.5;
    }
    return v;
}

} // namespace

// MARK: - Pixar Studio Soft-Vinyl & Three-Point Lighting Shaders

/// Three-point Pixar-inspired warm key-light wrap, cool opposite bounce fill, soft-vinyl matte micro-grain,
/// and gentle cinema vignette framing across a stage plate.
[[stitchable]] half4 pixarKeyLightWrap(
    float2 position,
    half4 color,
    float2 size,
    float2 keyPos,
    float keyIntensity,
    float rimStrength,
    float darkMode
) {
    if (color.a <= 0.001h) {
        return color;
    }
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    float2 keyUV = keyPos / safeSize;

    half3 rgb = color.rgb / color.a;

    // 1. Directional key-light falloff (warm golden key) & cool bounce shadow fill
    float distKey = length(uv - keyUV);
    float keyFalloff = exp(-distKey * distKey * (darkMode > 0.5 ? 2.4 : 1.7));
    half3 warmKey = darkMode > 0.5 ? half3(1.0h, 0.78h, 0.44h) : half3(1.0h, 0.96h, 0.85h);
    rgb = mix(rgb, rgb + warmKey * half(0.14 * keyIntensity), half(keyFalloff * 0.65));

    float2 shadowCorner = float2(1.0 - clamp(keyUV.x, 0.0, 1.0), 1.0);
    float shadowDist = length(uv - shadowCorner);
    float coolFill = exp(-shadowDist * shadowDist * 2.2) * 0.06;
    half3 bounceTint = darkMode > 0.5 ? half3(0.16h, 0.25h, 0.48h) : half3(0.84h, 0.91h, 0.98h);
    rgb = mix(rgb, bounceTint, half(coolFill * rimStrength));

    // 2. Matte soft-vinyl micro-tooth (organic silicone surface tactility, zero glossy plastic sheen)
    float grain = (hash21(floor(position * 0.85)) - 0.5) * (darkMode > 0.5 ? 0.018 : 0.014);
    rgb += half3(grain);

    // 3. Soft theatrical depth vignette
    float2 centered = uv - float2(0.5, 0.48);
    float vignette = 1.0 - smoothstep(0.32, 0.82, length(centered)) * (darkMode > 0.5 ? 0.22 : 0.07);
    rgb *= half(vignette);

    return half4(clamp(rgb, 0.0h, 1.0h) * color.a, color.a);
}

/// Directional alpha-gradient rim lighting & subsurface wrap on canonical 3D Moss & Otto sprites.
[[stitchable]] half4 pixarActorRimShade(
    float2 position,
    SwiftUI::Layer layer,
    float2 lightDir,
    half4 rimColor,
    float intensity
) {
    half4 center = layer.sample(position);
    if (center.a <= 0.002h) {
        return center;
    }

    float lenDir = length(lightDir);
    float2 dir = lenDir > 0.001 ? (lightDir / lenDir) : float2(0.7, -0.7);
    float stepPx = 2.4;

    half aTowards = layer.sample(position + dir * stepPx).a;
    half aAway = layer.sample(position - dir * stepPx).a;
    half aOrtho1 = layer.sample(position + float2(-dir.y, dir.x) * stepPx).a;
    half aOrtho2 = layer.sample(position + float2(dir.y, -dir.x) * stepPx).a;

    // Lit edge where moving toward the key light steps out of the sprite alpha
    float edgeLit = clamp(float(center.a - aTowards) * 1.45, 0.0, 1.0);
    // Subtle opposite edge occlusion
    float edgeShadow = clamp(float(center.a - aAway) * 0.9, 0.0, 1.0);
    // Inner crown wrap
    float softWrap = clamp(float((1.0h - aOrtho1) + (1.0h - aOrtho2)) * 0.22, 0.0, 0.45);

    half3 rgb = center.rgb / center.a;
    half3 rimTone = rimColor.rgb;
    rgb = mix(rgb, rimTone, half(edgeLit * 0.48 * intensity));
    rgb += rimTone * half(softWrap * 0.07 * intensity);
    rgb *= half(1.0 - edgeShadow * 0.10 * intensity);

    return half4(clamp(rgb, 0.0h, 1.0h) * center.a, center.a);
}

/// Volumetric conical light beam & shimmering golden dust motes emitted from Otto's lamp bead.
[[stitchable]] half4 pixarVolumetricBloom(
    float2 position,
    half4 color,
    float2 size,
    float2 beadPos,
    float2 targetPos,
    float time,
    float intensity,
    float darkMode
) {
    if (color.a <= 0.001h || intensity <= 0.001) {
        return color;
    }

    float2 axis = targetPos - beadPos;
    float axisLen = max(length(axis), 12.0);
    float2 dir = axis / axisLen;
    float2 rel = position - beadPos;
    float along = dot(rel, dir);
    float perp = abs(rel.x * (-dir.y) + rel.y * dir.x);

    float alongNorm = clamp(along / axisLen, 0.0, 1.35);
    float coneRadius = mix(8.0, max(size.x, size.y) * 0.31, clamp(alongNorm, 0.0, 1.0));
    float inCone = smoothstep(coneRadius, coneRadius * 0.16, perp)
        * smoothstep(-6.0, 14.0, along)
        * (1.0 - smoothstep(axisLen * 0.85, axisLen * 1.32, along));

    // Gentle volumetric shimmer along air column
    float dust = valueNoise(position * 0.055 + float2(time * 0.18, -time * 0.26));
    float beam = inCone * (0.65 + 0.35 * dust) * intensity * (darkMode > 0.5 ? 0.28 : 0.10);

    half3 rgb = color.rgb / color.a;
    half3 goldBloom = darkMode > 0.5 ? half3(1.0h, 0.78h, 0.36h) : half3(1.0h, 0.90h, 0.62h);
    rgb += goldBloom * half(beam);

    return half4(clamp(rgb, 0.0h, 1.0h) * color.a, color.a);
}

// MARK: - Studio Ghibli Watercolor, Cold-Press Cotton Paper & Komorebi Shaders

/// Cold-press cotton paper tooth + pigment granulation + wet-edge watercolor pooling ("edge darkening")
/// + gently swaying Komorebi dappled leaf sunlight.
[[stitchable]] half4 ghibliWatercolorWash(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float komorebiStrength,
    float darkMode
) {
    half4 center = layer.sample(position);
    if (center.a <= 0.001h) {
        return center;
    }

    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;

    // 1. Cold-press cotton paper tooth (multi-scale fibers + subtle valley pigment pooling)
    float coarseTooth = fbm3(position * 0.045);
    float fineFiber = valueNoise(float2(position.x * 0.36, position.y * 0.18)) * 0.55
        + valueNoise(float2(position.x * 0.16, position.y * 0.42)) * 0.45;
    float paperGrain = (coarseTooth * 0.65 + fineFiber * 0.35) - 0.5;

    // 2. Watercolor edge darkening (detect pigment transitions across neighbors and pool pigment along wet edge)
    float d = 1.6;
    half3 cN = layer.sample(position + float2(0.0, -d)).rgb;
    half3 cS = layer.sample(position + float2(0.0, d)).rgb;
    half3 cE = layer.sample(position + float2(d, 0.0)).rgb;
    half3 cW = layer.sample(position + float2(-d, 0.0)).rgb;
    half3 centerRgb = center.rgb / center.a;
    float grad = length(float3(cN - cS)) + length(float3(cE - cW));
    float wetEdge = smoothstep(0.04, 0.24, grad) * 0.14;

    // Pigment pooling darkens valleys slightly & leaves warm paper highlights on raised tooth
    half3 rgb = centerRgb;
    float lum = dot(float3(rgb), float3(0.299, 0.587, 0.114));
    float granulation = paperGrain * (darkMode > 0.5 ? 0.055 : 0.068) * (0.45 + 0.55 * (1.0 - lum));
    rgb -= half3(granulation);
    rgb *= half(1.0 - wetEdge);

    // 3. Komorebi (木漏日) dappled foliage sunlight or soft painted lantern glow
    if (komorebiStrength > 0.01) {
        float2 leafCoord = uv * float2(3.6, 2.8) + float2(sin(time * 0.28) * 0.16, cos(time * 0.22) * 0.10);
        float dapple = smoothstep(0.46, 0.78, fbm3(leafCoord));
        if (darkMode > 0.5) {
            half3 nightWash = half3(0.96h, 0.72h, 0.38h);
            rgb += nightWash * half(dapple * 0.07 * komorebiStrength);
        } else {
            half3 sunDapple = half3(1.0h, 0.95h, 0.78h);
            rgb = mix(rgb, rgb + sunDapple * 0.12h, half(dapple * 0.65 * komorebiStrength));
        }
    }

    // 4. Subtle cotton paper warm tint lift so whites feel like warm cream rag paper (#FBF6EA)
    if (darkMode < 0.5) {
        rgb = mix(rgb, rgb * half3(1.0h, 0.992h, 0.965h), 0.55h);
    }

    return half4(clamp(rgb, 0.0h, 1.0h) * center.a, center.a);
}

/// Subtle static hand-ink contour wobble breaking pure CAD linearity on 2D watercolor layers.
[[stitchable]] float2 ghibliHandInkWarp(
    float2 position,
    float seed,
    float amplitude
) {
    float wx = sin(position.y * 0.085 + seed * 3.1) * 0.65 + cos(position.x * 0.045 + seed * 1.7) * 0.35;
    float wy = cos(position.x * 0.080 + seed * 2.3) * 0.65 + sin(position.y * 0.040 + seed * 4.1) * 0.35;
    return position + float2(wx, wy) * clamp(amplitude, 0.0, 1.6);
}

/// Harmonizes 2D watercolor shadows away from cold digital black into Miyazaki/Takahata warm sage/indigo tones.
[[stitchable]] half4 ghibliPaperHighlightLift(
    float2 position,
    half4 color,
    float2 size,
    float darkMode
) {
    if (color.a <= 0.001h) {
        return color;
    }
    float2 safeSize = max(size, float2(1.0));
    float2 uv = position / safeSize;
    half3 rgb = color.rgb / color.a;

    if (darkMode > 0.5) {
        half3 twilightFloor = half3(0.08h, 0.11h, 0.22h);
        rgb = max(rgb, twilightFloor * 0.85h);
    } else {
        // Gentle warm atmospheric horizon bounce
        float horizon = smoothstep(0.15, 0.95, uv.y);
        rgb = mix(rgb, rgb + half3(0.025h, 0.020h, 0.006h), half(1.0 - horizon * 0.5));
    }

    return half4(clamp(rgb, 0.0h, 1.0h) * color.a, color.a);
}
