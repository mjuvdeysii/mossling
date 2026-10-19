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
    val mossStem = p("M47 36 C46 29 47 23 50 18")
    val mossLeafA = p("M50 19 C52 11 60 8 65 10 C62 17 55 21 50 19Z")
    val mossLeafB = p("M48.5 25 C45 20 38 19 35 21 C38 26 44 28 48.5 25Z")
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
    val tap = if (poke && !still) Modifier.clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
        scope.launch { blink.animateTo(1f, tween(60)); blink.animateTo(0f, tween(110)) }
        scope.launch { hop.snapTo(0f); hop.animateTo(0.7f, tween(120)); hop.animateTo(0f, spring(dampingRatio = 0.4f, stiffness = 600f)) }
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
                if (kind == Kind.Moss) drawMoss(mood, e, l) else drawOtto(mood, e, l)
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

private fun DrawScope.drawMoss(mood: Mood, look: Offset, lid: Float) {
    shadow(31f)
    drawPath(Shapes.mossStem, Palette.MossDeep, style = Stroke(2.2f, cap = StrokeCap.Round))
    drawPath(Shapes.mossLeafA, Palette.Sprout)
    drawPath(Shapes.mossLeafB, Palette.MossLight)
    leg(33f); leg(59f)
    body(Shapes.mossBody, Palette.Moss, Palette.MossDeep)
    drawPath(Shapes.mossTufts, Palette.MossLight.copy(alpha = 0.7f))
    eye(43f, 55f, 6.4f, 7.4f, mood, look, lid, Palette.Moss)
    eye(58f, 55f, 6.4f, 7.4f, mood, look, lid, Palette.Moss)
    if (mood == Mood.Wow) drawOval(Ink, Offset(48.3f, 65.2f), Size(4.4f, 5.6f))
}

private fun DrawScope.drawOtto(mood: Mood, look: Offset, lid: Float) {
    shadow(23f)
    drawPath(Shapes.ottoStem, Palette.RodDeep, style = Stroke(2.2f, cap = StrokeCap.Round))
    drawCircle(Palette.Bead, 3.2f, Offset(62f, 5.8f))
    leg(38f); leg(56f)
    body(Shapes.ottoBody, Palette.Rod, Palette.RodDeep)
    drawPath(Shapes.ottoDip, Palette.RodDeep.copy(alpha = 0.55f))
    eye(51f, 44f, 12.5f, 11.5f, mood, look, if (mood == Mood.Wow) 0f else lid, Palette.Rod)
    drawCircle(Palette.Bead, 6.2f, Offset(74f, 70f))
    drawCircle(Palette.BeadLight, 1.8f, Offset(72.2f, 68f))
    if (mood == Mood.Wow) drawOval(Ink, Offset(48.8f, 61.2f), Size(4.4f, 5.6f))
}
