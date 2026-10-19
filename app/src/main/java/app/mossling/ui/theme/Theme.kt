package app.mossling.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.dp
import app.mossling.ui.ip.Kind

val MosslingShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(20.dp),
    large = RoundedCornerShape(28.dp),
    extraLarge = RoundedCornerShape(36.dp),
)

/** Which character keeps the user company (Moss or Otto). */
val LocalCompanion = staticCompositionLocalOf { Kind.Moss }

enum class ThemeMode { System, Light, Dark }

@Composable
fun MosslingTheme(mode: ThemeMode = ThemeMode.System, companion: Kind = Kind.Moss, content: @Composable () -> Unit) {
    val dark = when (mode) { ThemeMode.System -> isSystemInDarkTheme(); ThemeMode.Light -> false; ThemeMode.Dark -> true }
    CompositionLocalProvider(LocalCompanion provides companion) {
        MaterialTheme(colorScheme = if (dark) DarkColors else LightColors, typography = MosslingType, shapes = MosslingShapes, content = content)
    }
}
