package app.mossling.ui.search

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Surface
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
import app.mossling.data.Block
import app.mossling.data.Content
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.areaColor
import app.mossling.ui.components.areaGlyph
import app.mossling.ui.theme.Numerals

private enum class HitCategory(val label: String) {
    All("全部"),
    Play("玩法"),
    Month("月龄"),
    Topic("专题"),
}

private data class Hit(
    val category: HitCategory,
    val kind: String,
    val title: String,
    val snippet: String,
    val domain: String?,
    val open: () -> Unit,
)

private fun Block.plainText(): String = listOfNotNull(
    text,
    items?.joinToString(" "),
    head?.joinToString(" "),
    rows?.flatten()?.joinToString(" "),
).joinToString(" ").replace("**", "")

/** One search over the content: plays, each month's areas, things to watch and care items, and the reference topics. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SearchScreen(
    c: Content,
    onBack: () -> Unit,
    openPlay: (String) -> Unit,
    openMonth: (Int) -> Unit,
    openTopic: (String) -> Unit,
) {
    var q by rememberSaveable { mutableStateOf("") }
    var cat by rememberSaveable { mutableStateOf(HitCategory.All) }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    val allHits = remember(q, c) {
        val t = q.trim()
        if (t.isEmpty()) emptyList() else buildList {
            fun cut(s: String): String {
                val clean = s.replace("**", "")
                val i = clean.indexOf(t, ignoreCase = true)
                return if (i < 0) clean.take(64) else (if (i > 18) "…" else "") + clean.substring((i - 18).coerceAtLeast(0)).take(68)
            }
            c.activities.forEach { p ->
                val body = listOf(p.name, p.prepare, p.steps.joinToString("；"), p.observe, p.safety, p.domains.joinToString()).joinToString(" ")
                if (p.code.contains(t, ignoreCase = true) || body.contains(t, ignoreCase = true)) {
                    add(Hit(HitCategory.Play, "玩法 ${p.code}", p.name, cut(body), p.domains.firstOrNull(), { openPlay(p.code) }))
                }
            }
            c.months.forEach { m ->
                val body = listOf(
                    m.title,
                    m.domains.joinToString(" ") { it.name + " " + it.text },
                    m.observe.joinToString(" ") { it.items.joinToString(" ") },
                    m.vaccines.joinToString(" "),
                    m.checkups.joinToString(" "),
                ).joinToString(" ")
                if (body.contains(t, ignoreCase = true)) {
                    add(Hit(HitCategory.Month, "满 ${m.month} 个月", m.title, cut(body), null, { openMonth(m.month) }))
                }
            }
            c.topics.forEach { tp ->
                val body = tp.title + " " + tp.blocks.joinToString(" ") { it.plainText() }
                if (body.contains(t, ignoreCase = true)) {
                    add(Hit(HitCategory.Topic, "专题", tp.title, cut(body), null, { openTopic(tp.id) }))
                }
            }
        }
    }

    val hits = remember(allHits, cat) {
        if (cat == HitCategory.All) allHits else allHits.filter { it.category == cat }
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item {
            Row(
                Modifier.statusBarsPadding().padding(horizontal = 4.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) { Glyph(G.Back) }
                OutlinedTextField(
                    value = q,
                    onValueChange = { q = it.take(30) },
                    modifier = Modifier.weight(1f).padding(end = 12.dp).focusRequester(focus),
                    singleLine = true,
                    shape = RoundedCornerShape(22.dp),
                    placeholder = { Text("搜索玩法、月龄内容、专题") },
                    leadingIcon = { Glyph(G.Search, size = 20.dp) },
                    trailingIcon = if (q.isNotEmpty()) {
                        {
                            IconButton(onClick = { q = "" }, modifier = Modifier.semantics { contentDescription = "清空" }) {
                                Glyph(G.Close, size = 18.dp)
                            }
                        }
                    } else null,
                )
            }
        }

        if (q.isBlank()) {
            item {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        "大家常找",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp),
                    )
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        listOf("辅食", "睡眠", "趴", "共读", "牙", "安全座椅", "发热", "疫苗", "儿保", "屏幕", "分离焦虑", "如厕").forEach { w ->
                            SuggestionChip(onClick = { q = w }, label = { Text(w) })
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "常翻的专题",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                    c.topics.take(6).forEach { tp ->
                        Surface(
                            onClick = { openTopic(tp.id) },
                            shape = RoundedCornerShape(20.dp),
                            color = MaterialTheme.colorScheme.surfaceContainerLow,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Row(
                                Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                ShapeBadge(
                                    G.Idea,
                                    MaterialTheme.colorScheme.secondaryContainer,
                                    MaterialTheme.colorScheme.onSecondaryContainer,
                                    shape = Shapes.of(tp.id),
                                    size = 36.dp,
                                )
                                Spacer(Modifier.width(12.dp))
                                Text(tp.title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }

        if (q.isNotBlank()) {
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(HitCategory.entries) { cItem ->
                        val count = if (cItem == HitCategory.All) allHits.size else allHits.count { it.category == cItem }
                        FilterChip(
                            selected = cat == cItem,
                            onClick = { cat = cItem },
                            label = { Text("${cItem.label} ($count)") },
                        )
                    }
                }
                Text(
                    if (hits.isEmpty()) "没有找到「${q.trim()}」" else "${hits.size} 处",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
                )
            }
        }

        items(hits, key = { it.kind + ":" + it.title }) { h ->
            Surface(
                onClick = h.open,
                shape = RoundedCornerShape(22.dp),
                color = MaterialTheme.colorScheme.surfaceContainerLowest,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                Row(
                    Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    val badgeGlyph = when (h.category) {
                        HitCategory.Play -> areaGlyph(h.domain ?: "A")
                        HitCategory.Month -> G.Grow
                        else -> G.Idea
                    }
                    val badgeTint = when (h.category) {
                        HitCategory.Play -> areaColor(h.domain ?: "A")
                        HitCategory.Month -> MaterialTheme.colorScheme.primary
                        else -> MaterialTheme.colorScheme.secondary
                    }
                    ShapeBadge(
                        badgeGlyph,
                        badgeTint.copy(alpha = 0.16f),
                        badgeTint,
                        shape = Shapes.of(h.kind + h.title),
                        size = 40.dp,
                    )
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            h.kind,
                            style = MaterialTheme.typography.labelMedium,
                            color = badgeTint,
                            fontFamily = if (h.category == HitCategory.Play) Numerals else null,
                        )
                        Text(h.title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 2.dp))
                        val t = q.trim()
                        Text(
                            buildAnnotatedString {
                                var i = 0
                                while (true) {
                                    val j = h.snippet.indexOf(t, i, ignoreCase = true)
                                    if (j < 0 || t.isEmpty()) {
                                        append(h.snippet.substring(i))
                                        break
                                    }
                                    append(h.snippet.substring(i, j))
                                    withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)) {
                                        append(h.snippet.substring(j, j + t.length))
                                    }
                                    i = j + t.length
                                }
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 2,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            }
        }
    }
}
