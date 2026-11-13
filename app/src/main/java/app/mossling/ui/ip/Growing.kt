package app.mossling.ui.ip

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mossling.ui.components.ArtIndex
import app.mossling.ui.components.LocalArtStyle
import app.mossling.ui.theme.Palette

private val Skin = Color(0xFFF3DFC8)
private val Cheek = Color(0xFFE7B69B)
private val Cloth = Color(0xFFD7E3C9)
private val Blanket = Color(0xFFEAE6DC)

fun childStage(m: Int): Int = when {
    m < 3 -> 0
    m < 6 -> 1
    m < 9 -> 2
    m < 12 -> 3
    m < 18 -> 4
    m < 24 -> 5
    else -> 6
}

/**
 * The child at each stage of the first three years — swaddled (0–2m), on the belly lifting the head (3–5m),
 * sitting with a ring (6–8m), crawling (9–11m), first steps (12–17m), stacking (18–23m), and running with
 * a book (24–36m). Uses the 3D/2D `child_0..6.webp` illustration when available, with vector fallback.
 */
@Composable
fun GrowingChild(month: Int, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val style = LocalArtStyle.current
    val st = childStage(month)
    val file = remember(st, style) { style.resolve("child_$st.webp") }
    val fallback = remember(st) { "child_$st.webp" }
    val bmp by produceState(
        initialValue = remember(file, fallback) {
            ArtIndex.bitmapSync(ctx, file, 512) ?: ArtIndex.bitmapSync(ctx, fallback, 512)
        },
        file,
        fallback,
    ) {
        if (value == null) {
            value = ArtIndex.bitmap(ctx, file, 512) ?: ArtIndex.bitmap(ctx, fallback, 512)
        }
    }

    Box(modifier.aspectRatio(1f), contentAlignment = Alignment.Center) {
        val current = bmp
        if (current != null) {
            Image(
                bitmap = current,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit,
                filterQuality = FilterQuality.High,
            )
        } else {
            Canvas(Modifier.fillMaxSize()) {
                val u = size.minDimension
                translate((size.width - u) / 2, (size.height - u) / 2) {
                    drawOval(Color.Black.copy(alpha = 0.07f), Offset(u * 0.16f, u * 0.84f), Size(u * 0.68f, u * 0.08f))
                    when (st) {
                        0 -> swaddled(u)
                        1 -> tummy(u)
                        2 -> sitting(u)
                        3 -> crawling(u)
                        4 -> standing(u)
                        5 -> building(u)
                        else -> running(u)
                    }
                }
            }
        }
    }
}

/**
 * "故事仍在继续" footer scene shown at the bottom of the Growth Map and Growth Book (`ios/Mossling/IP/Hug.swift`).
 */
@Composable
fun StoryGoesOn(month: Int, companion: Kind, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 28.dp, horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy((-8).dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            Creature(Kind.Moss, Modifier.size(56.dp), mood = Mood.Happy, look = Offset(0.6f, 0f), interactive = false)
            GrowingChild(month = month, modifier = Modifier.size(68.dp))
            Creature(Kind.Otto, Modifier.size(64.dp), mood = Mood.Calm, look = Offset(-0.6f, 0f), interactive = false)
        }
        Text("故事仍在继续", style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Text(
            "每一个月都有自己的节奏，不用赶，也不用比。",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

private fun DrawScope.head(c: Offset, r: Float, awake: Boolean = true) {
    drawCircle(Skin, r, c)
    drawCircle(Cheek.copy(alpha = 0.55f), r * 0.20f, c + Offset(-r * 0.45f, r * 0.18f))
    drawCircle(Cheek.copy(alpha = 0.55f), r * 0.20f, c + Offset(r * 0.45f, r * 0.18f))
    val curl = Path().apply {
        moveTo(c.x - r * 0.1f, c.y - r * 0.92f)
        quadraticTo(c.x + r * 0.18f, c.y - r * 1.22f, c.x + r * 0.28f, c.y - r * 0.88f)
    }
    drawPath(curl, Palette.Ink, style = Stroke(r * 0.14f, cap = StrokeCap.Round))
    if (awake) {
        drawCircle(Palette.Ink, r * 0.10f, c + Offset(-r * 0.30f, -r * 0.02f))
        drawCircle(Palette.Ink, r * 0.10f, c + Offset(r * 0.30f, -r * 0.02f))
    } else {
        val st = Stroke(r * 0.10f, cap = StrokeCap.Round)
        drawLine(Palette.Ink, c + Offset(-r * 0.42f, 0f), c + Offset(-r * 0.18f, 0f), r * 0.10f, StrokeCap.Round)
        drawLine(Palette.Ink, c + Offset(r * 0.18f, 0f), c + Offset(r * 0.42f, 0f), r * 0.10f, StrokeCap.Round)
        st.width
    }
}

private fun DrawScope.swaddled(u: Float) {
    drawRoundRect(Blanket, Offset(u * 0.20f, u * 0.50f), Size(u * 0.60f, u * 0.34f), CornerRadius(u * 0.17f))
    drawRoundRect(Cloth, Offset(u * 0.30f, u * 0.52f), Size(u * 0.48f, u * 0.30f), CornerRadius(u * 0.15f))
    head(Offset(u * 0.32f, u * 0.58f), u * 0.15f, awake = false)
}

private fun DrawScope.tummy(u: Float) {
    drawRoundRect(Cloth, Offset(u * 0.22f, u * 0.60f), Size(u * 0.44f, u * 0.22f), CornerRadius(u * 0.11f))
    drawLine(Skin, Offset(u * 0.60f, u * 0.68f), Offset(u * 0.64f, u * 0.84f), u * 0.07f, StrokeCap.Round)
    head(Offset(u * 0.66f, u * 0.46f), u * 0.16f)
    drawCircle(Palette.Bead, u * 0.055f, Offset(u * 0.84f, u * 0.78f))
}

private fun DrawScope.sitting(u: Float) {
    drawRoundRect(Cloth, Offset(u * 0.34f, u * 0.48f), Size(u * 0.32f, u * 0.34f), CornerRadius(u * 0.14f))
    drawRoundRect(Skin, Offset(u * 0.26f, u * 0.74f), Size(u * 0.48f, u * 0.10f), CornerRadius(u * 0.05f))
    head(Offset(u * 0.50f, u * 0.34f), u * 0.16f)
    drawCircle(Palette.Wood, u * 0.075f, Offset(u * 0.50f, u * 0.64f), style = Stroke(u * 0.032f))
}

private fun DrawScope.crawling(u: Float) {
    drawRoundRect(Cloth, Offset(u * 0.28f, u * 0.52f), Size(u * 0.38f, u * 0.20f), CornerRadius(u * 0.10f))
    drawLine(Skin, Offset(u * 0.34f, u * 0.68f), Offset(u * 0.30f, u * 0.84f), u * 0.07f, StrokeCap.Round)
    drawLine(Skin, Offset(u * 0.60f, u * 0.68f), Offset(u * 0.64f, u * 0.84f), u * 0.07f, StrokeCap.Round)
    head(Offset(u * 0.70f, u * 0.46f), u * 0.15f)
}

private fun DrawScope.standing(u: Float) {
    drawLine(Skin, Offset(u * 0.44f, u * 0.66f), Offset(u * 0.42f, u * 0.85f), u * 0.07f, StrokeCap.Round)
    drawLine(Skin, Offset(u * 0.56f, u * 0.66f), Offset(u * 0.58f, u * 0.85f), u * 0.07f, StrokeCap.Round)
    drawRoundRect(Cloth, Offset(u * 0.36f, u * 0.42f), Size(u * 0.28f, u * 0.28f), CornerRadius(u * 0.12f))
    drawLine(Skin, Offset(u * 0.36f, u * 0.48f), Offset(u * 0.22f, u * 0.42f), u * 0.06f, StrokeCap.Round)
    drawLine(Skin, Offset(u * 0.64f, u * 0.48f), Offset(u * 0.78f, u * 0.42f), u * 0.06f, StrokeCap.Round)
    head(Offset(u * 0.50f, u * 0.28f), u * 0.15f)
}

private fun DrawScope.building(u: Float) {
    standing(u)
    drawRoundRect(Palette.Rod, Offset(u * 0.74f, u * 0.74f), Size(u * 0.12f, u * 0.12f), CornerRadius(u * 0.02f))
    drawRoundRect(Palette.Bead, Offset(u * 0.755f, u * 0.64f), Size(u * 0.09f, u * 0.10f), CornerRadius(u * 0.02f))
}

private fun DrawScope.running(u: Float) {
    drawLine(Skin, Offset(u * 0.44f, u * 0.66f), Offset(u * 0.34f, u * 0.85f), u * 0.07f, StrokeCap.Round)
    drawLine(Skin, Offset(u * 0.56f, u * 0.66f), Offset(u * 0.66f, u * 0.82f), u * 0.07f, StrokeCap.Round)
    drawRoundRect(Cloth, Offset(u * 0.36f, u * 0.40f), Size(u * 0.28f, u * 0.28f), CornerRadius(u * 0.12f))
    head(Offset(u * 0.52f, u * 0.26f), u * 0.145f)
    drawRoundRect(Palette.RedRod, Offset(u * 0.64f, u * 0.46f), Size(u * 0.14f, u * 0.16f), CornerRadius(u * 0.02f))
}
