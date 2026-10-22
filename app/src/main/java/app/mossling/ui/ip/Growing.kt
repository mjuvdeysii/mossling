package app.mossling.ui.ip

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.mossling.ui.components.reducedMotion
import app.mossling.ui.theme.Palette
import kotlin.math.PI
import kotlin.math.sin

private val Skin = Color(0xFFEAC9A1)
private val Body = Palette.Bead
private val Limb = Color(0xFFB98A12)

/**
 * The growth map's icon: the same wooden peg child as in the pictures, growing from 0 to 3 in one loop — lying,
 * on the tummy with the head up, sitting, crawling, standing, walking — a little taller at each stage, then back to
 * the start. About five seconds a loop; still (standing) when animations are off.
 */
@Composable
fun GrowingChild(modifier: Modifier = Modifier) {
    val still = reducedMotion()
    val t = if (still) null else rememberInfiniteTransition(label = "grow").animateFloat(
        0f, 6f, infiniteRepeatable(tween(5400, easing = LinearEasing), RepeatMode.Restart), label = "t",
    )
    Canvas(modifier.semantics { contentDescription = "从出生到三岁慢慢长大" }) {
        val s = size.minDimension / 48f
        withTransform({ translate((size.width - 48 * s) / 2, (size.height - 48 * s) / 2); scale(s, s, Offset.Zero) }) {
            // the floor
            drawLine(Palette.Stone, Offset(4f, 42f), Offset(44f, 42f), 1.6f, StrokeCap.Round)
            // start in the middle of a pose, never on the hand-over between two
            val v = t?.value?.let { (it + 0.5f) % 6f } ?: 4.5f
            val stage = v.toInt().coerceIn(0, 5)
            val f = v - stage                       // progress inside the stage
            // ease in and out of each pose: a short fade where one stage hands over to the next
            val fade = when { f < 0.12f -> 0.25f + 0.75f * f / 0.12f; f > 0.88f -> 0.25f + 0.75f * (1f - f) / 0.12f; else -> 1f }.coerceIn(0f, 1f)
            val a = if (t == null) 1f else fade
            when (stage) {
                0 -> lying(a)
                1 -> tummy(a, f)
                2 -> sitting(a, f)
                3 -> crawling(a, f)
                4 -> standing(a, f)
                else -> walking(a, f)
            }
        }
    }
}

private fun DrawScope.head(c: Offset, r: Float, a: Float) = drawCircle(Skin.copy(alpha = a), r, c)
private fun DrawScope.limb(p: Offset, q: Offset, w: Float, a: Float) = drawLine(Limb.copy(alpha = a), p, q, w, StrokeCap.Round)
private fun DrawScope.peg(x: Float, top: Float, bottom: Float, w: Float, a: Float) =
    drawRoundRect(Body.copy(alpha = a), Offset(x - w / 2, top), Size(w, bottom - top), CornerRadius(w / 2))

private fun DrawScope.lying(a: Float) {
    drawRoundRect(Body.copy(alpha = a), Offset(16f, 34f), Size(18f, 8f), CornerRadius(4f))
    head(Offset(12f, 37.5f), 4.6f, a)
    limb(Offset(30f, 35f), Offset(33f, 30f), 2.2f, a); limb(Offset(26f, 35f), Offset(27f, 30.5f), 2.2f, a)
}

private fun DrawScope.tummy(a: Float, f: Float) {
    val lift = sin(f * PI.toFloat()) * 1.6f
    drawRoundRect(Body.copy(alpha = a), Offset(17f, 35f), Size(19f, 7f), CornerRadius(3.5f))
    head(Offset(14f, 32.5f - lift), 4.8f, a)
    limb(Offset(19f, 38f), Offset(12f, 41f), 2.3f, a)
}

private fun DrawScope.sitting(a: Float, f: Float) {
    peg(24f, 26f, 41f, 11f, a)
    limb(Offset(22f, 40.5f), Offset(14f, 41f), 2.6f, a)
    val wave = sin(f * 2 * PI.toFloat()) * 2f
    limb(Offset(21f, 31f), Offset(15f, 28f + wave), 2.3f, a)
    head(Offset(24f, 20.5f), 5.4f, a)
}

private fun DrawScope.crawling(a: Float, f: Float) {
    val x = 8f + f * 10f
    val step = sin(f * 4 * PI.toFloat()) * 1.5f
    drawRoundRect(Body.copy(alpha = a), Offset(x + 6f, 28f), Size(16f, 8f), CornerRadius(4f))
    limb(Offset(x + 9f, 34f), Offset(x + 8f + step, 41f), 2.6f, a)
    limb(Offset(x + 19f, 34f), Offset(x + 21f - step, 41f), 2.6f, a)
    head(Offset(x + 4f, 27f), 5.2f, a)
}

private fun DrawScope.standing(a: Float, f: Float) {
    val sway = sin(f * 2 * PI.toFloat()) * 2f
    rotate(sway, Offset(24f, 41f)) {
        limb(Offset(22f, 34f), Offset(21.5f, 41f), 2.8f, a); limb(Offset(26f, 34f), Offset(26.5f, 41f), 2.8f, a)
        peg(24f, 20f, 36f, 11f, a)
        limb(Offset(19.5f, 24f), Offset(14f, 18f), 2.4f, a); limb(Offset(28.5f, 24f), Offset(34f, 18f), 2.4f, a)
        head(Offset(24f, 14f), 5.6f, a)
    }
}

private fun DrawScope.walking(a: Float, f: Float) {
    val x = 18f + f * 12f
    val swing = sin(f * 4 * PI.toFloat()) * 4f
    limb(Offset(x - 1.5f, 32f), Offset(x - 1.5f - swing, 41f), 3f, a); limb(Offset(x + 1.5f, 32f), Offset(x + 1.5f + swing, 41f), 3f, a)
    peg(x, 15f, 34f, 11.5f, a)
    limb(Offset(x - 4.5f, 20f), Offset(x - 4.5f + swing * 0.8f, 28f), 2.5f, a); limb(Offset(x + 4.5f, 20f), Offset(x + 4.5f - swing * 0.8f, 28f), 2.5f, a)
    head(Offset(x, 8.6f), 6f, a)
}
