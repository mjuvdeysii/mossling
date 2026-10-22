package app.mossling.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

/** Montessori materials: moss, the blue rods, the golden beads, natural wood, chalk paper and ink. */
object Palette {
    val Ink = Color(0xFF1C1D19)
    val Chalk = Color(0xFFF4F2EC)
    val Paper = Color(0xFFFBF9F3)
    val Linen = Color(0xFFEAE6DC)
    val Stone = Color(0xFFD9D4C7)
    val Moss = Color(0xFF55704A)
    val MossDeep = Color(0xFF3D5434)
    val MossLight = Color(0xFF88A06C)
    val Sprout = Color(0xFF9DB26F)
    val Mint = Color(0xFF4FAE7F)
    val MintLight = Color(0xFF7FCBA0)
    val MintPale = Color(0xFFA9E0C0)
    val MintVein = Color(0xFF2B6A4A)
    val Rod = Color(0xFF2D4A8C)
    val RodDeep = Color(0xFF1F3566)
    val RodLight = Color(0xFF4D69AA)
    val Bead = Color(0xFFD4A21C)
    val BeadLight = Color(0xFFEDCB6A)
    val Wood = Color(0xFFC99B63)
    val RedRod = Color(0xFFB8382B)
    val Night = Color(0xFF121411)
    val NightRaised = Color(0xFF1B1E19)
}

val LightColors: ColorScheme = lightColorScheme(
    primary = Palette.MossDeep, onPrimary = Palette.Paper,
    primaryContainer = Color(0xFFD7E3C9), onPrimaryContainer = Color(0xFF1E2C17),
    secondary = Palette.Rod, onSecondary = Palette.Paper,
    secondaryContainer = Color(0xFFD9E0F2), onSecondaryContainer = Color(0xFF15254A),
    tertiary = Color(0xFF8A6508), onTertiary = Palette.Paper,
    tertiaryContainer = Color(0xFFF6E4AE), onTertiaryContainer = Color(0xFF3A2A00),
    error = Palette.RedRod, onError = Palette.Paper,
    errorContainer = Color(0xFFF7DAD4), onErrorContainer = Color(0xFF4A0F08),
    background = Palette.Chalk, onBackground = Palette.Ink,
    surface = Palette.Chalk, onSurface = Palette.Ink,
    surfaceVariant = Palette.Linen, onSurfaceVariant = Color(0xFF4A4C43),
    surfaceContainerLowest = Palette.Paper, surfaceContainerLow = Color(0xFFF0EDE5),
    surfaceContainer = Color(0xFFECE8DF), surfaceContainerHigh = Color(0xFFE6E2D8), surfaceContainerHighest = Palette.Linen,
    outline = Color(0xFF7B7D72), outlineVariant = Palette.Stone,
    inverseSurface = Color(0xFF2E302A), inverseOnSurface = Palette.Chalk, inversePrimary = Color(0xFFB3CB9F),
    scrim = Color(0xFF000000),
)

val DarkColors: ColorScheme = darkColorScheme(
    primary = Color(0xFFB3CB9F), onPrimary = Color(0xFF1E2C17),
    primaryContainer = Color(0xFF34472C), onPrimaryContainer = Color(0xFFD7E3C9),
    secondary = Color(0xFFAFC0EE), onSecondary = Color(0xFF15254A),
    secondaryContainer = Color(0xFF2A3D6B), onSecondaryContainer = Color(0xFFD9E0F2),
    tertiary = Color(0xFFE9C860), onTertiary = Color(0xFF3A2A00),
    tertiaryContainer = Color(0xFF5A4300), onTertiaryContainer = Color(0xFFF6E4AE),
    error = Color(0xFFF0A094), onError = Color(0xFF4A0F08),
    errorContainer = Color(0xFF6E1C12), onErrorContainer = Color(0xFFF7DAD4),
    background = Palette.Night, onBackground = Color(0xFFE7E4DB),
    surface = Palette.Night, onSurface = Color(0xFFE7E4DB),
    surfaceVariant = Color(0xFF2A2D26), onSurfaceVariant = Color(0xFFC3C2B6),
    surfaceContainerLowest = Color(0xFF0D0F0C), surfaceContainerLow = Color(0xFF171A15),
    surfaceContainer = Palette.NightRaised, surfaceContainerHigh = Color(0xFF22261F), surfaceContainerHighest = Color(0xFF2B2F28),
    outline = Color(0xFF8E8F84), outlineVariant = Color(0xFF3B3E36),
    inverseSurface = Color(0xFFE7E4DB), inverseOnSurface = Color(0xFF2E302A), inversePrimary = Palette.MossDeep,
    scrim = Color(0xFF000000),
)
