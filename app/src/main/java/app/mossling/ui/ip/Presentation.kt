package app.mossling.ui.ip

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Presentation-only state machine for Moss & Otto (`docs/IP.md` §3).
 *
 * The companions never read raw domain data or speak words; they only react to high-level
 * presentation events after an action is confirmed.
 */
enum class MascotPresentationState(val rawValue: String) {
    Dormant("dormant"),
    Idle("idle"),
    Observing("observing"),
    Focusing("focusing"),
    Acknowledge("acknowledge"),
    Rest("rest"),
}

enum class MascotEvent(val rawValue: String) {
    RecordStartConfirmed("record.start.confirmed"),
    RecordPersistSuccess("record.persist.success"),
    RecordPersistFailure("record.persist.failure"),
    ActivityRecommendationChanged("activity.recommendation.changed"),
    NightmodeEnabled("nightmode.enabled"),
    NightmodeDisabled("nightmode.disabled"),
    CompanionChanged("companion.changed"),
    AppBackground("app.background"),
    AppActive("app.active"),
    RecordTimerEnded("record.timer.ended"),
    PresentationSettle("presentation.settle"),
}

data class MascotMachine(
    var state: MascotPresentationState = MascotPresentationState.Idle,
    var night: Boolean = false,
) {
    fun send(event: MascotEvent): MascotPresentationState {
        when (event) {
            MascotEvent.AppBackground -> state = MascotPresentationState.Dormant
            MascotEvent.AppActive -> state = if (night) MascotPresentationState.Rest else MascotPresentationState.Idle
            MascotEvent.NightmodeEnabled -> {
                night = true
                if (state != MascotPresentationState.Focusing && state != MascotPresentationState.Dormant) {
                    state = MascotPresentationState.Rest
                }
            }
            MascotEvent.NightmodeDisabled -> {
                night = false
                if (state == MascotPresentationState.Rest) {
                    state = MascotPresentationState.Idle
                }
            }
            MascotEvent.RecordStartConfirmed -> {
                if (state != MascotPresentationState.Dormant) {
                    state = MascotPresentationState.Focusing
                }
            }
            MascotEvent.RecordTimerEnded -> {
                if (state == MascotPresentationState.Focusing) {
                    state = if (night) MascotPresentationState.Rest else MascotPresentationState.Idle
                }
            }
            MascotEvent.RecordPersistSuccess -> {
                if (state != MascotPresentationState.Dormant) {
                    state = MascotPresentationState.Acknowledge
                }
            }
            MascotEvent.RecordPersistFailure -> {
                if (state != MascotPresentationState.Dormant) {
                    state = if (night) MascotPresentationState.Rest else MascotPresentationState.Idle
                }
            }
            MascotEvent.ActivityRecommendationChanged, MascotEvent.CompanionChanged -> {
                if (state == MascotPresentationState.Idle || state == MascotPresentationState.Observing) {
                    state = MascotPresentationState.Observing
                }
            }
            MascotEvent.PresentationSettle -> {
                if (state == MascotPresentationState.Acknowledge || state == MascotPresentationState.Observing) {
                    state = if (night) MascotPresentationState.Rest else MascotPresentationState.Idle
                }
            }
        }
        return state
    }
}

/**
 * Character timing and pose parameters — numbers only, never text (`docs/IP.md` §3.3).
 */
data class MascotStyle(
    val glanceMs: Int,
    val glanceStages: Int,
    val blinkMs: Int,
    val tiltDegrees: Float,
    val acknowledgeMs: Int,
    val sproutLagMs: Int,
    val observeMs: Int,
) {
    companion object {
        val moss = MascotStyle(
            glanceMs = 180,
            glanceStages = 2,
            blinkMs = 90,
            tiltDegrees = 4f,
            acknowledgeMs = 420,
            sproutLagMs = 120,
            observeMs = 900,
        )
        val otto = MascotStyle(
            glanceMs = 300,
            glanceStages = 1,
            blinkMs = 180,
            tiltDegrees = 2f,
            acknowledgeMs = 550,
            sproutLagMs = 0,
            observeMs = 1200,
        )

        fun of(kind: Kind): MascotStyle = when (kind) {
            Kind.Moss -> moss
            Kind.Otto -> otto
        }
    }
}

@Stable
class MascotDirector(private val scope: CoroutineScope? = null) {
    private var machine = MascotMachine()
    private var settleJob: Job? = null

    var state by mutableStateOf(MascotPresentationState.Idle)
        private set
    var acknowledgements by mutableIntStateOf(0)
        private set
    var observations by mutableIntStateOf(0)
        private set
    var sleepsStarted by mutableIntStateOf(0)
        private set
    var failures by mutableIntStateOf(0)
        private set

    fun style(kind: Kind): MascotStyle = MascotStyle.of(kind)

    fun noteSleepStarted(companion: Kind) {
        sleepsStarted += 1
        handle(MascotEvent.RecordStartConfirmed, companion)
    }

    fun handle(event: MascotEvent, companion: Kind) {
        settleJob?.cancel()
        state = machine.send(event)
        val style = MascotStyle.of(companion)
        when (event) {
            MascotEvent.RecordPersistSuccess -> {
                acknowledgements += 1
                scheduleSettle(style.acknowledgeMs.coerceAtMost(550).toLong(), companion)
            }
            MascotEvent.RecordPersistFailure -> {
                failures += 1
            }
            MascotEvent.ActivityRecommendationChanged, MascotEvent.CompanionChanged -> {
                if (state == MascotPresentationState.Observing) {
                    observations += 1
                    scheduleSettle(style.observeMs.toLong(), companion)
                }
            }
            else -> {}
        }
    }

    private fun scheduleSettle(ms: Long, companion: Kind) {
        val s = scope ?: return
        settleJob = s.launch {
            delay(ms)
            handle(MascotEvent.PresentationSettle, companion)
        }
    }
}

val LocalMascotDirector = compositionLocalOf { MascotDirector() }

@Composable
fun rememberMascotDirector(): MascotDirector {
    val scope = rememberCoroutineScope()
    return remember(scope) { MascotDirector(scope) }
}
