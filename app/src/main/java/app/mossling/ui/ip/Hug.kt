package app.mossling.ui.ip

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.mossling.ui.components.Sticker
import app.mossling.ui.components.reducedMotion
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * The child's stage figure cuddled by the chosen companion (`ios/Mossling/IP/Hug.swift`).
 * Tapping or changing the companion/look triggers a gentle squeeze and floating heart.
 */
@Composable
fun HuggedAvatar(
    month: Int,
    girl: Boolean,
    companion: Kind,
    modifier: Modifier = Modifier,
    size: Dp = 84.dp,
) {
    val still = reducedMotion()
    val scope = rememberCoroutineScope()
    var squeezeTarget by remember { mutableFloatStateOf(0f) }
    var heartTarget by remember { mutableFloatStateOf(0f) }
    var firstRender by remember { mutableStateOf(true) }

    val squeeze by animateFloatAsState(
        targetValue = squeezeTarget,
        animationSpec = spring(dampingRatio = 0.48f, stiffness = Spring.StiffnessMedium),
        label = "squeeze",
    )
    val heart by animateFloatAsState(
        targetValue = heartTarget,
        animationSpec = tween(if (still) 0 else 420),
        label = "heart",
    )

    fun hug() {
        if (still) return
        scope.launch {
            squeezeTarget = 1f
            heartTarget = 1f
            delay(480)
            squeezeTarget = 0f
            delay(240)
            heartTarget = 0f
        }
    }

    LaunchedEffect(companion, girl) {
        if (firstRender) {
            firstRender = false
        } else {
            hug()
        }
    }

    Box(
        modifier = modifier
            .size(width = size * 1.18f, height = size * 1.06f)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ) { hug() },
        contentAlignment = Alignment.BottomCenter,
    ) {
        // The child at their current stage
        GrowingChild(
            month = month,
            modifier = Modifier
                .size(size * 0.88f)
                .offset(x = (-size.value * 0.12f).dp + (squeeze * 3f).dp)
                .graphicsLayer {
                    scaleX = 1f + squeeze * 0.04f
                    scaleY = 1f - squeeze * 0.03f
                },
        )

        // The companion cuddling beside the child
        Creature(
            kind = companion,
            modifier = Modifier
                .size(size * 0.64f)
                .offset(x = (size.value * 0.22f).dp - (squeeze * 4f).dp, y = 2.dp),
            mood = if (squeeze > 0.2f) Mood.Happy else Mood.Calm,
            look = Offset(-0.75f, -0.15f),
            interactive = false,
        )

        // Warm floating heart on cuddle
        if (heart > 0.02f) {
            Sticker(
                name = "ic_heart_fill.webp",
                size = (size.value * 0.24f).dp,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .offset(x = 4.dp, y = (-(heart * 8f)).dp)
                    .graphicsLayer {
                        alpha = heart
                        val sc = 0.7f + heart * 0.35f
                        scaleX = sc
                        scaleY = sc
                    },
            )
        }
    }
}
