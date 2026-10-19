package app.mossling.ui.components

import android.provider.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode

/**
 * True when the person has turned animations off (Developer options or Accessibility → Remove animations), and in
 * previews/tests. Ambient motion — breathing, glances, hops — stops; state changes still happen, just without play.
 */
@Composable
fun reducedMotion(): Boolean {
    if (LocalInspectionMode.current) return true
    val ctx = LocalContext.current
    return remember(ctx) {
        runCatching { Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f }.getOrDefault(false)
    }
}
