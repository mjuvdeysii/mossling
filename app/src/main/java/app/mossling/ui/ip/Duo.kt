package app.mossling.ui.ip

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.mossling.ui.components.reducedMotion
import kotlinx.coroutines.delay
import kotlin.random.Random

/**
 * Moss and Otto together. The chosen companion stands in front and leads; the other stands a step behind and smaller.
 * Every few seconds they do something together: the one behind leans in, the one in front turns to it, and both
 * brighten for a moment. Asleep, both sleep. Still when animations are off.
 */
@Composable
fun Duo(
    primary: Kind,
    modifier: Modifier = Modifier,
    size: Dp = 112.dp,
    mood: Mood = Mood.Open,
    look: Offset = Offset(-0.6f, 0.2f),
    lid: Float? = null,
    poke: Boolean = true,
    together: Boolean = true,
) {
    val other = if (primary == Kind.Moss) Kind.Otto else Kind.Moss
    val still = reducedMotion()
    val asleep = mood == Mood.Sleep
    var beat by remember { mutableIntStateOf(0) }
    LaunchedEffect(still, asleep, together) {
        beat = 0
        if (still || asleep || !together) return@LaunchedEffect
        delay(1800L + Random.nextLong(1600))
        while (true) {
            beat = 1; delay(900)       // the one behind leans in
            beat = 2; delay(1500)      // the one in front turns to it; both brighten
            beat = 0; delay(6500L + Random.nextLong(5000))
        }
    }
    val lean by animateFloatAsState(if (beat == 1) -9f else 0f, spring(dampingRatio = 0.5f, stiffness = 220f), label = "lean")
    val small = size * 0.72f
    Box(modifier.width(size + small * 0.62f).height(size)) {
        Creature(other, Modifier.size(small).align(Alignment.BottomEnd).offset(y = (-2).dp),
            mood = when { asleep -> Mood.Sleep; beat == 2 -> Mood.Happy; else -> Mood.Open },
            look = if (beat >= 1) Offset(-0.9f, 0.5f) else Offset(-0.7f, 0.1f),
            lean = lean, alive = !still, poke = poke)
        Creature(primary, Modifier.size(size).align(Alignment.BottomStart),
            mood = if (beat == 2 && mood == Mood.Open) Mood.Happy else mood,
            look = if (beat >= 1) Offset(0.95f, -0.35f) else look,
            lid = if (beat >= 1) null else lid,
            label = if (primary == Kind.Moss) "Moss 和 Otto" else "Otto 和 Moss", poke = poke)
    }
}
