package app.mossling.ui.components

import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** The app's own small pictograms, drawn on a 24 × 24 grid with a 1.8 stroke: no stock icon set. */
enum class G { Today, Grow, Journal, You, Nurse, Bottle, Sleep, Diaper, Solid, Bath, Note, Play, Bead, Check, Plus, Close, Back, Clock, Sun, Moon, Thermo, Pill, Ruler, Search, Share, Chart, Download, Shield, Idea, Eye, Hand, Gear, Speech, Walk, Heart, Home, Scale, Head }

@Composable
fun Glyph(g: G, modifier: Modifier = Modifier, size: Dp = 24.dp, color: Color = LocalContentColor.current, filled: Boolean = false) {
    Canvas(modifier.size(size)) {
        val s = this.size.minDimension / 24f
        withTransform({ scale(s, s, Offset.Zero) }) { drawGlyph(g, color, filled) }
    }
}

private fun DrawScope.drawGlyph(g: G, c: Color, filled: Boolean) {
    val st = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)
    fun path(b: Path.() -> Unit) = Path().apply(b)
    when (g) {
        G.Today -> { // a sun that is also an eye
            drawCircle(c, 5.2f, Offset(12f, 12f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st)
            if (filled) drawCircle(Color.White.copy(alpha = 0.9f), 1.8f, Offset(13f, 11.4f))
            for (i in 0 until 8) {
                val a = Math.toRadians(i * 45.0); val x = Math.cos(a).toFloat(); val y = Math.sin(a).toFloat()
                drawLine(c, Offset(12 + x * 8.3f, 12 + y * 8.3f), Offset(12 + x * 10.2f, 12 + y * 10.2f), 1.8f, StrokeCap.Round)
            }
        }
        G.Grow -> { // a short bead chain
            drawLine(c, Offset(2.5f, 15f), Offset(21.5f, 9f), 1.4f, StrokeCap.Round)
            listOf(Offset(5.5f, 14f), Offset(12f, 12f), Offset(18.5f, 10f)).forEachIndexed { i, o ->
                if (filled || i == 1) drawCircle(c, if (i == 1) 3.6f else 2.8f, o) else drawCircle(c, 2.8f, o, style = st)
            }
        }
        G.Journal -> {
            drawRoundRect(c, Offset(5f, 3.5f), Size(14f, 17f), CornerRadius(2.6f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st)
            val lc = if (filled) Color.White.copy(alpha = 0.85f) else c
            drawLine(lc, Offset(8.5f, 9f), Offset(15.5f, 9f), 1.6f, StrokeCap.Round); drawLine(lc, Offset(8.5f, 13f), Offset(13.5f, 13f), 1.6f, StrokeCap.Round)
        }
        G.You -> { // a pebble with two eyes: the companion
            val p = path { moveTo(4f, 17.5f); cubicTo(3f, 11f, 7f, 6f, 12.5f, 6f); cubicTo(18f, 6f, 21.5f, 10.5f, 20.5f, 16f); cubicTo(20f, 19.5f, 16f, 20.5f, 12f, 20.5f); cubicTo(7.5f, 20.5f, 4.5f, 20f, 4f, 17.5f); close() }
            if (filled) drawPath(p, c) else drawPath(p, c, style = st)
            val e = if (filled) Color.White else c
            drawCircle(e, 1.4f, Offset(10.2f, 12.8f)); drawCircle(e, 1.4f, Offset(14.6f, 12.8f))
        }
        G.Nurse -> { val p = path { moveTo(12f, 3.5f); cubicTo(16.5f, 9f, 18.5f, 12.5f, 18.5f, 15f); cubicTo(18.5f, 18.6f, 15.6f, 21f, 12f, 21f); cubicTo(8.4f, 21f, 5.5f, 18.6f, 5.5f, 15f); cubicTo(5.5f, 12.5f, 7.5f, 9f, 12f, 3.5f); close() }; if (filled) drawPath(p, c) else drawPath(p, c, style = st) }
        G.Bottle -> {
            drawRoundRect(c, Offset(7.5f, 8f), Size(9f, 13f), CornerRadius(3f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st)
            drawLine(c, Offset(9.5f, 8f), Offset(10.5f, 5f), 1.8f, StrokeCap.Round); drawLine(c, Offset(14.5f, 8f), Offset(13.5f, 5f), 1.8f, StrokeCap.Round); drawLine(c, Offset(10.5f, 5f), Offset(13.5f, 5f), 1.8f, StrokeCap.Round)
            drawLine(c, Offset(12f, 5f), Offset(12f, 2.8f), 1.8f, StrokeCap.Round)
        }
        G.Sleep, G.Moon -> { val p = path { moveTo(15.5f, 4f); cubicTo(10f, 4.5f, 6f, 8.5f, 6f, 13.5f); cubicTo(6f, 18f, 9.8f, 21f, 14f, 21f); cubicTo(16.6f, 21f, 18.6f, 20f, 20f, 18.4f); cubicTo(14.6f, 18.4f, 11.5f, 14.4f, 11.5f, 10.4f); cubicTo(11.5f, 7.8f, 13.2f, 5.2f, 15.5f, 4f); close() }; if (filled) drawPath(p, c) else drawPath(p, c, style = st) }
        G.Diaper -> { val p = path { moveTo(3.5f, 7f); lineTo(20.5f, 7f); lineTo(20.5f, 10f); cubicTo(17f, 11f, 15f, 14f, 14.5f, 18f); lineTo(9.5f, 18f); cubicTo(9f, 14f, 7f, 11f, 3.5f, 10f); close() }; if (filled) drawPath(p, c) else drawPath(p, c, style = st) }
        G.Solid -> { drawOval(c, Offset(8f, 3f), Size(8f, 9.5f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st); drawLine(c, Offset(12f, 12.5f), Offset(12f, 21f), 1.9f, StrokeCap.Round) }
        G.Bath -> { drawLine(c, Offset(3f, 12f), Offset(21f, 12f), 1.8f, StrokeCap.Round); drawPath(path { moveTo(4.5f, 12f); lineTo(5.5f, 17f); cubicTo(6f, 19f, 7.5f, 20f, 9.5f, 20f); lineTo(14.5f, 20f); cubicTo(16.5f, 20f, 18f, 19f, 18.5f, 17f); lineTo(19.5f, 12f) }, c, style = st); drawCircle(c, 1.3f, Offset(9f, 7f)); drawCircle(c, 1.8f, Offset(13.5f, 5.5f), style = Stroke(1.4f)) }
        G.Note -> { drawPath(path { moveTo(5f, 19f); lineTo(5.6f, 15.4f); lineTo(15.8f, 5.2f); cubicTo(16.6f, 4.4f, 17.9f, 4.4f, 18.7f, 5.2f); cubicTo(19.5f, 6f, 19.5f, 7.3f, 18.7f, 8.1f); lineTo(8.5f, 18.3f); close() }, c, style = st) }
        G.Play -> { drawCircle(c, 8.5f, Offset(12f, 12f), style = st); drawPath(path { moveTo(10f, 8.5f); lineTo(16f, 12f); lineTo(10f, 15.5f); close() }, c) }
        G.Bead -> { drawCircle(c, 7f, Offset(12f, 12f)); drawCircle(Color.White.copy(alpha = 0.55f), 2.2f, Offset(9.8f, 9.6f)) }
        G.Check -> drawPath(path { moveTo(5f, 12.5f); lineTo(10f, 17.5f); lineTo(19f, 7f) }, c, style = Stroke(2.2f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        G.Plus -> { drawLine(c, Offset(12f, 5f), Offset(12f, 19f), 2f, StrokeCap.Round); drawLine(c, Offset(5f, 12f), Offset(19f, 12f), 2f, StrokeCap.Round) }
        G.Close -> { drawLine(c, Offset(6f, 6f), Offset(18f, 18f), 2f, StrokeCap.Round); drawLine(c, Offset(18f, 6f), Offset(6f, 18f), 2f, StrokeCap.Round) }
        G.Back -> drawPath(path { moveTo(15f, 5f); lineTo(8f, 12f); lineTo(15f, 19f) }, c, style = Stroke(2f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        G.Clock -> { drawCircle(c, 8.5f, Offset(12f, 12f), style = st); drawPath(path { moveTo(12f, 7.5f); lineTo(12f, 12f); lineTo(15f, 14f) }, c, style = st) }
        G.Thermo -> { drawRoundRect(c, Offset(10f, 3f), Size(4f, 12.5f), CornerRadius(2f), style = st); drawCircle(c, 3.6f, Offset(12f, 17.6f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st); drawLine(c, Offset(12f, 9f), Offset(12f, 16f), 1.8f, StrokeCap.Round) }
        G.Pill -> { withTransform({ rotate(-40f, Offset(12f, 12f)) }) { drawRoundRect(c, Offset(4.5f, 8.5f), Size(15f, 7f), CornerRadius(3.5f), style = st); drawLine(c, Offset(12f, 8.5f), Offset(12f, 15.5f), 1.8f) } }
        G.Scale -> { // a baby scale: the cradle tray on a base with its dial
            drawPath(path { moveTo(3.5f, 8f); cubicTo(5f, 12f, 8f, 13.5f, 12f, 13.5f); cubicTo(16f, 13.5f, 19f, 12f, 20.5f, 8f); close() }, c, style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st)
            drawLine(c, Offset(12f, 13.5f), Offset(12f, 15.5f), 1.8f, StrokeCap.Round)
            drawRoundRect(c, Offset(5f, 15.5f), Size(14f, 5f), CornerRadius(2f), style = st)
            drawCircle(c, 1.1f, Offset(12f, 18f))
        }
        G.Head -> { // a round head with the measuring tape across the brow
            drawCircle(c, 8f, Offset(12f, 12.5f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st)
            drawPath(path { moveTo(3.6f, 11f); cubicTo(8f, 13.4f, 16f, 13.4f, 20.4f, 11f) }, if (filled) Color.White.copy(alpha = 0.9f) else c, style = Stroke(2.4f, cap = StrokeCap.Round))
            listOf(8f, 12f, 16f).forEach { x -> drawLine(if (filled) Color.White.copy(alpha = 0.9f) else c, Offset(x, 12.6f), Offset(x, 14.6f), 1.2f, StrokeCap.Round) }
        }
        G.Ruler -> { drawRoundRect(c, Offset(3f, 8f), Size(18f, 8f), CornerRadius(1.5f), style = st); for (i in 0..4) drawLine(c, Offset(6f + i * 3f, 8f), Offset(6f + i * 3f, if (i % 2 == 0) 12.5f else 11f), 1.5f, StrokeCap.Round) }
        G.Search -> { drawCircle(c, 6f, Offset(10.5f, 10.5f), style = st); drawLine(c, Offset(15f, 15f), Offset(20f, 20f), 2f, StrokeCap.Round) }
        G.Share -> { drawPath(path { moveTo(12f, 4f); lineTo(12f, 15f) }, c, style = st); drawPath(path { moveTo(8f, 8f); lineTo(12f, 4f); lineTo(16f, 8f) }, c, style = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)); drawPath(path { moveTo(6f, 12f); lineTo(6f, 19f); lineTo(18f, 19f); lineTo(18f, 12f) }, c, style = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)) }
        G.Chart -> { listOf(6f to 13f, 11f to 8f, 16f to 11f).forEach { (x, y) -> drawRoundRect(c, Offset(x - 1.6f, y), Size(3.2f, 19f - y), CornerRadius(1.2f)) }; drawLine(c, Offset(3.5f, 20f), Offset(20.5f, 20f), 1.6f, StrokeCap.Round) }
        G.Download -> { drawPath(path { moveTo(12f, 4f); lineTo(12f, 15f) }, c, style = st); drawPath(path { moveTo(8f, 11f); lineTo(12f, 15f); lineTo(16f, 11f) }, c, style = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)); drawLine(c, Offset(5f, 19.5f), Offset(19f, 19.5f), 1.8f, StrokeCap.Round) }
        G.Shield -> { val p = path { moveTo(12f, 3f); lineTo(19.5f, 6f); lineTo(19.5f, 11.5f); cubicTo(19.5f, 16f, 16.4f, 19.4f, 12f, 21f); cubicTo(7.6f, 19.4f, 4.5f, 16f, 4.5f, 11.5f); lineTo(4.5f, 6f); close() }; if (filled) drawPath(p, c) else drawPath(p, c, style = st); drawPath(path { moveTo(8.8f, 12f); lineTo(11.2f, 14.4f); lineTo(15.4f, 9.6f) }, c, style = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)) }
        G.Idea -> { drawPath(path { moveTo(9f, 17f); cubicTo(9f, 14.5f, 6f, 13f, 6f, 9.5f); cubicTo(6f, 6.2f, 8.7f, 3.5f, 12f, 3.5f); cubicTo(15.3f, 3.5f, 18f, 6.2f, 18f, 9.5f); cubicTo(18f, 13f, 15f, 14.5f, 15f, 17f); close() }, c, style = st); drawLine(c, Offset(9.5f, 20.5f), Offset(14.5f, 20.5f), 1.8f, StrokeCap.Round) }
        G.Eye -> { drawPath(path { moveTo(2.5f, 12f); cubicTo(5.5f, 6.5f, 18.5f, 6.5f, 21.5f, 12f); cubicTo(18.5f, 17.5f, 5.5f, 17.5f, 2.5f, 12f); close() }, c, style = st); drawCircle(c, 3.2f, Offset(12f, 12f)) }
        G.Hand -> { drawPath(path { moveTo(7f, 13f); lineTo(7f, 7f); moveTo(10f, 12f); lineTo(10f, 4.5f); moveTo(13f, 12f); lineTo(13f, 5f); moveTo(16f, 12.5f); lineTo(16f, 7f) }, c, style = st); drawPath(path { moveTo(7f, 12f); cubicTo(5f, 11f, 3.6f, 12.5f, 5f, 14.5f); lineTo(8.5f, 19f); cubicTo(9.6f, 20.4f, 11f, 21f, 12.6f, 21f); cubicTo(15f, 21f, 16f, 19f, 16f, 17f); lineTo(16f, 12f) }, c, style = st) }
        G.Gear -> { drawCircle(c, 3f, Offset(12f, 12f), style = st); for (i in 0 until 8) { val a = Math.toRadians(i * 45.0); drawLine(c, Offset(12 + Math.cos(a).toFloat() * 6f, 12 + Math.sin(a).toFloat() * 6f), Offset(12 + Math.cos(a).toFloat() * 8.6f, 12 + Math.sin(a).toFloat() * 8.6f), 2.6f, StrokeCap.Round) }; drawCircle(c, 6.2f, Offset(12f, 12f), style = Stroke(1.6f)) }
        G.Speech -> { drawPath(path { moveTo(4f, 6.5f); cubicTo(4f, 5.1f, 5.1f, 4f, 6.5f, 4f); lineTo(17.5f, 4f); cubicTo(18.9f, 4f, 20f, 5.1f, 20f, 6.5f); lineTo(20f, 13.5f); cubicTo(20f, 14.9f, 18.9f, 16f, 17.5f, 16f); lineTo(10f, 16f); lineTo(6f, 20f); lineTo(6f, 16f); cubicTo(4.9f, 16f, 4f, 14.9f, 4f, 13.5f); close() }, c, style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st) }
        G.Walk -> { drawCircle(c, 2.2f, Offset(13f, 4.5f)); drawPath(path { moveTo(13f, 8f); lineTo(11f, 14f); lineTo(14f, 20f); moveTo(11f, 14f); lineTo(8f, 20f); moveTo(8f, 11f); lineTo(12.5f, 9f); lineTo(16f, 12f) }, c, style = Stroke(1.9f, cap = StrokeCap.Round, join = StrokeJoin.Round)) }
        G.Heart -> { val p = path { moveTo(12f, 20f); cubicTo(5f, 15f, 3f, 11.5f, 3f, 8.5f); cubicTo(3f, 5.9f, 5f, 4f, 7.5f, 4f); cubicTo(9.4f, 4f, 11f, 5.1f, 12f, 6.8f); cubicTo(13f, 5.1f, 14.6f, 4f, 16.5f, 4f); cubicTo(19f, 4f, 21f, 5.9f, 21f, 8.5f); cubicTo(21f, 11.5f, 19f, 15f, 12f, 20f); close() }; if (filled) drawPath(p, c) else drawPath(p, c, style = st) }
        G.Home -> { drawPath(path { moveTo(4f, 11f); lineTo(12f, 4f); lineTo(20f, 11f); moveTo(6f, 9.5f); lineTo(6f, 20f); lineTo(18f, 20f); lineTo(18f, 9.5f) }, c, style = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)); drawRoundRect(c, Offset(10f, 14f), Size(4f, 6f), CornerRadius(1f), style = st) }
        G.Sun -> { drawCircle(c, 4.5f, Offset(12f, 12f)); for (i in 0 until 8) { val a = Math.toRadians(i * 45.0); drawLine(c, Offset(12 + Math.cos(a).toFloat() * 7.5f, 12 + Math.sin(a).toFloat() * 7.5f), Offset(12 + Math.cos(a).toFloat() * 9.6f, 12 + Math.sin(a).toFloat() * 9.6f), 1.8f, StrokeCap.Round) } }
    }
}
