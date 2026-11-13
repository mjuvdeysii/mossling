package app.mossling.ui.plan

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.AreaNames
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.Play
import app.mossling.data.TickKind
import app.mossling.domain.Shelf
import app.mossling.ui.components.ColorTablet
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.MorphBlob
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.Shelf as WoodShelf
import app.mossling.ui.components.areaColor
import app.mossling.ui.components.areaGlyph
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.MaterialStill
import app.mossling.ui.ip.Mood
import app.mossling.ui.ip.familyOf
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import app.mossling.ui.you.Bar
import java.time.Instant
import java.time.ZoneId

data class PlanActions(
    val setShelf: (List<String>) -> Unit = {},
    val openPlay: (String, Int) -> Unit = { _, _ -> },
    val logPlayed: (Play, Int) -> Unit = { _, _ -> },
    val back: () -> Unit = {},
)

/**
 * The week's Montessori shelf:
 * Three plays set out in the open, repeated as often as the child likes, rotated when a new week begins or when the child loses interest.
 */
@Composable
fun PlanScreen(ui: AppUi, playLogs: List<LogEntry>, a: PlanActions) {
    val c = ui.content ?: return
    val month = ui.age?.bookMonth ?: 0
    val pool = c.playsFor(month)
    val playedCodes = remember(ui.ticks, playLogs) {
        buildSet {
            ui.ticks.values.filter { it.kind == TickKind.Did }.forEach { add(it.key.substringAfterLast(":")) }
            playLogs.filter { it.type == LogType.Play }.forEach { e ->
                e.detail?.substringBefore(" ")?.takeIf { it.isNotBlank() }?.let(::add)
            }
        }
    }
    val (onShelf, _) = Shelf.current(c, month, ui.settings.shelf, ui.today, playedCodes)
    val codes = onShelf.map { it.code }
    val z = ZoneId.systemDefault()
    val weekStart = ui.today.minusDays((ui.today.dayOfWeek.value - 1).toLong()).atStartOfDay(z).toInstant().toEpochMilli()
    val thisWeek = remember(playLogs, weekStart) {
        playLogs.filter { it.type == LogType.Play && it.start >= weekStart }
            .groupingBy { it.detail?.substringBefore(" ").orEmpty() }
            .eachCount()
    }
    val allTime = remember(playLogs) {
        playLogs.filter { it.type == LogType.Play }
            .groupingBy { it.detail?.substringBefore(" ").orEmpty() }
            .eachCount()
    }
    val rest = pool.filter { it.code !in codes }

    fun toggle(code: String) {
        val next = if (code in codes) codes - code else (codes + code).takeLast(3)
        if (next.isNotEmpty()) a.setShelf(next)
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item { Bar("本周的架子", a.back) }
        item {
            Surface(
                shape = RoundedCornerShape(28.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("矮架上一次摆三样", style = MaterialTheme.typography.headlineSmall)
                        Text(
                            "蒙台梭利教室里，架子上的工作不多，但每天都在老地方。孩子看到熟悉的托盘，会自己走过去再做一遍；做腻了，再换一样。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                    Spacer(Modifier.width(8.dp))
                    Creature(ui.settings.companion, Modifier.size(64.dp), mood = Mood.Calm)
                }
            }
        }
        item {
            SectionTitle(
                "现在摆在架子上",
                kicker = "满 $month 个月 · ${onShelf.size} / 3 样",
                trailing = {
                    TextButton(
                        onClick = {
                            a.setShelf(Shelf.suggest(c, month, played = playedCodes, lastWeek = codes).map { it.code })
                        }
                    ) { Text("换一批推荐") }
                },
            )
            WoodShelf(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    onShelf.forEach { p ->
                        ShelfItemCard(
                            p = p,
                            weekCount = thisWeek[p.code] ?: 0,
                            totalCount = allTime[p.code] ?: 0,
                            onOpen = { a.openPlay(p.code, month) },
                            onPlayed = { a.logPlayed(p, month) },
                            onRemove = if (onShelf.size > 1) ({ toggle(p.code) }) else null,
                        )
                    }
                }
            }
        }
        if (rest.isNotEmpty()) {
            item {
                SectionTitle("满 $month 个月还能摆的", kicker = "点一下换到架子上（最多 3 样）")
            }
            items(rest, key = { it.code }) { p ->
                PoolRow(
                    p = p,
                    totalCount = allTime[p.code] ?: 0,
                    onPut = { toggle(p.code) },
                    onOpen = { a.openPlay(p.code, month) },
                )
            }
        }
        item {
            SectionTitle("怎么用这个架子")
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Text(
                    "· 不必一天做完三样。一天做一样、做五分钟就够；同一件事一周做四五遍，比做五件新事更有用。\n" +
                        "· 孩子还在看、还在试的时候不打断；把头转开、推开道具，就收起来。\n" +
                        "· 每周一架子会自动按孩子的月龄换上三样覆盖不同发展领域的玩法；你也可以随时手动调整。",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

@Composable
private fun ShelfItemCard(
    p: Play,
    weekCount: Int,
    totalCount: Int,
    onOpen: () -> Unit,
    onPlayed: () -> Unit,
    onRemove: (() -> Unit)?,
) {
    Surface(
        onClick = onOpen,
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLowest,
        border = BorderStroke(1.5.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)),
    ) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                MaterialStill(
                    family = familyOf(p.domains),
                    modifier = Modifier.width(104.dp).clip(RoundedCornerShape(16.dp)),
                    ground = MaterialTheme.colorScheme.surfaceContainer,
                )
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(p.code, fontFamily = Numerals, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        p.domains.forEach { d ->
                            ColorTablet(areaColor(d))
                            Text(AreaNames[d] ?: d, style = MaterialTheme.typography.labelSmall, color = areaColor(d))
                        }
                    }
                    Text(p.name, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 2.dp))
                    if (p.prepare.isNotEmpty() && p.prepare != "无") {
                        Text("准备：${p.prepare}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f),
                ) {
                    repeat(weekCount.coerceAtMost(7)) {
                        Box(Modifier.size(10.dp).background(Palette.Bead, CircleShape))
                    }
                    Text(
                        if (weekCount == 0) "本周还没做" + (if (totalCount > 0) " · 共做过 $totalCount 次" else "")
                        else "本周 $weekCount 次" + (if (totalCount > weekCount) " · 共 $totalCount 次" else ""),
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (onRemove != null) TextButton(onClick = onRemove) { Text("撤下") }
                Button(onClick = onPlayed, shape = RoundedCornerShape(14.dp), contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp)) {
                    Glyph(G.Check, size = 16.dp)
                    Spacer(Modifier.width(4.dp))
                    Text("今天做了", style = MaterialTheme.typography.labelLarge)
                }
            }
        }
    }
}

@Composable
private fun PoolRow(p: Play, totalCount: Int, onPut: () -> Unit, onOpen: () -> Unit) {
    Surface(
        onClick = onOpen,
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            val d0 = p.domains.firstOrNull() ?: "A"
            val dc = areaColor(d0)
            ShapeBadge(areaGlyph(d0), dc.copy(alpha = 0.16f), dc, shape = Shapes.of(p.code), size = 44.dp)
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(p.code, fontFamily = Numerals, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    p.domains.forEach { ColorTablet(areaColor(it)) }
                    if (totalCount > 0) {
                        Text("做过 $totalCount 次", fontFamily = Numerals, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                    }
                }
                Text(p.name, style = MaterialTheme.typography.titleSmall)
            }
            Box(Modifier.size(44.dp).clickable(onClick = onPut), contentAlignment = Alignment.Center) {
                MorphBlob(false, Shapes.Circle, Shapes.Burst, MaterialTheme.colorScheme.surfaceContainerHighest, Modifier.size(36.dp))
                Glyph(G.Plus, size = 18.dp)
            }
        }
    }
}
