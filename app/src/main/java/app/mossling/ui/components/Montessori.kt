package app.mossling.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.ImageShader
import androidx.compose.ui.graphics.ShaderBrush
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.mossling.ui.theme.Palette
import kotlin.random.Random

/*
 * The Montessori classroom, as the app's visual vocabulary:
 *  - sandpaper numerals on green boards (the child's age),
 *  - the work tray with its handles (today's play),
 *  - number rods in alternating red and blue (how much of a kind is recorded),
 *  - colour tablets with natural wood ends (the six areas),
 *  - the low open shelf (the month's plays), and the golden bead chain (months).
 */

private val SandLight = Color(0xFFE9DCC0)
private val SandDark = Color(0xFFB9A57E)
val RodRed = Color(0xFFC0392B)
val RodBlue = Color(0xFF2D4A8C)
val Wood = Color(0xFFC99B63)
val WoodDeep = Color(0xFF9C7444)
val WoodLight = Color(0xFFE2C394)
val TowerPink = Color(0xFFE6A7A4)

/** A small tile of sand grain, built once; used as the fill of sandpaper numerals. */
private object Sand {
    val tile: ImageBitmap by lazy {
        val n = 48; val px = IntArray(n * n); val r = Random(7)
        for (i in px.indices) {
            val t = r.nextFloat()
            val c = if (t < 0.18f) SandDark else if (t < 0.24f) Color(0xFFF5EEDC) else SandLight
            px[i] = android.graphics.Color.argb(255, (c.red * 255).toInt(), (c.green * 255).toInt(), (c.blue * 255).toInt())
        }
        android.graphics.Bitmap.createBitmap(px, n, n, android.graphics.Bitmap.Config.ARGB_8888).asImageBitmap()
    }
    val brush: Brush by lazy { ShaderBrush(ImageShader(tile, TileMode.Repeated, TileMode.Repeated)) }
}

/** A number in sandpaper, on its green board — the way children first trace numerals. */
@Composable
fun SandpaperNumber(text: String, style: TextStyle, modifier: Modifier = Modifier, board: Color = Palette.MossDeep) {
    Box(
        modifier.drawBehind {
            drawRoundRect(board, cornerRadius = CornerRadius(14.dp.toPx()))
            drawRoundRect(Color.Black.copy(alpha = 0.10f), topLeft = Offset(0f, size.height - 4.dp.toPx()), size = Size(size.width, 4.dp.toPx()), cornerRadius = CornerRadius(14.dp.toPx()))
        }.padding(horizontal = 14.dp, vertical = 4.dp),
    ) {
        Text(text, style = style.copy(brush = Sand.brush))
    }
}

/** A wooden work tray: a rim of natural wood, two cut-out handles, the work laid on the felt inside. */
@Composable
fun WorkTray(modifier: Modifier = Modifier, felt: Color = MaterialTheme.colorScheme.surfaceContainerLowest, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.drawBehind {
            val r = 30.dp.toPx(); val rim = 10.dp.toPx()
            drawRoundRect(WoodDeep, topLeft = Offset(0f, 3.dp.toPx()), size = size, cornerRadius = CornerRadius(r))
            drawRoundRect(Wood, size = Size(size.width, size.height - 2.dp.toPx()), cornerRadius = CornerRadius(r))
            // grain: two faint lines along the rim
            drawLine(WoodLight.copy(alpha = 0.7f), Offset(r, rim * 0.45f), Offset(size.width - r, rim * 0.45f), 1.2.dp.toPx())
            drawLine(WoodLight.copy(alpha = 0.5f), Offset(r, size.height - rim * 0.7f), Offset(size.width - r, size.height - rim * 0.7f), 1.dp.toPx())
            // handles
            val hw = 46.dp.toPx(); val hh = 6.dp.toPx()
            drawRoundRect(WoodDeep, topLeft = Offset(size.width / 2 - hw / 2, rim * 0.3f), size = Size(hw, hh * 0.6f), cornerRadius = CornerRadius(hh))
            drawRoundRect(felt, topLeft = Offset(rim, rim), size = Size(size.width - rim * 2, size.height - rim * 2 - 2.dp.toPx()), cornerRadius = CornerRadius(r - rim * 0.6f))
        }.padding(start = 10.dp, end = 10.dp, top = 10.dp, bottom = 12.dp).padding(18.dp),
        content = content,
    )
}

/** A number rod: [total] segments alternating red and blue; the first [n] are filled. */
@Composable
fun NumberRod(n: Int, total: Int, modifier: Modifier = Modifier, height: Dp = 12.dp) {
    val track = MaterialTheme.colorScheme.outlineVariant
    Canvas(modifier.fillMaxWidth().height(height)) {
        val k = total.coerceIn(1, 10)
        val filled = if (total <= 0) 0 else ((n.toFloat() / total) * k + 0.001f).toInt().coerceIn(0, k)
        val w = size.width / k
        for (i in 0 until k) {
            val c = if (i % 2 == 0) RodRed else RodBlue
            val tl = Offset(w * i, 0f); val s = Size(w, size.height)
            if (i < filled) drawRect(c, tl, s) else drawRect(track, tl + Offset(0.5f, 0.5f), Size(w - 1f, size.height - 1f), style = Stroke(1.dp.toPx()))
        }
        drawRoundRect(Color.Black.copy(alpha = 0.06f), Offset(0f, size.height * 0.62f), Size(w * filled, size.height * 0.38f), CornerRadius(0f))
    }
}

/** A colour tablet: a strip of colour between two ends of natural wood. */
@Composable
fun ColorTablet(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier.size(width = 28.dp, height = 16.dp)) {
        val e = size.width * 0.22f; val cr = CornerRadius(3.dp.toPx())
        drawRoundRect(Wood, size = size, cornerRadius = cr)
        drawRect(color, Offset(e, 0f), Size(size.width - e * 2, size.height))
    }
}

/** The low open shelf the month's plays stand on. */
@Composable
fun Shelf(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(modifier.drawBehind {
        val plank = 12.dp.toPx(); val y = size.height - plank
        drawRect(Color.Black.copy(alpha = 0.07f), Offset(0f, y + plank), Size(size.width, 4.dp.toPx()))
        drawRect(WoodDeep, Offset(0f, y + plank * 0.55f), Size(size.width, plank * 0.45f))
        drawRect(Wood, Offset(0f, y), Size(size.width, plank * 0.6f))
        drawLine(WoodLight, Offset(0f, y + 1.dp.toPx()), Offset(size.width, y + 1.dp.toPx()), 1.dp.toPx())
    }.padding(bottom = 12.dp), content = content)
}

/** The pink tower: ten cubes, largest at the bottom; [n] of [total] built. */
@Composable
fun PinkTower(n: Int, total: Int, modifier: Modifier = Modifier) {
    val ghost = MaterialTheme.colorScheme.outlineVariant
    Canvas(modifier.size(64.dp, 72.dp)) {
        val k = 10; val built = if (total <= 0) 0 else ((n.toFloat() / total) * k).toInt().coerceIn(0, k)
        var y = size.height
        for (i in 0 until k) {
            val s = size.width * (1f - i * 0.085f); val h = size.height / 12f
            y -= h
            val tl = Offset((size.width - s) / 2, y)
            if (i < built) { drawRect(TowerPink, tl, Size(s, h)); drawRect(Color.Black.copy(alpha = 0.08f), Offset(tl.x, tl.y + h * 0.7f), Size(s, h * 0.3f)) }
            else drawRect(ghost, tl, Size(s, h), style = Stroke(1.dp.toPx()))
        }
    }
}
