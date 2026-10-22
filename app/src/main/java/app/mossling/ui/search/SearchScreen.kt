package app.mossling.ui.search

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import app.mossling.data.Content
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.theme.Numerals

private data class Hit(val kind: String, val title: String, val snippet: String, val open: () -> Unit)

/** One search over the content: plays, each month's areas, things to watch and care items, and the reference topics. */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun SearchScreen(c: Content, onBack: () -> Unit, openPlay: (String) -> Unit, openMonth: (Int) -> Unit, openTopic: (String) -> Unit) {
    var q by rememberSaveable { mutableStateOf("") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    val hits = remember(q, c) {
        val t = q.trim()
        if (t.isEmpty()) emptyList() else buildList {
            fun cut(s: String): String { val i = s.indexOf(t); return if (i < 0) s.take(60) else (if (i > 18) "…" else "") + s.substring((i - 18).coerceAtLeast(0)).take(64) }
            c.activities.forEach { p ->
                val body = listOf(p.name, p.prepare, p.steps.joinToString("；"), p.observe, p.safety, p.domains.joinToString()).joinToString(" ")
                if (t in p.code || t in body) add(Hit("玩法 ${p.code}", p.name, cut(body), { openPlay(p.code) }))
            }
            c.months.forEach { m ->
                val body = listOf(m.title, m.domains.joinToString(" ") { it.name + " " + it.text }, m.observe.joinToString(" ") { it.items.joinToString(" ") }, m.vaccines.joinToString(" "), m.checkups.joinToString(" ")).joinToString(" ")
                if (t in body) add(Hit("满 ${m.month} 个月", m.title, cut(body), { openMonth(m.month) }))
            }
            c.topics.forEach { tp ->
                val body = tp.title + " " + tp.blocks.joinToString(" ") { it.toString() }
                if (t in body) add(Hit("专题", tp.title, cut(tp.title), { openTopic(tp.id) }))
            }
        }
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp)) {
        item {
            Row(Modifier.statusBarsPadding().padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) { Glyph(G.Back) }
                OutlinedTextField(q, { q = it.take(30) }, Modifier.weight(1f).padding(end = 12.dp).focusRequester(focus), singleLine = true, shape = RoundedCornerShape(20.dp),
                    placeholder = { Text("搜索玩法、月龄内容、专题") }, leadingIcon = { Glyph(G.Search, size = 20.dp) })
            }
        }
        if (q.isBlank()) item {
            // a few starting points, so the empty screen is not a dead end
            Text("常用", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp))
            androidx.compose.foundation.layout.FlowRow(Modifier.padding(horizontal = 16.dp), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(8.dp)) {
                listOf("辅食", "睡眠", "趴", "共读", "牙", "安全座椅", "发热", "疫苗", "儿保", "屏幕").forEach { w ->
                    androidx.compose.material3.SuggestionChip(onClick = { q = w }, label = { Text(w) })
                }
            }
        }
        if (q.isNotBlank()) item {
            Text(if (hits.isEmpty()) "没有找到「${q.trim()}」" else "${hits.size} 处", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
        }
        items(hits, key = { it.kind + it.title }) { h ->
            Column(Modifier.fillMaxWidth().clickable(onClick = h.open).heightIn(min = 56.dp).padding(horizontal = 20.dp, vertical = 10.dp)) {
                Text(h.kind, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary, fontFamily = if (h.kind.startsWith("玩法")) Numerals else null)
                Text(h.title, style = MaterialTheme.typography.titleMedium)
                val t = q.trim()
                Text(buildAnnotatedString {
                    var i = 0
                    while (true) { val j = h.snippet.indexOf(t, i); if (j < 0 || t.isEmpty()) { append(h.snippet.substring(i)); break }
                        append(h.snippet.substring(i, j)); withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)) { append(t) }; i = j + t.length }
                }, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2)
            }
        }
    }
}
