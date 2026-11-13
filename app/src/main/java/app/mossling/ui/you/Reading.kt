package app.mossling.ui.you

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.mossling.data.Block
import app.mossling.data.Content
import app.mossling.data.Topic
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.rich
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Bar(title: String, onBack: () -> Unit, actions: @Composable RowScope.() -> Unit = {}) {
    TopAppBar(
        title = {
            Text(
                title,
                style = MaterialTheme.typography.titleLarge,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        },
        navigationIcon = {
            IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) {
                Glyph(G.Back)
            }
        },
        actions = actions,
        colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
    )
}

/**
 * Renders structured content blocks as native Material 3 cards, callouts, and grouped lists
 * rather than flat web-like paragraphs.
 */
@Composable
fun Blocks(blocks: List<Block>) {
    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        blocks.forEach { b ->
            when (b.type) {
                "p" -> Surface(
                    shape = RoundedCornerShape(22.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerLowest,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        rich(b.text.orEmpty()),
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.padding(18.dp),
                    )
                }
                "quote" -> Surface(
                    shape = RoundedCornerShape(24.dp),
                    color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.55f),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.secondary.copy(alpha = 0.25f)),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(
                        Modifier.padding(16.dp),
                        verticalAlignment = Alignment.Top,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        ShapeBadge(
                            G.Idea,
                            MaterialTheme.colorScheme.secondaryContainer,
                            MaterialTheme.colorScheme.onSecondaryContainer,
                            shape = Shapes.Flower,
                            size = 34.dp,
                        )
                        Text(
                            rich(b.text.orEmpty()),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
                "list" -> {
                    val items = b.items.orEmpty()
                    if (items.isNotEmpty()) {
                        Surface(
                            shape = RoundedCornerShape(24.dp),
                            color = MaterialTheme.colorScheme.surfaceContainerLow,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Column(Modifier.padding(horizontal = 18.dp, vertical = 14.dp)) {
                                items.forEachIndexed { idx, item ->
                                    if (idx > 0) {
                                        HorizontalDivider(
                                            Modifier.padding(vertical = 10.dp),
                                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f),
                                        )
                                    }
                                    Row(verticalAlignment = Alignment.Top) {
                                        Box(
                                            Modifier
                                                .padding(top = 8.dp)
                                                .size(7.dp)
                                                .background(Palette.Moss, CircleShape)
                                        )
                                        Spacer(Modifier.width(12.dp))
                                        Text(
                                            rich(item),
                                            style = MaterialTheme.typography.bodyLarge,
                                            modifier = Modifier.weight(1f),
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                "table" -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    val head = b.head.orEmpty()
                    b.rows.orEmpty().forEach { row ->
                        Surface(
                            shape = RoundedCornerShape(24.dp),
                            color = MaterialTheme.colorScheme.surfaceContainerLow,
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                row.forEachIndexed { i, cell ->
                                    if (i == 0) {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                            Surface(
                                                shape = RoundedCornerShape(8.dp),
                                                color = MaterialTheme.colorScheme.primaryContainer,
                                            ) {
                                                Text(
                                                    head.firstOrNull().orEmpty().ifBlank { "要点" },
                                                    style = MaterialTheme.typography.labelSmall,
                                                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                                )
                                            }
                                            Text(rich(cell), style = MaterialTheme.typography.titleMedium)
                                        }
                                    } else {
                                        Row(
                                            Modifier
                                                .fillMaxWidth()
                                                .background(
                                                    MaterialTheme.colorScheme.surfaceContainerLowest,
                                                    RoundedCornerShape(14.dp),
                                                )
                                                .padding(horizontal = 12.dp, vertical = 8.dp),
                                            verticalAlignment = Alignment.Top,
                                        ) {
                                            Text(
                                                head.getOrElse(i) { "" },
                                                style = MaterialTheme.typography.labelMedium,
                                                color = MaterialTheme.colorScheme.primary,
                                                modifier = Modifier.width(84.dp).padding(top = 2.dp),
                                            )
                                            Text(
                                                rich(cell),
                                                style = MaterialTheme.typography.bodyMedium,
                                                modifier = Modifier.weight(1f),
                                            )
                                        }
                                    }
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
fun TopicScreen(
    t: Topic,
    allTopics: List<Topic> = emptyList(),
    onSelectTopic: (String) -> Unit = {},
    onBack: () -> Unit,
) {
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item("bar") { Bar(t.title, onBack) }
        if (allTopics.size > 1) {
            item("switcher") {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    allTopics.forEach { tp ->
                        FilterChip(
                            selected = tp.id == t.id,
                            onClick = { if (tp.id != t.id) onSelectTopic(tp.id) },
                            label = { Text(tp.title) },
                        )
                    }
                }
            }
        }
        item("hero") {
            Surface(
                shape = RoundedCornerShape(28.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                Row(
                    Modifier.padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    ShapeBadge(
                        G.Journal,
                        MaterialTheme.colorScheme.primaryContainer,
                        MaterialTheme.colorScheme.onPrimaryContainer,
                        shape = Shapes.of(t.id),
                        size = 48.dp,
                    )
                    Column(Modifier.weight(1f)) {
                        Text("育儿专题速查", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                        Text(t.title, style = MaterialTheme.typography.headlineMedium)
                    }
                }
            }
        }
        item("blocks") {
            AnimatedContent(
                targetState = t,
                transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(120)) },
                label = "topic-blocks",
            ) { topic ->
                Blocks(topic.blocks)
            }
        }
    }
}

/** Everything about where the content comes from — organized into interactive Material 3 tabs & cards. */
@Composable
fun AboutScreen(c: Content, licenses: () -> Unit = {}, onBack: () -> Unit) {
    val uri = LocalUriHandler.current
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var levelFilter by rememberSaveable { mutableStateOf("all") }

    val filteredLedger = remember(c.about.ledger, levelFilter) {
        if (levelFilter == "all") c.about.ledger
        else c.about.ledger.filter { it.level.equals(levelFilter, ignoreCase = true) }
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item("bar") {
            Bar("内容来源", onBack) {
                TextButton(onClick = licenses) { Text("开源许可") }
            }
        }
        item("tabs") {
            SingleChoiceSegmentedButtonRow(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                val labels = listOf(
                    "分级与方法",
                    "参考文献 (${c.sources.size + 1})",
                    "核对台账 (${c.about.ledger.size})",
                )
                labels.forEachIndexed { idx, label ->
                    SegmentedButton(
                        selected = tab == idx,
                        onClick = { tab = idx },
                        shape = SegmentedButtonDefaults.itemShape(index = idx, count = labels.size),
                        label = { Text(label, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    )
                }
            }
        }

        when (tab) {
            0 -> {
                item("top") { Blocks(c.about.top) }
                item("method-title") { SectionTitle("怎么读这些内容", kicker = "按月龄与个体节奏参考") }
                item("method") { Blocks(c.about.method) }
                item("conf-title") { SectionTitle("可信程度分级", kicker = "证据等级说明") }
                item("conf") { Blocks(c.about.confidence) }
                if (c.about.vaccineNote.isNotBlank() || c.about.checkupNote.isNotBlank()) {
                    item("vaccine") {
                        SectionTitle("接种与儿保", kicker = "以当地接种证与医院为准")
                        Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                            if (c.about.vaccineNote.isNotBlank()) {
                                Text(c.about.vaccineNote, style = MaterialTheme.typography.bodyMedium)
                            }
                            if (c.about.checkupNote.isNotBlank()) {
                                Spacer(Modifier.height(8.dp))
                                Text(c.about.checkupNote, style = MaterialTheme.typography.bodyMedium)
                            }
                        }
                    }
                }
            }
            1 -> {
                item("sources-head") {
                    SectionTitle("权威机构指南", kicker = "共 ${c.sources.size + 1} 项 · 点卡片可在浏览器打开原文")
                }
                itemsIndexed(c.sources, key = { _, s -> s.code }) { i, s ->
                    ReferenceCard(
                        n = i + 1,
                        code = s.code,
                        org = s.org,
                        title = s.title,
                        date = listOf(s.date, s.checked).filter { it.isNotBlank() }.joinToString(" · 核对 "),
                    ) {
                        if (s.url.isNotBlank()) runCatching { uri.openUri(s.url) }
                    }
                }
                item("who-cgs") {
                    ReferenceCard(
                        n = c.sources.size + 1,
                        code = "WHO-CGS",
                        org = "World Health Organization",
                        title = "WHO Child Growth Standards：体重、身长 / 身高、头围的年龄别标准",
                        date = "2006",
                    ) {
                        runCatching { uri.openUri("https://www.who.int/tools/child-growth-standards") }
                    }
                }
            }
            else -> {
                val levels = c.about.ledger.map { it.level }.distinct().sorted()
                item("ledger-head") {
                    SectionTitle("核对过的说法", kicker = "共 ${filteredLedger.size} 条核心结论")
                    if (levels.size > 1) {
                        Row(
                            Modifier.padding(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            FilterChip(
                                selected = levelFilter == "all",
                                onClick = { levelFilter = "all" },
                                label = { Text("全部 (${c.about.ledger.size})") },
                            )
                            levels.forEach { lv ->
                                val count = c.about.ledger.count { it.level == lv }
                                FilterChip(
                                    selected = levelFilter == lv,
                                    onClick = { levelFilter = lv },
                                    label = { Text("等级 $lv ($count)") },
                                )
                            }
                        }
                    }
                }
                itemsIndexed(filteredLedger, key = { _, l -> l.id }) { i, l ->
                    Surface(
                        shape = RoundedCornerShape(22.dp),
                        color = MaterialTheme.colorScheme.surfaceContainerLow,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    ) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    "#${i + 1}",
                                    fontFamily = Numerals,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                ) {
                                    Text(
                                        "证据等级 ${l.level}",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                    )
                                }
                                Surface(
                                    shape = RoundedCornerShape(8.dp),
                                    color = MaterialTheme.colorScheme.secondaryContainer,
                                ) {
                                    Text(
                                        l.source,
                                        fontFamily = Numerals,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                    )
                                }
                            }
                            Text(l.claim, style = MaterialTheme.typography.bodyLarge)
                            Text(
                                "核对日期 ${l.checked}" + if (l.limit.isNotBlank()) " · ${l.limit}" else "",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
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
                Text(
                    title,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(start = 28.dp, top = 16.dp, bottom = 6.dp),
                )
                Surface(
                    shape = RoundedCornerShape(24.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerLow,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                ) {
                    Column {
                        libs.forEachIndexed { i, l ->
                            if (i > 0) {
                                HorizontalDivider(
                                    Modifier.padding(horizontal = 16.dp),
                                    color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f),
                                )
                            }
                            Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                                Row(verticalAlignment = Alignment.Bottom) {
                                    Text(l.name, style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
                                    if (l.version != "—") {
                                        Text(
                                            l.version,
                                            fontFamily = Numerals,
                                            style = MaterialTheme.typography.labelMedium,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                    }
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
            Text(
                "许可证全文见源代码仓库 licenses 目录。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 28.dp, vertical = 16.dp),
            )
        }
    }
}

@Composable
private fun ReferenceCard(
    n: Int,
    code: String,
    org: String,
    title: String,
    date: String,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
    ) {
        Row(
            Modifier.padding(16.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Surface(
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primaryContainer,
                modifier = Modifier.size(32.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Text(
                        "$n",
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                    )
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = MaterialTheme.colorScheme.secondaryContainer,
                    ) {
                        Text(
                            code,
                            fontFamily = Numerals,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSecondaryContainer,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                    Text(
                        org,
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Text(title, style = MaterialTheme.typography.bodyMedium)
                if (date.isNotBlank()) {
                    Text(
                        date,
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}
