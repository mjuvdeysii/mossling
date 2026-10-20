package app.mossling.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asComposePath
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.graphics.shapes.CornerRounding
import androidx.graphics.shapes.Morph
import androidx.graphics.shapes.RoundedPolygon
import androidx.graphics.shapes.star
import androidx.graphics.shapes.toPath

/**
 * The expressive shape set the app speaks with (after Material 3 Expressive): soft, countable shapes — like the
 * Montessori geometric solids and the sandpaper shapes a child traces — used for badges, numerals and pressed states.
 */
object Shapes {
    val Cookie: RoundedPolygon = RoundedPolygon.star(9, innerRadius = 0.82f, rounding = CornerRounding(0.35f), innerRounding = CornerRounding(0.35f))
    val Clover: RoundedPolygon = RoundedPolygon.star(4, innerRadius = 0.62f, rounding = CornerRounding(0.42f), innerRounding = CornerRounding(0.30f))
    val Flower: RoundedPolygon = RoundedPolygon.star(6, innerRadius = 0.74f, rounding = CornerRounding(0.36f), innerRounding = CornerRounding(0.24f))
    val Burst: RoundedPolygon = RoundedPolygon.star(12, innerRadius = 0.84f, rounding = CornerRounding(0.16f), innerRounding = CornerRounding(0.16f))
    val Gem: RoundedPolygon = RoundedPolygon(6, rounding = CornerRounding(0.28f))
    val Square: RoundedPolygon = RoundedPolygon(4, rounding = CornerRounding(0.36f))
    val Circle: RoundedPolygon = RoundedPolygon.star(16, innerRadius = 0.999f, rounding = CornerRounding(0.5f))
    val all = listOf(Cookie, Clover, Flower, Burst, Gem, Square)
    /** the same text always gets the same shape */
    fun of(key: String): RoundedPolygon = all[(key.hashCode() and 0x7fffffff) % all.size]
}

private fun RoundedPolygon.fitted(size: Size): Path {
    val p = toPath().asComposePath()
    val b = calculateBounds(); val w = b[2] - b[0]; val h = b[3] - b[1]
    p.transform(Matrix().apply { scale(size.width / w, size.height / h); translate(-b[0], -b[1]) })
    return p
}

class PolygonShape(private val polygon: RoundedPolygon) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density) = Outline.Generic(polygon.fitted(size))
}

/** A pictogram sitting in an expressive shape — the app's standard way to give a section, a row or a state a picture. */
@Composable
fun ShapeBadge(g: G, container: Color, content: Color, modifier: Modifier = Modifier, shape: RoundedPolygon = Shapes.Cookie, size: Dp = 40.dp, filled: Boolean = false) {
    Box(modifier.size(size).drawBehind { drawPath(shape.fitted(this.size), container) }, contentAlignment = Alignment.Center) {
        Glyph(g, size = size * 0.52f, color = content, filled = filled)
    }
}

/** A shape that springs from one form to another when [on] changes (selection, done, pressed). */
@Composable
fun MorphBlob(on: Boolean, from: RoundedPolygon, to: RoundedPolygon, color: Color, modifier: Modifier = Modifier) {
    val morph = remember(from, to) { Morph(from, to) }
    val t by animateFloatAsState(if (on) 1f else 0f, spring(dampingRatio = 0.55f, stiffness = 380f), label = "morph")
    Box(modifier.drawBehind {
        val p = morph.toPath(t).asComposePath()
        val s = this.size
        p.transform(Matrix().apply { scale(s.width / 2f, s.height / 2f); translate(1f, 1f) })
        drawPath(p, color)
    })
}
