package app.mossling.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.dp
import app.mossling.ui.components.ArtStyle
import app.mossling.ui.components.LocalArtStyle
import app.mossling.ui.ip.Kind
import java.time.LocalTime

val MosslingShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(20.dp),
    large = RoundedCornerShape(28.dp),
    extraLarge = RoundedCornerShape(36.dp),
)

/** Which character keeps the user company (Moss or Otto). */
val LocalCompanion = staticCompositionLocalOf { Kind.Moss }

/** Whether the warm night-lamp mode is currently active. */
val LocalNightLamp = staticCompositionLocalOf { false }

enum class ThemeMode {
    System,
    Light,
    Dark;

    val label: String
        get() = when (this) {
            System -> "自动"
            Light -> "日光"
            Dark -> "夜灯"
        }
}

fun isNightHour(hour: Int = LocalTime.now().hour): Boolean = hour >= 19 || hour < 6

@Composable
fun MosslingTheme(
    mode: ThemeMode = ThemeMode.System,
    companion: Kind = Kind.Moss,
    nightLight: Boolean = false,
    artStyle: ArtStyle = ArtStyle.Vinyl,
    content: @Composable () -> Unit,
) {
    val sysDark = isSystemInDarkTheme()
    val dark = when (mode) {
        ThemeMode.System -> sysDark || (nightLight && isNightHour())
        ThemeMode.Light -> false
        ThemeMode.Dark -> true
    }
    CompositionLocalProvider(
        LocalCompanion provides companion,
        LocalArtStyle provides artStyle,
        LocalNightLamp provides dark,
    ) {
        MaterialTheme(
            colorScheme = if (dark) DarkColors else LightColors,
            typography = MosslingType,
            shapes = MosslingShapes,
            content = content,
        )
    }
}
