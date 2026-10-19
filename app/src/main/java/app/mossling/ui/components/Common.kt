package app.mossling.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp

/** A page section: a quiet small label above, the title in the book serif. */
@Composable
fun SectionTitle(title: String, modifier: Modifier = Modifier, kicker: String? = null, trailing: @Composable (() -> Unit)? = null) {
    Row(modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(top = 28.dp, bottom = 10.dp), verticalAlignment = Alignment.Bottom) {
        Column(Modifier.weight(1f)) {
            if (kicker != null) Text(kicker, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(title, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.semantics { heading() })
        }
        trailing?.invoke()
    }
}

/** A card the way this app draws them: one flat plane, generous corners, no shadow. */
@Composable
fun Plate(
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.surfaceContainerLowest,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(28.dp)
    if (onClick != null) Surface(onClick = onClick, modifier = modifier, shape = shape, color = color) { Column(Modifier.padding(20.dp), content = content) }
    else Surface(modifier = modifier, shape = shape, color = color) { Column(Modifier.padding(20.dp), content = content) }
}

/** A labelled line inside a plate: a short tag on the left, text on the right. */
@Composable
fun Tagged(tag: String, text: String, tagColor: Color = MaterialTheme.colorScheme.primary, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.Start) {
        Text(tag, style = MaterialTheme.typography.labelMedium, color = tagColor, modifier = Modifier.width(44.dp).padding(top = 3.dp))
        Spacer(Modifier.width(4.dp))
        Text(text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
    }
}

/** The handbook writes emphasis as **this**; render it bold. */
fun rich(s: String): AnnotatedString = buildAnnotatedString {
    var i = 0
    while (i < s.length) {
        val a = s.indexOf("**", i)
        if (a < 0) { append(s.substring(i)); break }
        val b = s.indexOf("**", a + 2)
        if (b < 0) { append(s.substring(i)); break }
        append(s.substring(i, a))
        withStyle(SpanStyle(fontWeight = FontWeight.SemiBold)) { append(s.substring(a + 2, b)) }
        i = b + 2
    }
}

/** Colour for each of the six areas of development, from the same material palette. */
fun areaColor(key: String): Color = when (key) {
    "A" -> Color(0xFF2D4A8C)
    "B" -> Color(0xFF55704A)
    "C" -> Color(0xFFB07B12)
    "D" -> Color(0xFFB8382B)
    "E" -> Color(0xFF8C6A45)
    else -> Color(0xFF5A5C55)
}
