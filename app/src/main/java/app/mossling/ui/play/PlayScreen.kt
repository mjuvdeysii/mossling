package app.mossling.ui.play

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.mossling.data.Play
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.Plate
import app.mossling.ui.components.shared
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Family
import app.mossling.ui.ip.MaterialStill
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette

/** One play, read the way it is done: what you need and what to watch for safety first, then the steps. */
@Composable
fun PlayScreen(p: Play, month: Int, did: Boolean, onDid: (Boolean) -> Unit, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val companion = LocalCompanion.current
    Box(modifier.fillMaxSize()) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 120.dp)) {
            item("top") {
                Row(Modifier.statusBarsPadding().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) { Glyph(G.Back) }
                    Spacer(Modifier.weight(1f))
                    Text("满 $month 个月", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(end = 16.dp))
                }
            }
            item("head") {
                Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.Bottom) {
                    Column(Modifier.weight(1f)) {
                        Surface(shape = RoundedCornerShape(18.dp), color = if (companion == app.mossling.ui.ip.Kind.Moss) Palette.Moss else Palette.Rod, modifier = Modifier.shared("code-${p.code}")) {
                            Text(p.code, fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, color = Palette.Paper, modifier = Modifier.padding(horizontal = 14.dp, vertical = 2.dp))
                        }
                        Text(p.name, style = MaterialTheme.typography.headlineLarge)
                        Text(listOf(p.age, p.domains.joinToString("、")).filter { it.isNotBlank() }.joinToString(" · "), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
                    }
                    Creature(companion, Modifier.size(88.dp), mood = if (did) Mood.Happy else Mood.Open, look = Offset(-0.7f, 0.6f))
                }
            }
            item("still") {
                // the material, set out on its mat: what this play looks like before anyone touches it
                Surface(shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.surfaceContainer, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp)) {
                    MaterialStill(Family.of(p.domains), Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp), ground = MaterialTheme.colorScheme.surfaceContainerHigh)
                }
            }
            item("before") {
                Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                    Text("开始之前", style = MaterialTheme.typography.titleMedium)
                    if (p.prepare.isNotBlank()) Line("准备", p.prepare, MaterialTheme.colorScheme.primary)
                    if (p.safety.isNotBlank()) Line("安全", p.safety, MaterialTheme.colorScheme.error)
                }
            }
            item("steps") {
                SectionTitle("怎么做", kicker = "${p.steps.size} 步")
                Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                    p.steps.forEachIndexed { i, s ->
                        Row(verticalAlignment = Alignment.Top) {
                            Text("${i + 1}", fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.tertiary, softWrap = false, modifier = Modifier.widthIn(min = 48.dp).padding(end = 8.dp))
                            Text(s, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f).padding(top = 8.dp))
                        }
                    }
                }
            }
            if (p.observe.isNotBlank()) item("watch") {
                SectionTitle("看什么", kicker = "记事实，不打分")
                Text(p.observe, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(horizontal = 20.dp))
            }
            if (p.pause.isNotBlank()) item("pause") {
                SectionTitle("什么时候停下", kicker = null)
                Text(p.pause, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(horizontal = 20.dp))
            }
        }
        // the one action, always within reach
        Surface(Modifier.align(Alignment.BottomCenter).fillMaxWidth(), color = MaterialTheme.colorScheme.surface.copy(alpha = 0.96f)) {
            val bg by animateColorAsState(if (did) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.primary, label = "did")
            val fg by animateColorAsState(if (did) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onPrimary, label = "didfg")
            Column(Modifier.navigationBarsPadding().padding(horizontal = 16.dp, vertical = 12.dp)) {
                Button(onClick = { onDid(!did) }, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(20.dp), colors = ButtonDefaults.buttonColors(containerColor = bg, contentColor = fg)) {
                    if (did) { Glyph(G.Check, size = 20.dp, color = fg); Spacer(Modifier.width(8.dp)) }
                    Text(if (did) "这个月做过了" else "记为做过")
                }
            }
        }
    }
}

@Composable
private fun Line(tag: String, text: String, tint: androidx.compose.ui.graphics.Color) {
    Row(Modifier.padding(top = 10.dp)) {
        Text(tag, style = MaterialTheme.typography.labelLarge, color = tint, softWrap = false, modifier = Modifier.widthIn(min = 48.dp).padding(end = 8.dp))
        Text(text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
    }
}
