package app.mossling.ui.search

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import app.mossling.data.AreaNames
import app.mossling.data.Block
import app.mossling.data.Content
import app.mossling.ui.components.ColorTablet
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
    var selectedDomain by rememberSaveable { mutableStateOf<String?>(null) }
    val focus = remember { FocusRequester() }
    val haptic = LocalHapticFeedback.current
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    val domainCounts = remember(c) {
        AreaNames.keys.associateWith { d -> c.activities.count { d in it.domains } }
    }

    val allHits = remember(q, selectedDomain, c) {
        val t = q.trim()
        if (t.isEmpty() && selectedDomain == null) emptyList() else buildList {
            fun cut(s: String): String {
                val clean = s.replace("**", "")
                if (t.isEmpty()) return clean.take(64)
                val i = clean.indexOf(t, ignoreCase = true)
                return if (i < 0) clean.take(64) else (if (i > 18) "…" else "") + clean.substring((i - 18).coerceAtLeast(0)).take(68)
            }
            c.activities.forEach { p ->
                val matchesDomain = selectedDomain == null || selectedDomain in p.domains
                if (!matchesDomain) return@forEach
                val body = listOf(p.name, p.prepare, p.steps.joinToString("；"), p.observe, p.safety, p.domains.joinToString()).joinToString(" ")
                if (t.isEmpty() || p.code.contains(t, ignoreCase = true) || body.contains(t, ignoreCase = true)) {
                    val rangeText = "满 ${p.months.first()}–${p.months.last()} 月"
                    add(Hit(HitCategory.Play, "玩法 ${p.code} · $rangeText", p.name, cut(body), p.domains.firstOrNull(), { openPlay(p.code) }))
                }
            }
            if (selectedDomain == null && t.isNotEmpty()) {
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
                    trailingIcon = if (q.isNotEmpty() || selectedDomain != null) {
                        {
                            IconButton(
                                onClick = { q = ""; selectedDomain = null; cat = HitCategory.All },
                                modifier = Modifier.semantics { contentDescription = "清空" },
                            ) {
                                Glyph(G.Close, size = 18.dp)
                            }
                        }
                    } else null,
                )
            }
        }

        if (q.isBlank() && selectedDomain == null) {
            item {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(
                        "大家常找",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                    )
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        listOf("辅食", "睡眠", "趴", "共读", "牙", "安全座椅", "发热", "疫苗", "儿保", "屏幕", "分离焦虑", "如厕").forEach { w ->
                            SuggestionChip(
                                onClick = {
                                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    q = w
                                },
                                label = { Text(w) },
                            )
                        }
                    }

                    Text(
                        "按六个发展领域找玩法",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                    )
                    AreaNames.entries.chunked(2).forEach { pair ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            pair.forEach { (key, title) ->
                                val col = areaColor(key)
                                Surface(
                                    onClick = {
                                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                        selectedDomain = key
                                        cat = HitCategory.All
                                    },
                                    modifier = Modifier.weight(1f),
                                    shape = RoundedCornerShape(20.dp),
                                    color = MaterialTheme.colorScheme.surfaceContainerLow,
                                    border = BorderStroke(1.dp, col.copy(alpha = 0.25f)),
                                ) {
                                    Row(
                                        Modifier.padding(horizontal = 12.dp, vertical = 12.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        ShapeBadge(areaGlyph(key), col.copy(alpha = 0.16f), col, shape = Shapes.of(key), size = 34.dp)
                                        Spacer(Modifier.width(10.dp))
                                        Column(Modifier.weight(1f)) {
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                                ColorTablet(col)
                                                Text(title, style = MaterialTheme.typography.titleSmall)
                                            }
                                            Text(
                                                "${domainCounts[key] ?: 0} 个玩法",
                                                fontFamily = Numerals,
                                                style = MaterialTheme.typography.labelSmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text(
                        "全部育儿专题 (${c.topics.size})",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                    c.topics.forEach { tp ->
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
                                Glyph(
                                    G.Back,
                                    size = 16.dp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.graphicsLayer { rotationZ = 180f },
                                )
                            }
                        }
                    }
                }
            }
        }

        if (q.isNotBlank() || selectedDomain != null) {
            item {
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    selectedDomain?.let { d ->
                        item("active-domain") {
                            FilterChip(
                                selected = true,
                                onClick = { selectedDomain = null },
                                leadingIcon = { ColorTablet(areaColor(d)) },
                                trailingIcon = { Glyph(G.Close, size = 14.dp) },
                                label = { Text(AreaNames[d] ?: d) },
                            )
                        }
                    }
                    if (selectedDomain == null && q.isNotBlank()) {
                        items(HitCategory.entries) { cItem ->
                            val count = if (cItem == HitCategory.All) allHits.size else allHits.count { it.category == cItem }
                            FilterChip(
                                selected = cat == cItem,
                                onClick = { cat = cItem },
                                label = { Text("${cItem.label} ($count)") },
                            )
                        }
                    }
                }
                Text(
                    when {
                        hits.isEmpty() -> "没有找到「${q.trim()}」"
                        selectedDomain != null && q.isBlank() -> "${AreaNames[selectedDomain]} · 共 ${hits.size} 个玩法"
                        else -> "${hits.size} 处"
                    },
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
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).animateItem(),
            ) {
                Row(
                    Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
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
                                    val j = if (t.isEmpty()) -1 else h.snippet.indexOf(t, i, ignoreCase = true)
                                    if (j < 0) {
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
                    Spacer(Modifier.width(8.dp))
                    Glyph(
                        G.Back,
                        size = 16.dp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.graphicsLayer { rotationZ = 180f },
                    )
                }
            }
        }
    }
}
