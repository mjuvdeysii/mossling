package app.mossling.ui.ip

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import app.mossling.ui.components.ArtIndex
import app.mossling.ui.components.ArtStyle
import app.mossling.ui.components.LocalArtStyle
import app.mossling.ui.components.reducedMotion
import app.mossling.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.random.Random

/**
 * The two silent companions of Mossling (`docs/IP.md`):
 * - **Moss (小苔)**: quick, curious moss-covered pebble with a tiny two-leaf sprout.
 * - **Otto (奥托)**: unhurried blue Montessori rod creature with a golden ten-bead lamp on top.
 *
 * Neither companion ever speaks, shows text bubbles, or scolds.
 */
enum class Kind {
    Moss,
    Otto;

    val title: String get() = when (this) {
        Moss -> "小苔 Moss"
        Otto -> "奥托 Otto"
    }
    val shortName: String get() = when (this) {
        Moss -> "小苔"
        Otto -> "奥托"
    }
    val trait: String get() = when (this) {
        Moss -> "精力用不完，什么都要先看一眼"
        Otto -> "有点困，但灯一直亮着"
    }
    val style: MascotStyle get() = MascotStyle.of(this)
}

enum class Mood { Calm, Happy, Sleep, Listening, Wow }

@Composable
fun Creature(
    kind: Kind,
    modifier: Modifier = Modifier,
    mood: Mood = Mood.Calm,
    look: Offset? = null,
    lid: Float = 0f,
    lamp: Boolean = true,
    interactive: Boolean = true,
    notice: Int = 0,
    stone: Boolean = false,
) {
    val still = reducedMotion()
    val artStyle = LocalArtStyle.current
    val director = LocalMascotDirector.current
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.2f
    val style = kind.style

    val breathMs = when {
        mood == Mood.Sleep -> 4200
        kind == Kind.Moss -> 2600
        else -> 3800
    }
    val inf = rememberInfiniteTransition(label = "creature")
    val breath by if (still) remember { mutableFloatStateOf(0.5f) } else inf.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(breathMs, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "breath",
    )
    val glow by if (still) remember { mutableFloatStateOf(0.5f) } else inf.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(2200, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "glow",
    )

    var idleTarget by remember { mutableStateOf(Offset.Zero) }
    var idleTilt by remember { mutableFloatStateOf(0f) }
    var idleBlink by remember { mutableFloatStateOf(0f) }
    var yawning by remember { mutableStateOf(false) }
    var stoneFail by remember { mutableStateOf(false) }

    // Ambient living loop (paused when Reduce Motion is on or sleeping)
    LaunchedEffect(kind, mood, look, still) {
        if (still || mood == Mood.Sleep) {
            idleTarget = Offset.Zero
            idleTilt = 0f
            idleBlink = 0f
            return@LaunchedEffect
        }
        val rng = Random(if (kind == Kind.Moss) 17 else 53)
        while (true) {
            delay(
                if (kind == Kind.Moss) rng.nextLong(1500, 3200)
                else rng.nextLong(2600, 5000)
            )
            when (rng.nextInt(10)) {
                in 0..4 -> if (look == null) {
                    val dest = Offset((rng.nextFloat() - 0.5f) * 1.7f, (rng.nextFloat() - 0.45f) * 1.1f)
                    if (style.glanceStages == 2) {
                        idleTarget = Offset(dest.x * 0.55f, dest.y * 0.35f)
                        idleTilt = dest.x * style.tiltDegrees
                        delay(style.glanceMs.toLong())
                    }
                    idleTarget = dest
                    idleTilt = dest.x * (style.tiltDegrees + 1.5f)
                }
                in 5..6 -> if (look == null) {
                    idleTarget = Offset.Zero
                    idleTilt = 0f
                }
                else -> {
                    idleBlink = 1f
                    delay(style.blinkMs.toLong())
                    idleBlink = 0f
                    if (kind == Kind.Moss && rng.nextInt(3) == 0) {
                        delay(85)
                        idleBlink = 1f
                        delay(75)
                        idleBlink = 0f
                    }
                }
            }
        }
    }

    // Notice reaction: Moss double-blinks (`docs/IP.md` §4.2), Otto blinks once slowly
    LaunchedEffect(notice, director.observations) {
        if ((notice <= 0 && director.observations <= 0) || still || mood == Mood.Sleep) return@LaunchedEffect
        idleBlink = 1f
        delay(style.blinkMs.toLong())
        idleBlink = 0f
        if (kind == Kind.Moss) {
            delay(85)
            idleBlink = 1f
            delay(style.blinkMs.toLong())
            idleBlink = 0f
        }
    }

    // Sleep timer start: Otto yawns once before settling
    LaunchedEffect(director.sleepsStarted) {
        if (director.sleepsStarted <= 0 || still || kind != Kind.Otto) return@LaunchedEffect
        yawning = true
        delay(1000)
        yawning = false
    }

    // Persist failure: Moss flattens quietly into a stone
    LaunchedEffect(director.failures) {
        if (director.failures <= 0 || kind != Kind.Moss) return@LaunchedEffect
        stoneFail = true
        delay(1200)
        stoneFail = false
    }

    val isStone = (stone || stoneFail) && kind == Kind.Moss
    val stoneVal by animateFloatAsState(
        targetValue = if (isStone) 1f else 0f,
        animationSpec = spring(dampingRatio = 0.75f, stiffness = 220f),
        label = "stone",
    )

    val hop = remember { Animatable(0f) }
    val sway = remember { Animatable(0f) }
    var tapMood by remember { mutableStateOf<Mood?>(null) }
    var patting by remember { mutableStateOf(false) }
    var tapCount by remember { mutableIntStateOf(0) }
    var flecks by remember { mutableFloatStateOf(0f) }
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current

    // React to MascotDirector acknowledgements (≤ 550ms)
    LaunchedEffect(director.acknowledgements) {
        if (director.acknowledgements <= 0) return@LaunchedEffect
        tapMood = Mood.Happy
        if (!still) {
            launch {
                hop.animateTo(1f, tween(130))
                hop.animateTo(0f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium))
            }
            if (kind == Kind.Moss) {
                launch {
                    delay(style.sproutLagMs.toLong())
                    sway.animateTo(1f, tween(110))
                    sway.animateTo(0f, spring(dampingRatio = 0.35f, stiffness = 280f))
                }
            }
        }
        delay(style.acknowledgeMs.coerceAtMost(550).toLong())
        tapMood = null
    }

    val target = look ?: idleTarget
    val gazeStiff = if (kind == Kind.Moss) 340f else 170f
    val gx by animateFloatAsState(target.x.coerceIn(-1f, 1f), spring(dampingRatio = 0.65f, stiffness = gazeStiff), label = "gx")
    val gy by animateFloatAsState(target.y.coerceIn(-1f, 1f), spring(dampingRatio = 0.65f, stiffness = gazeStiff), label = "gy")
    val tilt by animateFloatAsState(if (look != null) look.x * style.tiltDegrees else idleTilt, spring(dampingRatio = 0.6f, stiffness = 180f), label = "tilt")
    val blink by animateFloatAsState(
        targetValue = maxOf(idleBlink, lid, if (isStone) 0.55f else 0f).coerceIn(0f, 1f),
        animationSpec = tween(style.blinkMs),
        label = "blink",
    )
    val patVal by animateFloatAsState(if (patting) 1f else 0f, spring(dampingRatio = 0.65f, stiffness = 260f), label = "pat")
    val activeMood = when {
        patting -> Mood.Happy
        tapMood != null -> tapMood!!
        director.state == MascotPresentationState.Acknowledge -> Mood.Happy
        else -> mood
    }

    val tapMod = if (!interactive) Modifier else Modifier.pointerInput(kind, still) {
        detectTapGestures(
            onTap = {
                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                tapCount += 1
                val c = tapCount
                scope.launch {
                    if (c >= 5) {
                        tapCount = 0
                        tapMood = Mood.Happy
                        for (i in 1..20) {
                            flecks = i / 20f
                            delay(35)
                        }
                        flecks = 0f
                        tapMood = null
                    } else {
                        tapMood = if (kind == Kind.Moss) Mood.Happy else Mood.Wow
                        if (!still) {
                            launch {
                                hop.animateTo(1f, tween(110))
                                hop.animateTo(0f, spring(dampingRatio = 0.38f, stiffness = Spring.StiffnessMedium))
                            }
                            launch {
                                sway.animateTo(1f, tween(130))
                                sway.animateTo(-0.7f, tween(150))
                                sway.animateTo(0f, spring(dampingRatio = 0.35f, stiffness = 260f))
                            }
                        }
                        delay(style.acknowledgeMs.toLong())
                        tapMood = null
                        delay(1500)
                        if (tapCount == c) tapCount = 0
                    }
                }
            },
            onLongPress = {
                haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                scope.launch {
                    patting = true
                    if (!still) sway.animateTo(0.6f, tween(220))
                    delay(900)
                    patting = false
                    if (!still) sway.animateTo(0f, spring(dampingRatio = 0.5f, stiffness = 200f))
                }
            }
        )
    }

    val spriteName = remember(kind, activeMood, yawning, hop.value > 0.25f, blink > 0.55f, gx, gy) {
        spriteFor(kind, activeMood, yawning, hop.value, blink, Offset(gx, gy))
    }
    val ctx = LocalContext.current
    val spriteBitmap by produceState(
        initialValue = remember(spriteName, artStyle) {
            if (artStyle == ArtStyle.Vinyl) ArtIndex.bitmapSync(ctx, spriteName, 512) else null
        },
        spriteName,
        artStyle,
    ) {
        value = if (artStyle == ArtStyle.Vinyl) {
            ArtIndex.bitmap(ctx, spriteName, 512)
        } else null
    }

    BoxWithConstraints(
        modifier = modifier.aspectRatio(1f).then(tapMod),
        contentAlignment = Alignment.Center,
    ) {
        val currentSprite = spriteBitmap
        if (artStyle == ArtStyle.Vinyl && currentSprite != null) {
            val b = (breath - 0.5f) * 2f
            val amp = if (activeMood == Mood.Sleep) 0.012f else if (kind == Kind.Moss) 0.025f else 0.018f
            val sx = (1f - b * amp * 0.7f + hop.value * 0.06f) * (1f + stoneVal * 0.10f) * (1f + patVal * 0.06f)
            val sy = (1f + b * amp - hop.value * 0.05f) * (1f - stoneVal * 0.14f) * (1f - patVal * 0.07f)
            val dyRatio = (-hop.value * 0.07f - maxOf(0f, b) * 0.01f + stoneVal * 0.03f)
            val rot = tilt * (1f - stoneVal) + sway.value * 4f

            Canvas(Modifier.fillMaxSize()) {
                val u = size.minDimension
                // Contact shadow on tabletop
                val shadowScale = (1f - hop.value * 0.22f).coerceIn(0.6f, 1.1f)
                drawOval(
                    color = Color.Black.copy(alpha = if (isDark) 0.34f else 0.13f),
                    topLeft = Offset(u * (0.5f - 0.28f * shadowScale), u * 0.85f),
                    size = Size(u * 0.56f * shadowScale, u * 0.08f * shadowScale),
                )
                // Otto's warm night-lamp halo when night mode is active
                if (kind == Kind.Otto && lamp && isDark) {
                    val r = u * (0.36f + glow * 0.05f)
                    val lc = Offset(u * 0.5f, u * 0.17f)
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(Palette.BeadLight.copy(alpha = 0.50f), Palette.Bead.copy(alpha = 0.18f), Color.Transparent),
                            center = lc,
                            radius = r,
                        ),
                        radius = r,
                        center = lc,
                    )
                }
            }
            Image(
                bitmap = currentSprite,
                contentDescription = null,
                contentScale = ContentScale.Fit,
                filterQuality = FilterQuality.High,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        scaleX = sx
                        scaleY = sy
                        translationY = size.height * dyRatio
                        rotationZ = rot
                    },
            )
            if (flecks > 0f) {
                Canvas(Modifier.fillMaxSize()) {
                    drawMintFlecks(size.minDimension, Offset(size.width * 0.5f, size.height * 0.2f), flecks)
                }
            }
        } else {
            Canvas(Modifier.fillMaxSize()) {
                val u = size.minDimension
                translate((size.width - u) / 2f, (size.height - u) / 2f) {
                    when (kind) {
                        Kind.Moss -> drawMoss(u, activeMood, Offset(gx, gy), breath, hop.value, sway.value, tilt, blink, flecks, stoneVal, patVal)
                        Kind.Otto -> drawOtto(u, activeMood, Offset(gx, gy), breath, glow, hop.value, sway.value, tilt, blink, lamp, flecks, yawning, patVal)
                    }
                }
            }
        }
    }
}

private fun spriteFor(
    kind: Kind,
    mood: Mood,
    yawning: Boolean,
    hop: Float,
    blink: Float,
    gaze: Offset,
): String {
    val prefix = if (kind == Kind.Moss) "ip_moss" else "ip_otto"
    if (yawning && kind == Kind.Otto) return "ip_otto_yawn.webp"
    if (hop > 0.25f && kind == Kind.Moss) return "ip_moss_hop.webp"
    when (mood) {
        Mood.Sleep -> return "${prefix}_sleep.webp"
        Mood.Happy -> return "${prefix}_glee.webp"
        Mood.Wow -> return "${prefix}_wide.webp"
        Mood.Calm, Mood.Listening -> {}
    }
    if (blink > 0.55f) return "${prefix}_blink.webp"
    if (hypot(gaze.x, gaze.y) > 0.28f) {
        return if (abs(gaze.x) >= abs(gaze.y)) {
            if (gaze.x < 0f) "${prefix}_left.webp" else "${prefix}_right.webp"
        } else {
            if (gaze.y < 0f) "${prefix}_up.webp" else "${prefix}_down.webp"
        }
    }
    return "${prefix}_idle.webp"
}

private fun DrawScope.drawMoss(
    u: Float,
    mood: Mood,
    gaze: Offset,
    breath: Float,
    hop: Float,
    sway: Float,
    tilt: Float,
    blink: Float,
    flecks: Float,
    stone: Float,
    pat: Float,
) {
    val b = (breath - 0.5f) * 2f
    val amp = if (mood == Mood.Sleep) 0.015f else 0.032f
    val sx = (1f - b * amp * 0.7f + hop * 0.07f) * (1f + stone * 0.10f) * (1f + pat * 0.06f)
    val sy = (1f + b * amp - hop * 0.05f) * (1f - stone * 0.14f) * (1f - pat * 0.07f)
    val lift = hop * u * 0.09f + maxOf(0f, b) * u * 0.012f - stone * u * 0.025f
    val foot = Offset(u * 0.5f, u * 0.87f)

    // Ground shadow
    drawOval(
        color = Color.Black.copy(alpha = 0.10f * (1f - hop * 0.4f)),
        topLeft = Offset(u * (0.20f + hop * 0.04f), u * 0.84f),
        size = Size(u * (0.60f - hop * 0.08f), u * 0.08f),
    )

    translate(0f, -lift) {
        rotate(tilt * (1f - stone), foot) {
            scale(sx, sy, foot) {
                val body = Path().apply {
                    moveTo(u * 0.14f, u * 0.63f)
                    cubicTo(u * 0.11f, u * 0.36f, u * 0.27f, u * 0.22f, u * 0.50f, u * 0.22f)
                    cubicTo(u * 0.74f, u * 0.22f, u * 0.89f, u * 0.37f, u * 0.86f, u * 0.63f)
                    cubicTo(u * 0.84f, u * 0.81f, u * 0.70f, u * 0.87f, u * 0.50f, u * 0.87f)
                    cubicTo(u * 0.30f, u * 0.87f, u * 0.16f, u * 0.81f, u * 0.14f, u * 0.63f)
                    close()
                }
                drawPath(body, Palette.Moss)
                drawPath(
                    body,
                    Brush.radialGradient(
                        colors = listOf(Palette.MossLight.copy(alpha = 0.55f), Color.Transparent),
                        center = Offset(u * 0.38f, u * 0.34f),
                        radius = u * 0.44f,
                    ),
                )
                val shade = Path().apply {
                    moveTo(u * 0.16f, u * 0.69f)
                    cubicTo(u * 0.28f, u * 0.82f, u * 0.72f, u * 0.82f, u * 0.84f, u * 0.69f)
                    cubicTo(u * 0.82f, u * 0.82f, u * 0.69f, u * 0.87f, u * 0.50f, u * 0.87f)
                    cubicTo(u * 0.31f, u * 0.87f, u * 0.18f, u * 0.82f, u * 0.16f, u * 0.69f)
                    close()
                }
                drawPath(shade, Palette.MossDeep.copy(alpha = 0.55f))
                listOf(
                    Offset(0.28f, 0.40f) to 0.016f,
                    Offset(0.73f, 0.44f) to 0.013f,
                    Offset(0.66f, 0.33f) to 0.011f,
                    Offset(0.24f, 0.68f) to 0.012f,
                    Offset(0.74f, 0.70f) to 0.015f,
                ).forEach { (p, r) ->
                    drawCircle(Palette.MossDeep.copy(alpha = 0.38f), u * r, Offset(u * p.x, u * p.y))
                }

                // Mint two-leaf sprout on top
                val stem = Offset(u * 0.50f, u * 0.23f)
                val sproutDroop = stone * -24f
                rotate(b * 4.5f + sway * 18f + gaze.x * 4f + sproutDroop, stem) {
                    val tip = Offset(u * 0.50f, u * 0.115f)
                    drawLine(Palette.MintVein, stem, tip, strokeWidth = u * 0.025f, cap = StrokeCap.Round)
                    mintLeaf(tip, u, angle = -34f, scale = 1f)
                    mintLeaf(tip, u, angle = 30f, scale = 0.86f)
                }

                if (flecks > 0f) drawMintFlecks(u, stem, flecks)

                // Rosy cheeks when happy or patted
                if (mood == Mood.Happy || pat > 0.1f) {
                    val ca = maxOf(if (mood == Mood.Happy) 0.28f else 0f, pat * 0.32f)
                    drawOval(Color(0xFFE58E73).copy(alpha = ca), Offset(u * 0.22f, u * 0.58f), Size(u * 0.11f, u * 0.06f))
                    drawOval(Color(0xFFE58E73).copy(alpha = ca), Offset(u * 0.67f, u * 0.58f), Size(u * 0.11f, u * 0.06f))
                }

                // Eyes
                val shift = Offset(gaze.x * u * 0.026f, gaze.y * u * 0.018f)
                val r = u * if (mood == Mood.Wow) 0.098f else 0.086f
                eye(Offset(u * 0.38f, u * 0.53f) + shift, r, gaze, mood, blink, Palette.Moss)
                eye(Offset(u * 0.62f, u * 0.53f) + shift, r, gaze, mood, blink, Palette.Moss)
            }
        }
    }
}

private fun DrawScope.mintLeaf(base: Offset, u: Float, angle: Float, scale: Float) {
    rotate(angle, base) {
        val w = u * 0.062f * scale
        val h = u * 0.108f * scale
        val leaf = Path().apply {
            moveTo(base.x, base.y)
            cubicTo(base.x - w * 1.15f, base.y - h * 0.22f, base.x - w * 0.95f, base.y - h * 0.82f, base.x, base.y - h)
            cubicTo(base.x + w * 0.95f, base.y - h * 0.82f, base.x + w * 1.15f, base.y - h * 0.22f, base.x, base.y)
            close()
        }
        drawPath(leaf, Palette.Mint)
        val light = Path().apply {
            moveTo(base.x, base.y - h * 0.08f)
            cubicTo(base.x - w * 0.85f, base.y - h * 0.26f, base.x - w * 0.72f, base.y - h * 0.78f, base.x, base.y - h * 0.95f)
            close()
        }
        drawPath(light, Palette.MintLight.copy(alpha = 0.65f))
        drawLine(Palette.MintVein.copy(alpha = 0.65f), Offset(base.x, base.y - h * 0.08f), Offset(base.x, base.y - h * 0.82f), u * 0.011f, StrokeCap.Round)
    }
}

private fun DrawScope.drawMintFlecks(u: Float, origin: Offset, t: Float) {
    val a = (1f - t).coerceIn(0f, 1f)
    listOf(-0.22f to -0.18f, 0.24f to -0.15f, -0.12f to -0.28f, 0.14f to -0.26f, 0.0f to -0.32f).forEachIndexed { i, (dx, dy) ->
        val p = Offset(origin.x + dx * u * (0.4f + t * 0.9f), origin.y + dy * u * (0.3f + t * 0.9f))
        mintLeaf(p, u, angle = (i * 52f + t * 90f) - 60f, scale = 0.42f * a)
    }
}

private fun DrawScope.drawOtto(
    u: Float,
    mood: Mood,
    gaze: Offset,
    breath: Float,
    glow: Float,
    hop: Float,
    sway: Float,
    tilt: Float,
    blink: Float,
    lamp: Boolean,
    flecks: Float,
    yawning: Boolean,
    pat: Float,
) {
    val b = (breath - 0.5f) * 2f
    val amp = if (mood == Mood.Sleep) 0.012f else 0.022f
    val sx = (1f - b * amp * 0.6f + hop * 0.05f) * (1f + pat * 0.05f)
    val sy = (1f + b * amp - hop * 0.04f) * (1f - pat * 0.06f)
    val lift = hop * u * 0.07f + maxOf(0f, b) * u * 0.008f
    val foot = Offset(u * 0.5f, u * 0.89f)

    drawOval(
        color = Color.Black.copy(alpha = 0.11f * (1f - hop * 0.4f)),
        topLeft = Offset(u * 0.23f, u * 0.86f),
        size = Size(u * 0.54f, u * 0.07f),
    )

    translate(0f, -lift) {
        rotate(tilt * 0.7f, foot) {
            scale(sx, sy, foot) {
                val base = Offset(u * 0.50f, u * 0.25f)
                val bob = b * 2.5f + sway * 14f + gaze.x * 3f
                val rad = bob * (PI.toFloat() / 180f)
                val len = u * 0.12f
                val bead = Offset(base.x + sin(rad) * len, base.y - cos(rad) * len + abs(sin(rad)) * u * 0.015f)
                val ctrl = Offset(base.x + sin(rad) * len * 0.35f, base.y - len * 0.55f)

                if (lamp) {
                    val r = u * (0.22f + glow * 0.04f + hop * 0.05f)
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(Palette.BeadLight.copy(alpha = 0.55f), Palette.Bead.copy(alpha = 0.18f), Color.Transparent),
                            center = bead,
                            radius = r,
                        ),
                        radius = r,
                        center = bead,
                    )
                }

                // Tall rounded blue body
                val top = u * 0.24f
                val h = u * 0.65f
                val left = u * 0.24f
                val w = u * 0.52f
                val cr = CornerRadius(u * 0.25f, u * 0.25f)
                drawRoundRect(Palette.Rod, Offset(left, top), Size(w, h), cr)
                drawRoundRect(
                    Brush.radialGradient(
                        colors = listOf(Palette.RodLight.copy(alpha = 0.50f), Color.Transparent),
                        center = Offset(u * 0.40f, u * 0.38f),
                        radius = u * 0.36f,
                    ),
                    Offset(left, top),
                    Size(w, h),
                    cr,
                )
                drawRoundRect(Palette.RodDeep.copy(alpha = 0.38f), Offset(u * 0.30f, u * 0.60f), Size(u * 0.40f, u * 0.23f), CornerRadius(u * 0.18f))

                // Curved stem & golden ten-bead lamp
                val stem = Path().apply {
                    moveTo(base.x, base.y)
                    quadraticTo(ctrl.x, ctrl.y, bead.x, bead.y)
                }
                drawPath(stem, Palette.RodDeep, style = Stroke(u * 0.026f, cap = StrokeCap.Round))
                drawCircle(if (lamp) Palette.Bead else Palette.Stone, u * 0.058f, bead)
                if (lamp) drawCircle(Palette.Paper.copy(alpha = 0.75f), u * 0.020f, bead + Offset(-u * 0.018f, -u * 0.018f))
                if (flecks > 0f) {
                    drawCircle(
                        Palette.BeadLight.copy(alpha = (1f - flecks) * 0.6f),
                        u * (0.08f + flecks * 0.28f),
                        bead,
                        style = Stroke(u * 0.018f),
                    )
                }

                val shift = Offset(gaze.x * u * 0.020f, gaze.y * u * 0.016f)
                val r = u * if (mood == Mood.Wow) 0.086f else 0.076f
                val lidVal = if (yawning) 0.85f else blink
                eye(Offset(u * 0.40f, u * 0.46f) + shift, r, gaze, mood, lidVal, Palette.Rod)
                eye(Offset(u * 0.60f, u * 0.46f) + shift, r, gaze, mood, lidVal, Palette.Rod)

                // Yawn mouth when sleep timer starts
                if (yawning) {
                    drawOval(
                        color = Palette.Ink.copy(alpha = 0.75f),
                        topLeft = Offset(u * 0.465f, u * 0.56f),
                        size = Size(u * 0.07f, u * 0.085f),
                    )
                }
            }
        }
    }
}

private fun DrawScope.eye(center: Offset, r: Float, gaze: Offset, mood: Mood, blink: Float, lidColor: Color) {
    when (mood) {
        Mood.Sleep -> {
            val p = Path().apply {
                moveTo(center.x - r * 0.8f, center.y)
                quadraticTo(center.x, center.y + r * 0.55f, center.x + r * 0.8f, center.y)
            }
            drawPath(p, Palette.Ink, style = Stroke(width = r * 0.28f, cap = StrokeCap.Round))
        }
        Mood.Happy -> {
            val p = Path().apply {
                moveTo(center.x - r * 0.8f, center.y + r * 0.2f)
                quadraticTo(center.x, center.y - r * 0.65f, center.x + r * 0.8f, center.y + r * 0.2f)
            }
            drawPath(p, Palette.Ink, style = Stroke(width = r * 0.30f, cap = StrokeCap.Round))
        }
        Mood.Calm, Mood.Listening, Mood.Wow -> {
            drawCircle(Palette.Paper, r, center)
            val maxShift = r * 0.34f
            val mag = hypot(gaze.x, gaze.y).coerceAtMost(1f)
            val dir = if (mag > 0.01f) Offset(gaze.x / mag, gaze.y / mag) else Offset.Zero
            val pupil = center + dir * (maxShift * mag)
            val pr = r * when (mood) {
                Mood.Wow -> 0.60f
                Mood.Listening -> 0.56f
                else -> 0.50f
            }
            drawCircle(Palette.Ink, pr, pupil)
            drawCircle(Palette.Paper, pr * 0.30f, pupil + Offset(-pr * 0.28f, -pr * 0.30f))
            if (blink > 0.02f) {
                val h = r * 2.1f * blink.coerceIn(0f, 1f)
                drawRoundRect(lidColor, Offset(center.x - r * 1.05f, center.y - r * 1.05f), Size(r * 2.1f, h), CornerRadius(r))
            }
        }
    }
}
