package app.mossling.ui.you

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.mossling.data.Block
import app.mossling.data.Content
import app.mossling.data.Topic
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.rich

@Composable
private fun Bar(title: String, onBack: () -> Unit) {
    Row(Modifier.statusBarsPadding().padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) { Glyph(G.Back) }
        Text(title, style = MaterialTheme.typography.titleLarge)
    }
}

/** Renders the handbook's text blocks: paragraphs, quotes, lists, and tables as one card per row. */
@Composable
fun Blocks(blocks: List<Block>) {
    Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        blocks.forEach { b ->
            when (b.type) {
                "p" -> Text(rich(b.text.orEmpty()), style = MaterialTheme.typography.bodyLarge)
                "quote" -> Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainer) { Text(rich(b.text.orEmpty()), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(16.dp)) }
                "list" -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) { b.items.orEmpty().forEach { Row { Text("·  ", style = MaterialTheme.typography.bodyLarge); Text(rich(it), style = MaterialTheme.typography.bodyLarge) } } }
                "table" -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val head = b.head.orEmpty()
                    b.rows.orEmpty().forEach { row ->
                        Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                row.forEachIndexed { i, cell ->
                                    if (i == 0) Text(rich(cell), style = MaterialTheme.typography.titleMedium)
                                    else Row { Text(head.getOrElse(i) { "" }, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(88.dp).padding(top = 2.dp)); Text(rich(cell), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun TopicScreen(t: Topic, onBack: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp)) {
        item { Bar("", onBack) }
        item { Text(t.title, style = MaterialTheme.typography.headlineLarge, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) }
        item { Blocks(t.blocks) }
    }
}

/** Everything about where the handbook comes from — in this one place and nowhere else in the app. */
@Composable
fun AboutScreen(c: Content, onBack: () -> Unit) {
    val uri = LocalUriHandler.current
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp)) {
        item { Bar("", onBack) }
        item { Text("关于与来源", style = MaterialTheme.typography.headlineLarge, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) }
        item { Blocks(c.about.top) }
        item { SectionTitle("怎么读这本手册", kicker = null) }
        item { Blocks(c.about.method) }
        item { SectionTitle("可信程度", kicker = null) }
        item { Blocks(c.about.confidence) }
        if (c.about.vaccineNote.isNotBlank() || c.about.checkupNote.isNotBlank()) item {
            SectionTitle("接种与儿保", kicker = null)
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(c.about.vaccineNote, style = MaterialTheme.typography.bodyMedium); Text(c.about.checkupNote, style = MaterialTheme.typography.bodyMedium)
            }
        }
        item { SectionTitle("来源", kicker = "${c.sources.size} 份机构原始文件") }
        items(c.sources, key = { it.code }) { s ->
            Surface(onClick = { if (s.url.isNotBlank()) runCatching { uri.openUri(s.url) } }, color = MaterialTheme.colorScheme.surface, modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(horizontal = 20.dp, vertical = 10.dp)) {
                    Text(s.org, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                    Text(s.title, style = MaterialTheme.typography.titleMedium)
                    Text(listOf(s.date, s.checked).filter { it.isNotBlank() }.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item { SectionTitle("核对过的说法", kicker = "${c.about.ledger.size} 条") }
        items(c.about.ledger, key = { it.id }) { l ->
            Column(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
                Text(l.claim, style = MaterialTheme.typography.bodyMedium)
                Text("${l.level} · ${l.source} · ${l.checked}" + if (l.limit.isNotBlank()) " · ${l.limit}" else "", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
