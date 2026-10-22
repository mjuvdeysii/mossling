package app.mossling.ui.you

import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.remember
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
fun Bar(title: String, onBack: () -> Unit) {
    Row(Modifier.statusBarsPadding().padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) { Glyph(G.Back) }
        Text(title, style = MaterialTheme.typography.titleLarge)
    }
}

/** Renders the app's text blocks: paragraphs, quotes, lists, and tables as one card per row. */
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

/** Everything about where the content comes from — in this one place and nowhere else in the app. */
@Composable
fun AboutScreen(c: Content, licenses: () -> Unit = {}, onBack: () -> Unit) {
    val uri = LocalUriHandler.current
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val version = remember { runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName }.getOrNull() ?: "" }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp)) {
        item { Bar("", onBack) }
        item { Text("内容来源", style = MaterialTheme.typography.headlineLarge, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) }
        item { Blocks(c.about.top) }
        item { SectionTitle("怎么读这些内容", kicker = null) }
        item { Blocks(c.about.method) }
        item { SectionTitle("可信程度", kicker = null) }
        item { Blocks(c.about.confidence) }
        if (c.about.vaccineNote.isNotBlank() || c.about.checkupNote.isNotBlank()) item {
            SectionTitle("接种与儿保", kicker = null)
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(c.about.vaccineNote, style = MaterialTheme.typography.bodyMedium); Text(c.about.checkupNote, style = MaterialTheme.typography.bodyMedium)
            }
        }
        item { SectionTitle("参考文献", kicker = "${c.sources.size + 1} 项") }
        // a numbered reference list: number, institution, title, date and check; the code is how the content cites it
        itemsIndexed(c.sources, key = { _, s -> s.code }) { i, s -> Reference(i + 1, s.code, s.org, s.title, listOf(s.date, s.checked).filter { it.isNotBlank() }.joinToString("；")) {
            if (s.url.isNotBlank()) runCatching { uri.openUri(s.url) } } }
        item { Reference(c.sources.size + 1, "WHO-CGS", "World Health Organization", "WHO Child Growth Standards：体重、身长 / 身高、头围的年龄别标准", "2006") {
            runCatching { uri.openUri("https://www.who.int/tools/child-growth-standards") } } }
        item { SectionTitle("核对过的说法", kicker = "${c.about.ledger.size} 条") }
        itemsIndexed(c.about.ledger, key = { _, l -> l.id }) { i, l ->
            Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
                Text("${i + 1}.", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(32.dp))
                Column(Modifier.weight(1f)) {
                    Text(l.claim, style = MaterialTheme.typography.bodyMedium)
                    Text("证据等级 ${l.level} · ${l.source} · 核对 ${l.checked}" + if (l.limit.isNotBlank()) " · ${l.limit}" else "", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

    }
}

@Composable
private fun LinkRow(title: String, sub: String, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(horizontal = 18.dp, vertical = 14.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** The fonts, libraries and data this app is built with: name, version, licence and rights holder, in that order. */
private data class Lib(val name: String, val version: String, val licence: String, val holder: String)

@Composable
fun LicensesScreen(onBack: () -> Unit) {
    val groups = listOf(
        "字体" to listOf(
            Lib("Young Serif", "—", "SIL Open Font License 1.1", "© 2023 The Young Serif Project Authors"),
            Lib("Noto Serif SC（子集）", "—", "SIL Open Font License 1.1", "© 2017 Adobe Systems Incorporated；Noto 为 Google LLC 的商标"),
            Lib("Instrument Sans", "—", "SIL Open Font License 1.1", "© 2022 The Instrument Sans Project Authors"),
        ),
        "开源库" to listOf(
            Lib("Jetpack Compose（BOM）", "2025.01.00", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Navigation Compose", "2.8.5", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Room", "2.6.1", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("DataStore", "1.1.1", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Glance", "1.1.1", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Lifecycle", "2.8.7", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Activity / Fragment", "1.9.3 / 1.8.5", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Core / SplashScreen", "1.15.0 / 1.0.1", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Biometric", "1.1.0", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("ProfileInstaller", "1.4.1", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Graphics Shapes", "1.0.1", "Apache License 2.0", "© The Android Open Source Project"),
            Lib("Kotlin 标准库", "2.1.0", "Apache License 2.0", "© JetBrains s.r.o."),
            Lib("kotlinx.serialization", "1.7.3", "Apache License 2.0", "© JetBrains s.r.o."),
            Lib("kotlinx.coroutines", "—", "Apache License 2.0", "© JetBrains s.r.o."),
        ),
        "数据" to listOf(
            Lib("WHO Child Growth Standards", "2006", "按世界卫生组织公开发布条款使用", "© World Health Organization"),
        ),
    )
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 32.dp)) {
        item { Bar("开源许可", onBack) }
        groups.forEach { (title, libs) ->
            item(title) {
                Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(start = 28.dp, top = 16.dp, bottom = 6.dp))
                Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                    Column {
                        libs.forEachIndexed { i, l ->
                            if (i > 0) androidx.compose.material3.HorizontalDivider(Modifier.padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
                            Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                                Row(verticalAlignment = Alignment.Bottom) {
                                    Text(l.name, style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
                                    if (l.version != "—") Text(l.version, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Text(l.licence, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 2.dp))
                                Text(l.holder, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }
        }
        item {
            Text("许可证全文见源代码仓库 licenses 目录。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 28.dp, vertical = 16.dp))
        }
    }
}

@Composable
private fun Reference(n: Int, code: String, org: String, title: String, date: String, onClick: () -> Unit) {
    Surface(onClick = onClick, color = MaterialTheme.colorScheme.surface, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 10.dp)) {
            Text("[$n]", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, modifier = Modifier.width(40.dp))
            Column(Modifier.weight(1f)) {
                Text(org, style = MaterialTheme.typography.titleSmall)
                Text(title, style = MaterialTheme.typography.bodyMedium)
                Text(listOf(code, date).filter { it.isNotBlank() }.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
