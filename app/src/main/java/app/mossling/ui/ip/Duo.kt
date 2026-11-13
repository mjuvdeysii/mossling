package app.mossling.ui.ip

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.mossling.ui.components.reducedMotion
import kotlinx.coroutines.delay
import kotlin.random.Random

/**
 * Moss and Otto together (`docs/IP.md` §4.2, `ios/Mossling/IP/Creature.swift`).
 *
 * The chosen companion stands in front at full scale; the other stands slightly behind (`0.88×`).
 * Every 14–24s in daylight (when Reduce Motion is off), they share a brief wordless moment.
 * At night (`Rest` or dark theme), they rest quietly with half-closed eyes and Otto's warm lamp lit.
 */
@Composable
fun Duo(
    lead: Kind,
    modifier: Modifier = Modifier,
    size: Dp = 88.dp,
    mood: Mood = Mood.Calm,
    look: Offset? = null,
    notice: Int = 0,
) {
    val still = reducedMotion()
    val director = LocalMascotDirector.current
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.2f
    val nightRest = isDark || director.state == MascotPresentationState.Rest

    var act by remember { mutableIntStateOf(0) }
    var ack by remember { mutableStateOf(false) }
    var glanceDown by remember { mutableStateOf(false) }

    LaunchedEffect(mood, look, still, nightRest) {
        if (still || mood != Mood.Calm || look != null || nightRest) {
            act = 0
            return@LaunchedEffect
        }
        val r = Random(31)
        while (true) {
            delay(r.nextLong(14_000, 24_000))
            act = r.nextInt(1, 4)
            delay(1300)
            act = 0
        }
    }

    LaunchedEffect(director.acknowledgements) {
        if (director.acknowledgements <= 0) return@LaunchedEffect
        ack = true
        delay(lead.style.acknowledgeMs.coerceAtMost(550).toLong())
        ack = false
    }

    LaunchedEffect(director.observations) {
        if (director.observations <= 0) return@LaunchedEffect
        glanceDown = true
        delay(lead.style.observeMs.toLong())
        glanceDown = false
    }

    val mossLook = when {
        look != null -> look
        glanceDown -> Offset(0f, 0.55f)
        act == 1 || act == 2 -> Offset(0.95f, -0.1f)
        act == 3 -> Offset(0f, 0.65f)
        else -> null
    }
    val ottoLook = when {
        look != null -> look
        glanceDown -> Offset(0f, 0.55f)
        act == 1 || act == 2 -> Offset(-0.95f, 0.2f)
        act == 3 -> Offset(0f, 0.65f)
        else -> null
    }
    val mossMood = when {
        ack || act == 2 -> Mood.Happy
        else -> mood
    }
    val ottoMood = when {
        ack || act == 2 -> Mood.Happy
        else -> mood
    }
    val nightLid = if (nightRest && mood == Mood.Calm && !ack) 0.5f else 0f

    val back = if (lead == Kind.Moss) Kind.Otto else Kind.Moss
    val backSize = size * DuoDefaults.behind
    val shift = size * DuoDefaults.apart

    Box(modifier.width(size + shift), contentAlignment = Alignment.BottomStart) {
        Creature(
            kind = back,
            modifier = Modifier
                .size(backSize)
                .offset(x = if (lead == Kind.Moss) shift else 0.dp),
            mood = if (back == Kind.Moss) mossMood else ottoMood,
            look = if (back == Kind.Moss) mossLook else ottoLook,
            lid = nightLid,
            notice = notice,
        )
        Creature(
            kind = lead,
            modifier = Modifier
                .size(size)
                .offset(x = if (lead == Kind.Moss) 0.dp else shift),
            mood = if (lead == Kind.Moss) mossMood else ottoMood,
            look = if (lead == Kind.Moss) mossLook else ottoLook,
            lid = nightLid,
            notice = notice,
        )
    }
}

object DuoDefaults {
    const val behind = 0.88f
    const val apart = 0.48f
}
