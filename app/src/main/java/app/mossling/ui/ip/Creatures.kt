package app.mossling.ui.ip

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateOffsetAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import app.mossling.ui.components.reducedMotion
import kotlinx.coroutines.launch
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.mossling.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/** The two companions. Geometry is in a 100 × 100 box (see native/tools/creatures_reference.js). */
enum class Kind { Moss, Otto }
enum class Mood { Open, Happy, Wow, Sleep }

private fun p(d: String): Path = PathParser().parsePathString(d).toPath()

private object Shapes {
    val mossStem = p("M49 36 C48 30 49.2 23 50 17.6")
    // mint, not just any sprout: two serrated leaves and a small pair on top
    val mintA = p("M49.80 24.00 Q52.61 27.00 54.92 26.72 L59.05 26.80 Q59.05 25.74 59.20 25.58 L62.47 24.24 Q62.40 23.06 62.52 22.84 L65.12 20.40 Q65.11 19.32 65.21 19.07 L67.19 15.60 Q67.33 14.76 67.42 14.51 Q67.86 13.39 68.00 13.00 Q67.59 12.94 66.40 12.81 Q66.13 12.78 65.32 12.51 L61.33 12.65 Q61.06 12.62 60.11 12.11 L56.74 13.28 Q56.49 13.28 55.48 12.67 L52.77 14.94 Q52.56 15.00 51.62 14.51 L49.78 18.20 Q48.45 20.12 49.80 24.00Z")
    val mintB = p("M48.80 26.00 Q49.48 22.34 48.07 20.84 L45.98 17.84 Q45.22 18.42 45.03 18.40 L42.38 16.79 Q41.57 17.49 41.36 17.53 L38.27 17.00 Q37.50 17.60 37.27 17.66 L33.77 18.16 Q33.10 18.52 32.87 18.59 Q31.85 18.89 31.50 19.00 Q31.67 19.32 32.20 20.25 Q32.32 20.46 32.55 21.19 L34.72 23.98 Q34.84 24.18 34.97 25.14 L37.56 26.91 Q37.69 27.09 37.78 28.15 L40.80 28.84 Q40.96 28.96 41.10 29.90 L44.69 29.20 Q46.74 29.10 48.80 26.00Z")
    val mintC = p("M50.40 17.80 Q52.30 18.17 53.12 17.39 L55.35 14.61 Q55.06 13.89 55.07 13.67 L55.09 9.92 Q54.83 9.22 54.77 8.96 Q54.65 8.39 54.60 8.20 Q54.42 8.29 53.92 8.59 Q53.70 8.72 53.00 9.01 L50.27 11.57 Q50.11 11.72 49.38 12.00 L48.85 15.52 Q48.84 16.66 50.40 17.80Z")
    val mintD = p("M49.60 18.00 Q50.87 16.72 50.70 15.69 L49.72 12.60 Q49.01 12.46 48.84 12.35 L45.98 10.48 Q45.30 10.33 45.07 10.24 Q44.57 10.06 44.40 10.00 Q44.38 10.18 44.35 10.72 Q44.33 10.95 44.20 11.63 L44.74 15.01 Q44.78 15.22 44.61 15.92 L47.05 18.07 Q47.92 18.64 49.60 18.00Z")
    val mintVeins = p("M49.80 24.00 L65.45 14.54 M55.26 20.70 L59.82 22.48 M55.26 20.70 L55.80 15.84 M59.26 18.28 L63.34 19.26 M59.26 18.28 L60.29 14.22 M62.90 16.08 L66.18 15.74 M62.90 16.08 L64.73 13.34 M48.80 26.00 L33.92 19.98 M43.61 23.90 L42.51 19.66 M43.61 23.90 L39.87 26.18 M39.80 22.36 L38.38 18.90 M39.80 22.36 L36.38 23.86 M36.34 20.96 L34.40 18.80 M36.34 20.96 L33.44 21.16 M50.40 17.80 L54.01 9.54 M49.60 18.00 L45.13 11.12")
    val mintFleck = p("M0 3 C1.6 1.2 4 0.6 6 0.8 C5.6 3 4 4.6 0 3Z")
    val mossBody = p("M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z")
    val mossTufts = p("M24 52 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M64 44 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M70 72 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M28 72 c2 -2 5 -2 7 0 c-2 1.6 -5 1.6 -7 0Z")
    val ottoStem = p("M53 17 C54 12 57 8 61 6")
    val ottoBody = p("M30 84 C25 74 24 58 26 44 C28 28 38 16 52 16 C65 17 74 28 75 44 C76 60 74 75 70 84 C60 88 40 88 30 84Z")
    val ottoDip = p("M25.2 64 C35 68 64 68 75.4 63 C75 71 73 78 70 84 C60 88 40 88 30 84 C27.6 78 26 71 25.2 64Z")
}

private val Ink = Palette.Ink
private val White = Color(0xFFFBF9F3)

/**
 * A companion. [look] is where the pupils point, each axis −1…1. [lid] closes the eye (0 open, 1 shut); null uses
 * the character's own rest (Otto rests under a heavy lid). When [alive] the eyes blink now and then.
 */
@Composable
fun Creature(
    kind: Kind,
    modifier: Modifier = Modifier,
    mood: Mood = Mood.Open,
    look: Offset = Offset.Zero,
    lid: Float? = null,
    lean: Float = 0f,
    alive: Boolean = true,
    label: String? = null,
    poke: Boolean = false,
) {
    val still = !alive || reducedMotion()
    val eyes by animateOffsetAsState(look, tween(420, easing = FastOutSlowInEasing), label = "look")
    val blink = remember { Animatable(0f) }
    val glance = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    val hop = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    var shown by remember { mutableStateOf(mood) }

    // blinking: irregular, sometimes twice — never on a sleeping or smiling face
    LaunchedEffect(still, mood) {
        if (still || mood != Mood.Open && mood != Mood.Wow) return@LaunchedEffect
        while (true) {
            delay(2600L + Random.nextLong(4200))
            blink.animateTo(1f, tween(70)); blink.animateTo(0f, tween(130))
            if (Random.nextInt(5) == 0) { delay(160); blink.animateTo(1f, tween(60)); blink.animateTo(0f, tween(120)) }
        }
    }
    // a glance away now and then, held, and back to what it was looking at
    LaunchedEffect(still, mood) {
        if (still || mood == Mood.Sleep) return@LaunchedEffect
        while (true) {
            delay(7000L + Random.nextLong(7000))
            val to = Offset(Random.nextFloat() * 1.2f - 0.6f, Random.nextFloat() * 0.8f - 0.5f) - look * 0.6f
            glance.animateTo(to, tween(380, easing = FastOutSlowInEasing))
            delay(700L + Random.nextLong(900))
            glance.animateTo(Offset.Zero, tween(520, easing = FastOutSlowInEasing))
        }
    }
    // becoming happy is one small hop, not a celebration
    LaunchedEffect(mood) {
        if (mood == Mood.Happy && shown != Mood.Happy && !still) {
            hop.animateTo(1f, tween(160, easing = FastOutSlowInEasing)); hop.animateTo(0f, spring(dampingRatio = 0.45f, stiffness = 500f))
        }
        shown = mood
    }
    // breathing: a slow rise of a percent or so; slower and deeper asleep. Read only in the draw phase.
    val breath = if (still) null else rememberInfiniteTransition(label = "breath").animateFloat(
        0f, 1f, infiniteRepeatable(tween(if (mood == Mood.Sleep) 4200 else 3200, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "b",
    )
    val sem = if (label != null) Modifier.semantics { contentDescription = label } else Modifier
    val leaf = remember { Animatable(0f) }
    val fleck = remember { Animatable(0f) }
    var taps by remember { mutableStateOf(0) }
    var lastTap by remember { mutableStateOf(0L) }
    val tap = if (poke && !still) Modifier.clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
        val now = System.currentTimeMillis()
        taps = if (now - lastTap < 900) taps + 1 else 1
        lastTap = now
        scope.launch { blink.animateTo(1f, tween(60)); blink.animateTo(0f, tween(110)) }
        scope.launch { hop.snapTo(0f); hop.animateTo(0.7f, tween(120)); hop.animateTo(0f, spring(dampingRatio = 0.4f, stiffness = 600f)) }
        scope.launch { leaf.snapTo(14f); leaf.animateTo(0f, spring(dampingRatio = 0.25f, stiffness = 180f)) }
        // five quick taps: a few mint leaves drift up (小薄荷)
        if (taps >= 5) { taps = 0; scope.launch { fleck.snapTo(0f); fleck.animateTo(1f, tween(1600, easing = FastOutSlowInEasing)); fleck.snapTo(0f) } }
    } else Modifier
    Canvas(modifier.aspectRatio(1f).then(sem).then(tap)) {
        val s = min(size.width, size.height) / 100f
        val b = breath?.value ?: 0f
        val amp = if (mood == Mood.Sleep) 0.022f else 0.012f
        withTransform({
            translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2 - hop.value * 7f * s)
            scale(s, s, Offset.Zero)
            // squash and stretch from the feet, so the shadow stays put
            scale(1f - b * amp * 0.5f, 1f + b * amp, Offset(50f, 88f))
        }) {
            rotate(lean, Offset(50f, 88f)) {
                val rest = lid ?: if (kind == Kind.Otto) 0.34f else 0f
                val l = max(rest, blink.value)
                val e = eyes + glance.value
                if (kind == Kind.Moss) drawMoss(mood, e, l, (b - 0.5f) * 6f + leaf.value) else drawOtto(mood, e, l, (b - 0.5f) * 5f + leaf.value)
            }
            val f = fleck.value
            if (f > 0f) {
                val a = (if (f < 0.2f) f / 0.2f else 1f - (f - 0.2f) / 0.8f).coerceIn(0f, 1f)
                listOf(Triple(36f, -8f, 0f), Triple(58f, 6f, 0.12f), Triple(47f, -2f, 0.24f)).forEach { (x, dx, d) ->
                    val g = ((f - d) / (1f - d)).coerceIn(0f, 1f)
                    translate(x + dx * g, 14f - g * 26f) { rotate(g * 120f + dx * 4f, Offset(3f, 2f)) { drawPath(Shapes.mintFleck, Palette.Mint.copy(alpha = a)) } }
                }
            }
        }
    }
}

private fun DrawScope.shadow(rx: Float) =
    drawOval(Ink.copy(alpha = 0.09f), Offset(50f - rx, 87.5f), Size(rx * 2, 6f))

private fun DrawScope.leg(x: Float) = drawRoundRect(Ink, Offset(x, 80f), Size(6.5f, 10f), CornerRadius(3.2f))

private fun DrawScope.body(path: Path, fill: Color, deep: Color) {
    translate(1.4f, 1.2f) { drawPath(path, deep) }
    drawPath(path, fill)
}

private fun DrawScope.eye(cx: Float, cy: Float, rx: Float, ry: Float, mood: Mood, look: Offset, lid: Float, body: Color) {
    when (mood) {
        Mood.Sleep -> {
            val path = Path().apply { moveTo(cx - rx, cy); quadraticBezierTo(cx, cy + ry * 0.9f, cx + rx, cy) }
            drawPath(path, Ink, style = Stroke(max(1.6f, ry * 0.32f), cap = StrokeCap.Round))
            return
        }
        else -> Unit
    }
    val oval = Path().apply { addOval(androidx.compose.ui.geometry.Rect(cx - rx, cy - ry, cx + rx, cy + ry)) }
    clipPath(oval) {
        drawRect(White, Offset(cx - rx, cy - ry), Size(rx * 2, ry * 2))
        val pr = min(rx, ry) * if (mood == Mood.Wow) 0.5f else 0.62f
        val px = cx + look.x.coerceIn(-1f, 1f) * (rx - pr - 0.3f)
        val py = cy + look.y.coerceIn(-1f, 1f) * (ry - pr - 0.3f)
        drawCircle(Ink, pr, Offset(px, py))
        if (mood == Mood.Happy) {
            // the cheek pushes the lower lid up: what remains is a crescent of a smiling eye
            drawOval(body, Offset(cx - rx * 1.3f, cy + ry * 0.12f), Size(rx * 2.6f, ry * 2f))
        }
        if (lid > 0f) drawRect(body, Offset(cx - rx - 0.6f, cy - ry - 0.6f), Size(rx * 2 + 1.2f, (ry * 2 + 1.2f) * lid))
    }
}

private fun DrawScope.drawMoss(mood: Mood, look: Offset, lid: Float, sway: Float) {
    shadow(31f)
    drawPath(Shapes.mossStem, Palette.MossDeep, style = Stroke(2.2f, cap = StrokeCap.Round))
    rotate(sway, Offset(49.6f, 25f)) {
        drawPath(Shapes.mintB, Palette.MintLight)
        drawPath(Shapes.mintA, Palette.Mint)
        drawPath(Shapes.mintD, Palette.MintPale)
        drawPath(Shapes.mintC, Palette.MintPale)
        drawPath(Shapes.mintVeins, Palette.MintVein.copy(alpha = 0.45f), style = Stroke(0.6f, cap = StrokeCap.Round))
    }
    leg(33f); leg(59f)
    body(Shapes.mossBody, Palette.Moss, Palette.MossDeep)
    drawPath(Shapes.mossTufts, Palette.MossLight.copy(alpha = 0.7f))
    eye(43f, 55f, 6.4f, 7.4f, mood, look, lid, Palette.Moss)
    eye(58f, 55f, 6.4f, 7.4f, mood, look, lid, Palette.Moss)
    if (mood == Mood.Wow) drawOval(Ink, Offset(48.3f, 65.2f), Size(4.4f, 5.6f))
}

private fun DrawScope.drawOtto(mood: Mood, look: Offset, lid: Float, swing: Float) {
    shadow(23f)
    rotate(swing, Offset(53f, 17f)) {
        drawPath(Shapes.ottoStem, Palette.RodDeep, style = Stroke(2.2f, cap = StrokeCap.Round))
        drawCircle(Palette.Bead, 3.2f, Offset(62f, 5.8f))
    }
    leg(38f); leg(56f)
    body(Shapes.ottoBody, Palette.Rod, Palette.RodDeep)
    drawPath(Shapes.ottoDip, Palette.RodDeep.copy(alpha = 0.55f))
    eye(51f, 44f, 12.5f, 11.5f, mood, look, if (mood == Mood.Wow) 0f else lid, Palette.Rod)
    drawCircle(Palette.Bead, 6.2f, Offset(74f, 70f))
    drawCircle(Palette.BeadLight, 1.8f, Offset(72.2f, 68f))
    if (mood == Mood.Wow) drawOval(Ink, Offset(48.8f, 61.2f), Size(4.4f, 5.6f))
}
