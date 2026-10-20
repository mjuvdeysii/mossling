package app.mossling.ui.play

import kotlinx.coroutines.launch
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.clip
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
                    val ctx = androidx.compose.ui.platform.LocalContext.current
                    IconButton(onClick = { share(ctx, p) }, modifier = Modifier.semantics { contentDescription = "分享这个玩法" }) { Glyph(G.Share, size = 22.dp) }
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
                SectionTitle("怎么做", kicker = "${p.steps.size} 步 · 左右滑动")
                Steps(p)
            }
            if (p.observe.isNotBlank() || p.pause.isNotBlank()) item("watch") {
                SectionTitle("做的时候", kicker = "记事实，不打分")
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (p.observe.isNotBlank()) Note("看什么", p.observe, MaterialTheme.colorScheme.secondaryContainer, MaterialTheme.colorScheme.onSecondaryContainer)
                    if (p.pause.isNotBlank()) Note("什么时候停下", p.pause, MaterialTheme.colorScheme.tertiaryContainer, MaterialTheme.colorScheme.onTertiaryContainer)
                }
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

/** The play as plain text, for a message to family: what to prepare, the safety line, the steps. */
private fun share(ctx: android.content.Context, p: Play) {
    val text = buildString {
        append(p.code).append(" ").append(p.name).append('\n')
        if (p.age.isNotBlank()) append(p.age).append('\n')
        if (p.prepare.isNotBlank()) append("准备：").append(p.prepare).append('\n')
        if (p.safety.isNotBlank()) append("安全：").append(p.safety).append('\n')
        p.steps.forEachIndexed { i, s -> append(i + 1).append(". ").append(s).append('\n') }
        if (p.observe.isNotBlank()) append("看什么：").append(p.observe).append('\n')
        append("— 来自 Mossling 苔生")
    }
    val send = android.content.Intent(android.content.Intent.ACTION_SEND).setType("text/plain").putExtra(android.content.Intent.EXTRA_TEXT, text)
    runCatching { ctx.startActivity(android.content.Intent.createChooser(send, "分享 ${p.name}")) }
}

/**
 * The steps as a row of cards, one step per card: the picture and its words in the same container, so a picture
 * can never be read as belonging to the text above it. The next card peeks in from the edge; golden beads below
 * count the steps, the current one larger.
 */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun Steps(p: Play) {
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val frames = androidx.compose.runtime.remember(p.code) { app.mossling.ui.components.ArtIndex.steps(ctx, p.code) }
    val pager = androidx.compose.foundation.pager.rememberPagerState { p.steps.size }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    androidx.compose.foundation.pager.HorizontalPager(pager, contentPadding = PaddingValues(start = 16.dp, end = if (p.steps.size > 1) 48.dp else 16.dp),
        pageSpacing = 12.dp, verticalAlignment = Alignment.Top, key = { it }) { i ->
        val off = ((pager.currentPage - i) + pager.currentPageOffsetFraction).let { kotlin.math.abs(it) }.coerceIn(0f, 1f)
        Surface(shape = RoundedCornerShape(32.dp), color = MaterialTheme.colorScheme.surfaceContainerLow,
            modifier = Modifier.fillMaxWidth().graphicsLayer { val k = 1f - 0.06f * off; scaleX = k; scaleY = k; alpha = 1f - 0.35f * off }) {
            Column {
                frames.getOrNull(i)?.let { f ->
                    app.mossling.ui.components.Art(f, "第 ${i + 1} 步的图示", Modifier.fillMaxWidth().padding(8.dp).clip(RoundedCornerShape(26.dp)))
                }
                Row(Modifier.padding(start = 16.dp, end = 18.dp, top = 6.dp, bottom = 18.dp), verticalAlignment = Alignment.Top) {
                    Text("${i + 1}", fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.tertiary, softWrap = false, modifier = Modifier.widthIn(min = 44.dp).padding(end = 8.dp))
                    Text(p.steps[i], style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f).padding(top = 8.dp))
                }
            }
        }
    }
    if (p.steps.size > 1) Row(Modifier.fillMaxWidth().padding(top = 14.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        repeat(p.steps.size) { i ->
            val on = pager.currentPage == i
            val d by androidx.compose.animation.core.animateDpAsState(if (on) 16.dp else 10.dp, androidx.compose.animation.core.spring(dampingRatio = 0.5f, stiffness = 500f), label = "bead")
            Box(Modifier.size(32.dp).clickable(onClickLabel = "第 ${i + 1} 步") { scope.launch { pager.animateScrollToPage(i) } }, contentAlignment = Alignment.Center) {
                Box(Modifier.size(d).background(if (on || i < pager.currentPage) Palette.Bead else MaterialTheme.colorScheme.outlineVariant, androidx.compose.foundation.shape.CircleShape))
            }
        }
        Text("第 ${pager.currentPage + 1} / ${p.steps.size} 步", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 8.dp))
    }
}

@Composable
private fun Note(title: String, text: String, bg: androidx.compose.ui.graphics.Color, fg: androidx.compose.ui.graphics.Color) {
    Surface(shape = RoundedCornerShape(24.dp), color = bg, contentColor = fg, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(horizontal = 18.dp, vertical = 14.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(text, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(top = 4.dp))
        }
    }
}
