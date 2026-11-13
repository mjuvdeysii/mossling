package app.mossling.ui.ip

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.mossling.ui.components.Sticker
import app.mossling.ui.components.reducedMotion
import app.mossling.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * The 4-second wordless opening scene (`docs/IP.md` §5, `ios/Mossling/IP/LampScene.swift`):
 *
 * Evening table; Otto's golden bead lamp lights up with a warm pool of light;
 * Moss wakes up, blinks twice, nudges the wooden ring stacker (the top ring wobbles),
 * turns delighted to Otto, and Otto answers with a slow blink.
 */
@Composable
fun LampScene(
    modifier: Modifier = Modifier,
    focus: Kind? = null,
    selecting: Boolean = false,
    onSelect: ((Kind) -> Unit)? = null,
) {
    val still = reducedMotion()
    var step by remember { mutableIntStateOf(if (still) 4 else 0) }
    var lampTarget by remember { mutableFloatStateOf(if (still) 1f else 0f) }
    var mossXTarget by remember { mutableFloatStateOf(0f) }
    var wobbleTarget by remember { mutableFloatStateOf(0f) }
    var notice by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    val lamp by animateFloatAsState(lampTarget, tween(if (still) 0 else 650), label = "lamp")
    val mossX by animateFloatAsState(mossXTarget, spring(dampingRatio = 0.68f, stiffness = 220f), label = "mossX")
    val wobble by animateFloatAsState(wobbleTarget, spring(dampingRatio = 0.35f, stiffness = Spring.StiffnessMedium), label = "wobble")

    LaunchedEffect(still) {
        if (still) {
            lampTarget = 1f
            step = 4
            return@LaunchedEffect
        }
        step = 0
        lampTarget = 0f
        mossXTarget = 0f
        wobbleTarget = 0f
        delay(280)
        // Shot A (0–1.5s): Otto's lamp lights up
        step = 1
        lampTarget = 1f
        delay(950)
        // Shot B (1.5–3.2s): Moss wakes, looks twice, touches the wooden stacker
        step = 2
        notice += 1
        mossXTarget = 16f
        wobbleTarget = 1f
        delay(420)
        wobbleTarget = 0f
        delay(450)
        // Moss turns delighted to Otto; Otto blinks slowly
        step = 3
        mossXTarget = 6f
        delay(950)
        // Shot C (3.2–4.0s): Both settle and glance down toward the action button
        step = 4
        mossXTarget = 0f
    }

    val mossMood = when {
        focus == Kind.Moss -> Mood.Happy
        step == 0 -> Mood.Sleep
        step == 2 -> Mood.Wow
        step == 3 -> Mood.Happy
        else -> Mood.Calm
    }
    val ottoMood = when {
        focus == Kind.Otto -> Mood.Happy
        step == 3 -> Mood.Happy
        else -> Mood.Calm
    }
    val mossLook = when {
        focus == Kind.Otto -> Offset(0.9f, -0.1f)
        step == 1 || step == 2 || step == 3 -> Offset(0.9f, 0.05f)
        step == 4 -> Offset(0.15f, 0.65f)
        else -> Offset(0.4f, 0.1f)
    }
    val ottoLook = when {
        focus == Kind.Moss -> Offset(-0.9f, 0.1f)
        step == 2 || step == 3 -> Offset(-0.85f, 0.15f)
        step == 4 -> Offset(-0.15f, 0.65f)
        else -> Offset(-0.35f, 0.15f)
    }

    BoxWithConstraints(
        modifier = modifier
            .clip(RoundedCornerShape(28.dp))
            .background(Color(0xFF1A2230))
            .semantics { contentDescription = "小苔与奥托的台灯剧场" },
    ) {
        val w = maxWidth
        val h = maxHeight

        // Night room backdrop image (subtle) + painted window, moon, light cone, and table
        Sticker(
            name = "stage_night.webp",
            modifier = Modifier.fillMaxSize().graphicsLayer { alpha = 0.32f + lamp * 0.26f },
            scale = androidx.compose.ui.layout.ContentScale.Crop,
        )

        Canvas(Modifier.fillMaxSize()) {
            val cw = size.width
            val ch = size.height

            // Evening window on top-left with crescent moon and stars
            val winX = cw * 0.12f
            val winY = ch * 0.11f
            val winW = cw * 0.19f
            val winH = ch * 0.34f
            drawRoundRect(
                color = Color(0xFF233047),
                topLeft = Offset(winX, winY),
                size = Size(winW, winH),
                cornerRadius = CornerRadius(10.dp.toPx()),
            )
            val moonCenter = Offset(winX + winW * 0.58f, winY + winH * 0.36f)
            drawCircle(Palette.BeadLight.copy(alpha = 0.85f), radius = 7.dp.toPx(), center = moonCenter)
            drawCircle(Color(0xFF233047), radius = 6.dp.toPx(), center = moonCenter + Offset(3.dp.toPx(), -2.dp.toPx()))
            drawCircle(Palette.Paper.copy(alpha = 0.55f), radius = 1.5.dp.toPx(), center = Offset(winX + winW * 0.28f, winY + winH * 0.26f))
            drawCircle(Palette.Paper.copy(alpha = 0.45f), radius = 1.2.dp.toPx(), center = Offset(winX + winW * 0.34f, winY + winH * 0.64f))

            // Warm light cone from Otto's golden bead lamp
            if (lamp > 0.01f) {
                val apex = Offset(cw * 0.71f, ch * 0.22f)
                val cone = Path().apply {
                    moveTo(apex.x, apex.y)
                    lineTo(cw * 0.10f, ch * 0.92f)
                    lineTo(cw * 0.96f, ch * 0.92f)
                    close()
                }
                drawPath(
                    path = cone,
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Palette.BeadLight.copy(alpha = 0.34f * lamp),
                            Palette.Bead.copy(alpha = 0.15f * lamp),
                            Color.Transparent,
                        ),
                        startY = apex.y,
                        endY = ch * 0.92f,
                    ),
                )
            }

            // Wooden tabletop at bottom
            val tableTop = ch * 0.75f
            drawRect(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF56412C).copy(alpha = 0.65f + lamp * 0.35f),
                        Color(0xFF34271A),
                    ),
                    startY = tableTop,
                    endY = ch,
                ),
                topLeft = Offset(0f, tableTop),
                size = Size(cw, ch - tableTop),
            )
            drawLine(
                color = Palette.BeadLight.copy(alpha = 0.22f * lamp),
                start = Offset(0f, tableTop),
                end = Offset(cw, tableTop),
                strokeWidth = 1.5.dp.toPx(),
            )
            // Warm pool of light on tabletop
            if (lamp > 0.01f) {
                drawOval(
                    brush = Brush.radialGradient(
                        colors = listOf(Palette.BeadLight.copy(alpha = 0.26f * lamp), Color.Transparent),
                        center = Offset(cw * 0.53f, tableTop + (ch - tableTop) * 0.42f),
                        radius = cw * 0.40f,
                    ),
                    topLeft = Offset(cw * 0.13f, tableTop - ch * 0.03f),
                    size = Size(cw * 0.80f, (ch - tableTop) * 0.88f),
                )
            }
        }

        // Wooden ring stacker in the middle of the table
        WoodenStacker(
            wobble = wobble,
            lit = lamp,
            modifier = Modifier
                .size(width = 48.dp, height = 56.dp)
                .align(Alignment.BottomCenter)
                .offset(x = (-6).dp, y = -(h * 0.14f)),
        )

        // Moss on the left
        Box(
            modifier = Modifier
                .size(88.dp)
                .align(Alignment.BottomCenter)
                .offset(x = (-74).dp + mossX.dp, y = -(h * 0.11f))
                .graphicsLayer { alpha = 0.65f + lamp * 0.35f }
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) {
                    onSelect?.invoke(Kind.Moss)
                    scope.launch {
                        wobbleTarget = 1f
                        delay(380)
                        wobbleTarget = 0f
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            if (selecting && focus == Kind.Moss) {
                Box(
                    Modifier
                        .size(80.dp)
                        .background(Palette.MintLight.copy(alpha = 0.22f), CircleShape)
                )
            }
            Creature(
                kind = Kind.Moss,
                modifier = Modifier.fillMaxSize(),
                mood = mossMood,
                look = mossLook,
                lid = if (step == 0) 1f else 0f,
                interactive = onSelect == null,
                notice = notice,
            )
        }

        // Otto on the right, lighting the table
        Box(
            modifier = Modifier
                .size(102.dp)
                .align(Alignment.BottomCenter)
                .offset(x = 68.dp, y = -(h * 0.10f))
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) {
                    onSelect?.invoke(Kind.Otto)
                    if (lampTarget < 1f) lampTarget = 1f
                },
            contentAlignment = Alignment.Center,
        ) {
            if (selecting && focus == Kind.Otto) {
                Box(
                    Modifier
                        .size(92.dp)
                        .background(Palette.BeadLight.copy(alpha = 0.22f), CircleShape)
                )
            }
            Creature(
                kind = Kind.Otto,
                modifier = Modifier.fillMaxSize(),
                mood = ottoMood,
                look = ottoLook,
                lamp = lamp > 0.2f,
                interactive = onSelect == null,
            )
        }
    }
}

@Composable
private fun WoodenStacker(wobble: Float, lit: Float, modifier: Modifier = Modifier) {
    Canvas(modifier.graphicsLayer { alpha = 0.55f + lit * 0.45f }) {
        val w = size.width
        val h = size.height
        // Base & dowel
        drawRoundRect(
            color = Color(0xFF9C7444),
            topLeft = Offset(w * 0.10f, h * 0.84f),
            size = Size(w * 0.80f, h * 0.12f),
            cornerRadius = CornerRadius(4.dp.toPx()),
        )
        drawRoundRect(
            color = Color(0xFFC99B63),
            topLeft = Offset(w * 0.44f, h * 0.20f),
            size = Size(w * 0.12f, h * 0.66f),
            cornerRadius = CornerRadius(3.dp.toPx()),
        )
        // Bottom two rings
        drawRoundRect(
            color = Palette.Moss,
            topLeft = Offset(w * 0.15f, h * 0.68f),
            size = Size(w * 0.70f, h * 0.15f),
            cornerRadius = CornerRadius(6.dp.toPx()),
        )
        drawRoundRect(
            color = Palette.Bead,
            topLeft = Offset(w * 0.21f, h * 0.52f),
            size = Size(w * 0.58f, h * 0.14f),
            cornerRadius = CornerRadius(6.dp.toPx()),
        )
        // Top ring that wobbles when Moss touches it
        val shiftX = wobble * 4.dp.toPx()
        drawRoundRect(
            color = Color(0xFFD86C52),
            topLeft = Offset(w * 0.28f + shiftX, h * 0.37f - wobble * 2.dp.toPx()),
            size = Size(w * 0.44f, h * 0.13f),
            cornerRadius = CornerRadius(6.dp.toPx()),
        )
    }
}

/**
 * Modal sheet to replay Moss & Otto's story ("小苔与奥托的故事"), matching iOS `StoryRoute` / `showStory`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StorySheet(
    companion: Kind,
    onSelectCompanion: (Kind) -> Unit,
    onDismiss: () -> Unit,
) {
    var replayKey by remember { mutableIntStateOf(0) }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("小苔与奥托", style = MaterialTheme.typography.headlineSmall)
                    Text("孩子摸索，大人点灯", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                TextButton(onClick = { replayKey += 1 }) { Text("再看一遍") }
            }
            androidx.compose.runtime.key(replayKey) {
                LampScene(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(210.dp),
                    focus = companion,
                    selecting = true,
                    onSelect = onSelectCompanion,
                )
            }
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerLow,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("小苔 Moss · ${Kind.Moss.trait}", style = MaterialTheme.typography.titleSmall)
                    Text("好奇、反应快，总想先凑过去看一眼桌上的教具；看见新玩法会连眨两下眼。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(2.dp))
                    Text("奥托 Otto · ${Kind.Otto.trait}", style = MaterialTheme.typography.titleSmall)
                    Text("安静、动作慢半拍，头顶有一颗金色串珠小灯；到了夜里会替你把桌面照亮。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}
