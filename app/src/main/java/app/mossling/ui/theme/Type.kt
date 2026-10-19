package app.mossling.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import app.mossling.R

/** Numerals and Latin display: Young Serif. Chinese headings: Noto Serif SC. Interface text: Instrument Sans
 *  for Latin and digits, the system's CJK sans for Chinese. */
val Numerals = FontFamily(Font(R.font.young_serif, FontWeight.Normal))
val SerifCjk = FontFamily(Font(R.font.noto_serif_sc_semibold, FontWeight.SemiBold))
val Sans = FontFamily(
    Font(R.font.instrument_sans_regular, FontWeight.Normal),
    Font(R.font.instrument_sans_medium, FontWeight.Medium),
    Font(R.font.instrument_sans_semibold, FontWeight.SemiBold),
    Font(R.font.instrument_sans_bold, FontWeight.Bold),
)

private val trim = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None)
private fun sans(size: Int, line: Int, w: FontWeight = FontWeight.Normal, track: Double = 0.0) =
    TextStyle(fontFamily = Sans, fontWeight = w, fontSize = size.sp, lineHeight = line.sp, letterSpacing = track.em, lineHeightStyle = trim)
private fun serif(size: Int, line: Int, track: Double = 0.0) =
    TextStyle(fontFamily = SerifCjk, fontWeight = FontWeight.SemiBold, fontSize = size.sp, lineHeight = line.sp, letterSpacing = track.em, lineHeightStyle = trim)

val MosslingType = Typography(
    displayLarge = TextStyle(fontFamily = Numerals, fontSize = 96.sp, lineHeight = 96.sp, letterSpacing = (-0.02).em),
    displayMedium = TextStyle(fontFamily = Numerals, fontSize = 64.sp, lineHeight = 68.sp, letterSpacing = (-0.015).em),
    displaySmall = TextStyle(fontFamily = Numerals, fontSize = 44.sp, lineHeight = 48.sp),
    headlineLarge = serif(30, 40, 0.01),
    headlineMedium = serif(25, 34, 0.01),
    headlineSmall = serif(21, 30, 0.01),
    titleLarge = serif(19, 28),
    titleMedium = sans(16, 24, FontWeight.SemiBold),
    titleSmall = sans(14, 20, FontWeight.SemiBold, 0.01),
    bodyLarge = sans(17, 28),
    bodyMedium = sans(15, 24),
    bodySmall = sans(13, 20),
    labelLarge = sans(15, 20, FontWeight.SemiBold, 0.01),
    labelMedium = sans(13, 18, FontWeight.Medium, 0.02),
    labelSmall = sans(11, 16, FontWeight.Medium, 0.04),
)
