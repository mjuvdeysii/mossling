package app.mossling.ui.components

import androidx.compose.animation.AnimatedVisibilityScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier

/** Shared-element plumbing: the root provides the transition scope, each destination its own visibility scope. */
@OptIn(ExperimentalSharedTransitionApi::class)
val LocalShared = compositionLocalOf<SharedTransitionScope?> { null }
val LocalDestination = compositionLocalOf<AnimatedVisibilityScope?> { null }

/** Marks an element that travels between screens (the play's code label, for one). No-op in previews and tests. */
@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun Modifier.shared(key: String): Modifier {
    val s = LocalShared.current ?: return this
    val d = LocalDestination.current ?: return this
    return with(s) { this@shared.sharedBounds(rememberSharedContentState(key), d) }
}
