package app.mossling.ui.grow

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.AreaOverview
import app.mossling.data.MonthGuide
import app.mossling.data.Play
import app.mossling.data.TickKind
import app.mossling.data.tickKey
import app.mossling.domain.PlayRecord
import app.mossling.ui.components.Art
import app.mossling.ui.components.ArtIndex
import app.mossling.ui.components.BeadChain
import app.mossling.ui.components.ColorTablet
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.MorphBlob
import app.mossling.ui.components.NumberRod
import app.mossling.ui.components.PinkTower
import app.mossling.ui.components.Plate
import app.mossling.ui.components.ProgressRing
import app.mossling.ui.components.SandpaperNumber
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.Shelf
import app.mossling.ui.components.Sticker
import app.mossling.ui.components.TrayArt
import app.mossling.ui.components.areaColor
import app.mossling.ui.components.areaGlyph
import app.mossling.ui.components.areaSticker
import app.mossling.ui.components.rich
import app.mossling.ui.components.shared
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.GrowingChild
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import app.mossling.ui.today.SmallCheck
import app.mossling.ui.you.Blocks

data class GrowActions(
    val selectMonth: (Int) -> Unit = {},
    val openPlay: (String) -> Unit = {},
    val openTopic: (String) -> Unit = {},
    val toggle: (String, String, String) -> Unit = { _, _, _ -> },
    val openGrowth: () -> Unit = {},
    val openMap: () -> Unit = {},
    val openPlan: () -> Unit = {},
    val openBook: () -> Unit = {},
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GrowScreen(ui: AppUi, month: Int, a: GrowActions) {
    val content = ui.content ?: return
    val guide = content.month(month) ?: return
    val babyMonth = ui.age?.bookMonth
    val records = remember(ui.ticks, ui.allLogs, month, ui.today) { ui.playRecords(month) }
    val (primary, also) = content.playsSplit(month)
    val doneCodes = ui.ticks.values.filter { it.month == month && it.kind == TickKind.Did }.map { it.key.substringAfterLast(":") }.toSet() +
        records.values.filter { it.total > 0 }.map { it.code }
    var showAllAlso by rememberSaveable(month) { mutableStateOf(false) }

    LazyColumn(
        Modifier.fillMaxSize().testTag("grow"),
        contentPadding = PaddingValues(bottom = 112.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item("chain") {
            Column(Modifier.statusBarsPadding().padding(top = 6.dp)) {
                Row(
                    Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "0–36 个月 · 滑到哪一颗看哪一站",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f),
                    )
                    if (babyMonth != null && babyMonth != month) {
                        AssistChip(onClick = { a.selectMonth(babyMonth) }, label = { Text("回到满 $babyMonth 个月") })
                        Spacer(Modifier.width(6.dp))
                    }
                    TextButton(onClick = a.openBook) { Text("成长册") }
                    TextButton(onClick = a.openMap) { Text("地图") }
                }
                BeadChain(
                    selected = month,
                    babyMonth = babyMonth,
                    onSelect = a.selectMonth,
                    modifier = Modifier.padding(horizontal = 8.dp),
                )
            }
        }

        item("banner") { MonthBanner(guide, month, babyMonth, ui) }

        item("growth-entry") {
            val last = ui.measures.maxByOrNull { it.at }
            val sub = if (last == null) {
                "体重、身长、头围 · 对照 WHO 生长标准"
            } else {
                listOfNotNull(
                    last.weightG?.let { "${"%.2f".format(it / 1000.0)} kg" },
                    last.lengthMm?.let { "${"%.1f".format(it / 10.0)} cm" },
                    last.headMm?.let { "头围 ${"%.1f".format(it / 10.0)} cm" },
                ).joinToString(" · ")
            }
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp), onClick = a.openGrowth) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ShapeBadge(G.Ruler, MaterialTheme.colorScheme.secondaryContainer, MaterialTheme.colorScheme.onSecondaryContainer, shape = Shapes.Clover, size = 40.dp)
                    Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                        Text("生长曲线", style = MaterialTheme.typography.titleMedium)
                        Text(sub, fontFamily = Numerals, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text("查看", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                }
            }
        }

        item("plays") {
            val donePrimary = primary.count { it.code in doneCodes }
            SectionTitle(
                "这个月玩什么",
                kicker = "推荐 ${primary.size} 个 · 做过 $donePrimary",
                trailing = {
                    if (month == (babyMonth ?: 0)) {
                        TextButton(onClick = a.openPlan) { Text("放上架子") }
                    }
                },
            )
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                NumberRod(donePrimary, primary.size)
                Shelf(Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        primary.forEach { p ->
                            PlayRow(
                                p = p,
                                done = p.code in doneCodes,
                                record = records[p.code],
                                onOpen = { a.openPlay(p.code) },
                                onToggle = { a.toggle(TickKind.Did, p.code, p.name) },
                            )
                        }
                    }
                }
            }
        }

        if (also.isNotEmpty()) {
            item("also") {
                SectionTitle("也适合这个月", kicker = "${also.size} 个跨月龄玩法")
                val visible = if (showAllAlso) also else also.take(4)
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    visible.forEach { p ->
                        PlayRow(
                            p = p,
                            done = p.code in doneCodes,
                            record = records[p.code],
                            onOpen = { a.openPlay(p.code) },
                            onToggle = { a.toggle(TickKind.Did, p.code, p.name) },
                        )
                    }
                    if (also.size > 4) {
                        TextButton(onClick = { showAllAlso = !showAllAlso }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                            Text(if (showAllAlso) "收起" else "展开其余 ${also.size - 4} 个")
                        }
                    }
                }
            }
        }

        if (guide.observe.isNotEmpty()) {
            item("observe") {
                val total = guide.observe.sumOf { it.items.size }
                val done = ui.ticks.values.count { it.month == month && it.kind == TickKind.Observed }
                SectionTitle("可以留意", kicker = "观察参考，不是考试 · 已记下 $done / $total")
                Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                    Row(
                        Modifier.fillMaxWidth().padding(bottom = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        ProgressRing(done = done, total = total, tint = MaterialTheme.colorScheme.primary)
                        PinkTower(done, total)
                        Column(Modifier.weight(1f)) {
                            Text("$done / $total", fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium)
                            Text(
                                "粉红塔：每留意到一项就往上叠一块；快慢不一，不作比较",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    guide.observe.forEachIndexed { gi, g ->
                        if (gi > 0) Spacer(Modifier.height(14.dp))
                        Text(g.group, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.height(6.dp))
                        g.items.forEachIndexed { ii, text ->
                            val id = "$gi-$ii"
                            val checked = tickKey(month, TickKind.Observed, id) in ui.ticks
                            Row(
                                Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp))
                                    .clickable { a.toggle(TickKind.Observed, id, text) }
                                    .padding(vertical = 7.dp),
                                verticalAlignment = Alignment.Top,
                            ) {
                                SmallCheck(checked, Modifier.padding(top = 2.dp))
                                Spacer(Modifier.width(12.dp))
                                Text(text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }

        item("domains") {
            SectionTitle("六个方面", kicker = "满 $month 个月")
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                guide.domains.forEach { d -> AreaCard(d) }
            }
        }

        if (guide.vaccines.isNotEmpty() || guide.checkups.isNotEmpty()) {
            item("care") {
                val totalCare = guide.vaccines.size + guide.checkups.size
                val doneCare = guide.vaccines.indices.count { tickKey(month, TickKind.Vaccine, "$it") in ui.ticks } +
                    guide.checkups.indices.count { tickKey(month, TickKind.Checkup, "$it") in ui.ticks }
                SectionTitle(
                    "接种与儿保",
                    kicker = "仅供参考，以预防接种证与社区医院为准",
                    trailing = { ProgressRing(done = doneCare, total = totalCare, size = 38.dp) },
                )
                Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                    if (guide.vaccines.isNotEmpty()) {
                        Text("疫苗", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.height(4.dp))
                        guide.vaccines.forEachIndexed { i, v ->
                            val id = "$i"
                            val checked = tickKey(month, TickKind.Vaccine, id) in ui.ticks
                            CheckLine(v, checked) { a.toggle(TickKind.Vaccine, id, v) }
                        }
                    }
                    if (guide.checkups.isNotEmpty()) {
                        if (guide.vaccines.isNotEmpty()) Spacer(Modifier.height(12.dp))
                        Text("儿保", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.secondary)
                        Spacer(Modifier.height(4.dp))
                        guide.checkups.forEachIndexed { i, c ->
                            val id = "$i"
                            val checked = tickKey(month, TickKind.Checkup, id) in ui.ticks
                            CheckLine(c, checked) { a.toggle(TickKind.Checkup, id, c) }
                        }
                    }
                }
            }
        }

        guide.rhythm?.takeIf { it.isNotEmpty() }?.let { r ->
            item("rhythm") {
                SectionTitle("一天的节奏")
                Blocks(r)
            }
        }

        if (guide.extra.isNotEmpty()) {
            item("extra") {
                SectionTitle("还要知道")
                Blocks(guide.extra)
            }
        }

        item("topics") {
            SectionTitle("常翻的专题", kicker = "睡眠 · 喂养 · 安全 · 就医信号")
            FlowRow(
                Modifier.padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                content.topics.forEach { t ->
                    Surface(
                        onClick = { a.openTopic(t.id) },
                        shape = RoundedCornerShape(18.dp),
                        color = MaterialTheme.colorScheme.surfaceContainerLow,
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    ) {
                        Text(t.title, style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun MonthBanner(guide: MonthGuide, month: Int, babyMonth: Int?, ui: AppUi) {
    val ctx = LocalContext.current
    val cover = remember(month) { ArtIndex.cover(ctx, month) }
    val tag = when {
        babyMonth == null -> "第 $month 站"
        month == babyMonth -> "现在这一站"
        month < babyMonth -> "走过的第 $month 站"
        else -> "往前的第 $month 站"
    }
    val look = when {
        babyMonth == null -> Offset(0.5f, 0f)
        month < babyMonth -> Offset(-0.7f, 0.1f)
        month > babyMonth -> Offset(0.7f, -0.1f)
        else -> null
    }
    Surface(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        shape = RoundedCornerShape(32.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
    ) {
        Column(Modifier.padding(22.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(tag, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.height(6.dp))
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text("满 ", style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(bottom = 4.dp))
                        SandpaperNumber("$month", MaterialTheme.typography.displaySmall)
                        Text(" 个月", style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(start = 6.dp, bottom = 4.dp))
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(
                        guide.title,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Spacer(Modifier.width(8.dp))
                Box(contentAlignment = Alignment.BottomEnd) {
                    GrowingChild(month = month, modifier = Modifier.size(92.dp))
                    Creature(
                        ui.settings.companion,
                        Modifier.size(46.dp),
                        mood = if (month == babyMonth) Mood.Happy else Mood.Calm,
                        look = look,
                    )
                }
            }
            if (cover != null) {
                Spacer(Modifier.height(14.dp))
                Art(
                    cover,
                    label = "满 $month 个月：${guide.title}",
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)),
                )
            }
        }
    }
}

@Composable
private fun PlayRow(
    p: Play,
    done: Boolean,
    record: PlayRecord?,
    onOpen: () -> Unit,
    onToggle: () -> Unit,
) {
    val count = maxOf(record?.total ?: 0, if (done) 1 else 0)
    Surface(
        onClick = onOpen,
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLowest,
    ) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(54.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surfaceContainer),
                contentAlignment = Alignment.Center,
            ) {
                TrayArt(p.code, modifier = Modifier.fillMaxSize().padding(4.dp), label = p.name)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        p.code,
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.shared("play-code-${p.code}"),
                    )
                    p.domains.forEach { d -> ColorTablet(areaColor(d)) }
                    if (count > 1) {
                        Text(
                            "×$count",
                            fontFamily = Numerals,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
                Text(
                    p.name,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.padding(top = 2.dp).shared("play-title-${p.code}"),
                )
                if (p.prepare.isNotEmpty() && p.prepare != "无") {
                    Text(p.prepare, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Spacer(Modifier.width(8.dp))
            Box(
                Modifier
                    .size(48.dp)
                    .clickable(onClick = onToggle)
                    .semantics {
                        role = Role.Checkbox
                        contentDescription = "记为做过"
                        stateDescription = if (done) "已做过" else "未做"
                    },
                contentAlignment = Alignment.Center,
            ) {
                MorphBlob(
                    done,
                    from = Shapes.Circle,
                    to = Shapes.Burst,
                    color = if (done) Palette.Bead else MaterialTheme.colorScheme.surfaceContainerHigh,
                    modifier = Modifier.size(40.dp),
                )
                Glyph(G.Check, size = 18.dp, color = if (done) Palette.Ink else MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun AreaCard(d: AreaOverview) {
    val c = areaColor(d.key)
    Plate(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(contentAlignment = Alignment.Center) {
                ShapeBadge(areaGlyph(d.key), c.copy(alpha = 0.16f), c, shape = Shapes.of(d.key), size = 36.dp)
                Sticker(areaSticker(d.key), size = 22.dp)
            }
            Spacer(Modifier.width(10.dp))
            ColorTablet(c)
            Spacer(Modifier.width(8.dp))
            Text(d.name, style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(8.dp))
        Text(rich(d.text), style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun CheckLine(text: String, checked: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 7.dp),
        verticalAlignment = Alignment.Top,
    ) {
        SmallCheck(checked, Modifier.padding(top = 2.dp))
        Spacer(Modifier.width(12.dp))
        Text(rich(text), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
    }
}
