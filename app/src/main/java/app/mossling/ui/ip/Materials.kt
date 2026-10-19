package app.mossling.ui.ip

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import app.mossling.ui.theme.Palette

/**
 * Each play is shown by the material it uses, laid out on a mat the way a prepared environment would present it:
 * one thing, ready, nothing else around it. Six families cover the 46 plays. Flat shapes, wood and paint colours,
 * a single soft shadow — a still life, not a cartoon.
 */
enum class Family(val label: String) {
    Words("语言"), Hands("动作"), Mind("认知"), Together("关系"), Senses("感官"), Life("生活");

    companion object {
        fun of(domains: List<String>): Family {
            val d = domains.joinToString()
            return when {
                listOf("精细", "手部", "运动", "大运动").any { it in d } -> Hands
                listOf("因果", "认知", "问题", "记忆", "计划").any { it in d } -> Mind
                listOf("感知", "视觉").any { it in d } -> Senses
                listOf("自理", "自主", "生活", "安全", "规则", "调节", "照护").any { it in d } -> Life
                listOf("语言", "表达", "共读").any { it in d } -> Words
                else -> Together
            }
        }
    }
}

private val Ink = Palette.Ink
private val Shade = Palette.Ink.copy(alpha = 0.10f)
private val Linen = Color(0xFFE9E3D6)
private val Glass = Color(0xFFBFD3D6)
private val Water = Color(0xFF8FB3BD)
private val Brass = Color(0xFFC59A3A)
private val Red = Color(0xFFB8452E)
private val WoodDeep = Color(0xFFA77B47)
private val Willow = Color(0xFFCDAE7A)

@Composable
fun MaterialStill(family: Family, modifier: Modifier = Modifier, ground: Color = Linen) {
    Canvas(modifier.aspectRatio(1.6f).semantics { contentDescription = "教具：" + family.label }) {
        val s = size.width / 160f
        withTransform({ scale(s, s, Offset.Zero) }) {
            // the mat, unrolled
            drawRoundRect(ground, Offset(10f, 58f), Size(140f, 34f), CornerRadius(4f))
            drawLine(Ink.copy(alpha = 0.06f), Offset(14f, 62f), Offset(146f, 62f), 0.8f)
            when (family) {
                Family.Words -> basket()
                Family.Hands -> pegAndRings()
                Family.Mind -> permanenceBox()
                Family.Together -> mirror()
                Family.Senses -> bellAndTablets()
                Family.Life -> pouring()
            }
        }
    }
}

private fun DrawScope.box(c: Color, r: Rect) = drawRect(c, r.topLeft, r.size)

private fun DrawScope.shadow(cx: Float, w: Float, y: Float = 80f) = drawOval(Shade, Offset(cx - w / 2, y - 2.5f), Size(w, 5f))

/** A low willow basket of three real objects — the first naming work. */
private fun DrawScope.basket() {
    shadow(80f, 76f, 82f)
    // objects behind the rim
    drawCircle(Red, 9f, Offset(66f, 50f))
    drawArc(Color.White.copy(alpha = 0.25f), 200f, 70f, false, Offset(60f, 44f), Size(12f, 12f), style = Stroke(1.6f, cap = StrokeCap.Round))
    drawRoundRect(Palette.Rod, Offset(78f, 38f), Size(12f, 20f), CornerRadius(3f))
    drawRoundRect(Palette.Rod.copy(alpha = 0.7f), Offset(76f, 36f), Size(16f, 4f), CornerRadius(2f))
    // a wooden spoon leaning out
    rotate(-28f, Offset(98f, 56f)) {
        drawRoundRect(Palette.Wood, Offset(96.5f, 26f), Size(3f, 30f), CornerRadius(1.5f))
        drawOval(Palette.Wood, Offset(93f, 18f), Size(10f, 13f))
    }
    // the basket
    val body = Path().apply { moveTo(46f, 52f); lineTo(114f, 52f); cubicTo(113f, 70f, 104f, 80f, 80f, 80f); cubicTo(56f, 80f, 47f, 70f, 46f, 52f); close() }
    drawPath(body, Willow)
    for (i in 0..4) drawLine(WoodDeep.copy(alpha = 0.35f), Offset(48f + i * 0.6f, 57f + i * 5f), Offset(112f - i * 0.6f, 57f + i * 5f), 1.1f)
    drawRoundRect(WoodDeep, Offset(43f, 49f), Size(74f, 6f), CornerRadius(3f))
}

/** A peg on a block with three rings: two on, one waiting on the mat. */
private fun DrawScope.pegAndRings() {
    shadow(72f, 60f); shadow(118f, 26f)
    drawRoundRect(WoodDeep, Offset(46f, 72f), Size(52f, 9f), CornerRadius(2f))
    drawRoundRect(Palette.Wood, Offset(46f, 70f), Size(52f, 8f), CornerRadius(2f))
    drawRoundRect(Palette.Wood, Offset(69f, 22f), Size(6f, 50f), CornerRadius(3f))
    fun ring(cy: Float, w: Float, c: Color) {
        drawRoundRect(c, Offset(72f - w / 2, cy - 5f), Size(w, 10f), CornerRadius(5f))
        drawLine(Color.White.copy(alpha = 0.22f), Offset(72f - w / 2 + 4f, cy - 2.6f), Offset(72f + w / 2 - 4f, cy - 2.6f), 1.2f, StrokeCap.Round)
    }
    ring(64f, 40f, Palette.Rod); ring(53f, 32f, Palette.Bead)
    // the third ring lies flat: an ellipse with its hole
    drawOval(Red, Offset(104f, 70f), Size(28f, 11f))
    drawOval(Linen, Offset(114f, 73.4f), Size(8f, 3.6f))
}

/** The box with a hole: the ball goes in on top and rolls out on the tray — it was there all along. */
private fun DrawScope.permanenceBox() {
    shadow(80f, 92f)
    box(WoodDeep, Rect(44f, 40f, 88f, 80f))
    box(Palette.Wood, Rect(44f, 36f, 88f, 42f))
    drawOval(Ink.copy(alpha = 0.75f), Offset(58f, 37f), Size(16f, 4f))
    // tray out of the front
    val tray = Path().apply { moveTo(88f, 70f); lineTo(126f, 72f); lineTo(126f, 80f); lineTo(88f, 80f); close() }
    drawPath(tray, Palette.Wood)
    drawLine(WoodDeep, Offset(124f, 66f), Offset(124f, 80f), 3f, StrokeCap.Round)
    box(Ink.copy(alpha = 0.7f), Rect(84f, 68f, 88f, 79f))
    drawCircle(Palette.Bead, 6f, Offset(114f, 66.5f))
    drawArc(Color.White.copy(alpha = 0.35f), 200f, 70f, false, Offset(110f, 62.5f), Size(8f, 8f), style = Stroke(1.4f, cap = StrokeCap.Round))
    // a second ball, waiting at the hole
    drawCircle(Palette.Bead, 6f, Offset(66f, 30f))
}

/** A round mirror in a wooden frame, set low — the first face to look at is your own. */
private fun DrawScope.mirror() {
    shadow(80f, 70f, 82f)
    drawRoundRect(WoodDeep, Offset(56f, 72f), Size(48f, 8f), CornerRadius(3f))
    drawCircle(Palette.Wood, 27f, Offset(80f, 46f))
    drawCircle(Glass, 22f, Offset(80f, 46f))
    drawLine(Color.White.copy(alpha = 0.55f), Offset(68f, 38f), Offset(78f, 30f), 2.2f, StrokeCap.Round)
    drawLine(Color.White.copy(alpha = 0.35f), Offset(70f, 46f), Offset(86f, 32f), 1.4f, StrokeCap.Round)
    // a small shape of a face in the glass — two dots, no more
    drawCircle(Ink.copy(alpha = 0.25f), 1.6f, Offset(84f, 50f)); drawCircle(Ink.copy(alpha = 0.25f), 1.6f, Offset(92f, 50f))
}

/** A brass bell and three colour tablets with wooden ends. */
private fun DrawScope.bellAndTablets() {
    shadow(58f, 34f); shadow(108f, 64f)
    val bell = Path().apply { moveTo(48f, 74f); cubicTo(48f, 60f, 50f, 46f, 58f, 44f); cubicTo(66f, 46f, 68f, 60f, 68f, 74f); close() }
    drawRoundRect(Palette.Wood, Offset(55f, 28f), Size(6f, 17f), CornerRadius(3f))
    drawPath(bell, Brass)
    drawRoundRect(Brass, Offset(44f, 72f), Size(28f, 5f), CornerRadius(2.5f))
    drawLine(Color.White.copy(alpha = 0.3f), Offset(53f, 52f), Offset(52f, 68f), 1.6f, StrokeCap.Round)
    listOf(Red, Palette.Rod, Palette.Bead).forEachIndexed { i, c ->
        val y = 52f + i * 9.5f; val x = 82f + i * 4f
        box(Palette.Wood, Rect(x, y, x + 4f, y + 7f)); box(c, Rect(x + 4f, y, x + 44f, y + 7f)); box(Palette.Wood, Rect(x + 44f, y, x + 48f, y + 7f))
    }
}

/** A small glass jug, a cup and a folded cloth: pouring, the first work of the hands at the table. */
private fun DrawScope.pouring() {
    shadow(66f, 40f); shadow(104f, 28f); shadow(130f, 22f, 81f)
    val jug = Path().apply { moveTo(54f, 78f); lineTo(52f, 44f); lineTo(48f, 38f); lineTo(80f, 38f); lineTo(78f, 44f); lineTo(76f, 78f); close() }
    drawPath(jug, Glass.copy(alpha = 0.8f))
    box(Water, Rect(53.4f, 56f, 76.6f, 78f))
    drawArc(Glass, -90f, 180f, false, Offset(72f, 46f), Size(14f, 22f), style = Stroke(3f))
    drawLine(Color.White.copy(alpha = 0.5f), Offset(57f, 46f), Offset(58f, 72f), 1.6f, StrokeCap.Round)
    drawRoundRect(Palette.Chalk, Offset(94f, 60f), Size(20f, 19f), CornerRadius(3f))
    drawRoundRect(Ink.copy(alpha = 0.08f), Offset(94f, 60f), Size(20f, 3f), CornerRadius(1.5f))
    drawRoundRect(Palette.Moss.copy(alpha = 0.85f), Offset(120f, 70f), Size(22f, 10f), CornerRadius(1.5f))
    drawLine(Palette.Chalk.copy(alpha = 0.5f), Offset(120f, 74.5f), Offset(142f, 74.5f), 0.8f)
}
