package app.mossling.ui.grow

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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.First
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.Measure
import app.mossling.data.MonthGuide
import app.mossling.data.Play
import app.mossling.data.TickKind
import app.mossling.domain.playedInMonth
import app.mossling.ui.components.Art
import app.mossling.ui.components.ArtIndex
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SandpaperNumber
import app.mossling.ui.components.Sticker
import app.mossling.ui.components.TrayArt
import app.mossling.ui.ip.HuggedAvatar
import app.mossling.ui.ip.StoryGoesOn
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import app.mossling.ui.you.Bar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * The Growth Book ("成长册", `ios/DESIGN.md` §3 & `GrowthBookView`):
 * A month-by-month keepsake album (newest lived month first) combining:
 * - Taped month cover illustration & date span
 * - "第一次" milestones recorded in that month
 * - Plays done in that month with wooden tray illustrations & counts
 * - Latest growth measurement of that month (weight, length, head circumference)
 * - Daily average care stats (sleep hours, feeds, diapers)
 * - Observed milestones & parent notes
 */
@Composable
fun GrowthBookScreen(
    ui: AppUi,
    openMonth: (Int) -> Unit,
    openPlay: (String, Int) -> Unit,
    openFirsts: () -> Unit,
    onBack: () -> Unit,
) {
    val content = ui.content ?: return
    val currentMonth = ui.age?.bookMonth ?: 0
    val monthsToShow = remember(currentMonth, ui.ticks, ui.measures, ui.firsts) {
        val maxTickMonth = ui.ticks.values.maxOfOrNull { it.month } ?: 0
        val top = maxOf(currentMonth, maxTickMonth).coerceIn(0, 36)
        (top downTo 0).toList()
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 56.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item("bar") {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) { Bar("成长册", onBack) }
                TextButton(onClick = openFirsts, modifier = Modifier.padding(end = 12.dp)) {
                    Text("记第一次")
                }
            }
        }

        item("header") {
            Surface(
                shape = RoundedCornerShape(30.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                Row(
                    Modifier.padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        val name = ui.settings.nickname.ifBlank { "宝宝" }
                        Text("$name 的成长册", style = MaterialTheme.typography.headlineMedium)
                        Text(
                            if (ui.settings.birth != null) {
                                "从 ${ui.settings.birth} 到今天 · 共走过 ${currentMonth + 1} 站"
                            } else {
                                "按月留存做过的游戏、第一次、身高体重与日常照护"
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                    Spacer(Modifier.width(10.dp))
                    HuggedAvatar(
                        month = currentMonth,
                        girl = ui.settings.drawsGirl,
                        companion = ui.settings.companion,
                        size = 80.dp,
                    )
                }
            }
        }

        items(monthsToShow, key = { "book-m-$it" }) { m ->
            val guide = content.month(m) ?: return@items
            MonthAlbumPage(
                ui = ui,
                guide = guide,
                month = m,
                onOpenMonth = { openMonth(m) },
                onOpenPlay = { code -> openPlay(code, m) },
            )
        }

        item("footer") {
            StoryGoesOn(month = currentMonth, companion = ui.settings.companion)
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun MonthAlbumPage(
    ui: AppUi,
    guide: MonthGuide,
    month: Int,
    onOpenMonth: () -> Unit,
    onOpenPlay: (String) -> Unit,
) {
    val content = ui.content ?: return
    val ctx = LocalContext.current
    val cover = remember(month) { ArtIndex.cover(ctx, month) }
    val zone = ZoneId.systemDefault()
    val birth = ui.settings.birth

    val spanStart = birth?.plusMonths(month.toLong())
    val spanEnd = birth?.plusMonths((month + 1).toLong())
    val startMs = spanStart?.atStartOfDay(zone)?.toInstant()?.toEpochMilli()
    val endMs = spanEnd?.atStartOfDay(zone)?.toInstant()?.toEpochMilli()

    val played = remember(ui.ticks, ui.allLogs, birth, month) {
        playedInMonth(content, ui.ticks, ui.allLogs, birth, month, zone)
    }
    val observed = remember(ui.ticks, month) {
        ui.ticks.values.filter { it.month == month && it.kind == TickKind.Observed }.map { it.label }
    }
    val monthFirsts = remember(ui.firsts, startMs, endMs, month) {
        if (startMs != null && endMs != null) {
            ui.firsts.filter { it.at in startMs until endMs }
        } else if (month == 0) ui.firsts else emptyList()
    }
    val monthMeasure = remember(ui.measures, startMs, endMs, month) {
        if (startMs != null && endMs != null) {
            ui.measures.filter { it.at in startMs until endMs }.maxByOrNull { it.at }
        } else if (month == 0) ui.measures.maxByOrNull { it.at } else null
    }
    val monthLogs = remember(ui.allLogs, startMs, endMs) {
        if (startMs != null && endMs != null) {
            ui.allLogs.filter { it.start in startMs until endMs }
        } else emptyList()
    }

    Plate(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        onClick = onOpenMonth,
    ) {
        // Month header
        Row(verticalAlignment = Alignment.CenterVertically) {
            SandpaperNumber("$month", MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text("满 $month 个月 · ${guide.title}", style = MaterialTheme.typography.titleMedium)
                if (spanStart != null && spanEnd != null) {
                    Text(
                        "${spanStart.year}.${spanStart.monthValue}.${spanStart.dayOfMonth} — ${spanEnd.year}.${spanEnd.monthValue}.${spanEnd.dayOfMonth}",
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Text("详情 →", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
        }

        // Taped cover photo
        if (cover != null) {
            Spacer(Modifier.height(14.dp))
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
                Art(
                    name = cover,
                    label = "满 $month 个月：${guide.title}",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 6.dp)
                        .clip(RoundedCornerShape(20.dp)),
                )
                // Paper masking tape strip across top center
                Box(
                    Modifier
                        .width(68.dp)
                        .height(16.dp)
                        .offset(y = 0.dp)
                        .graphicsLayer { rotationZ = if (month % 2 == 0) -2.5f else 2.5f }
                        .background(Palette.BeadLight.copy(alpha = 0.65f), RoundedCornerShape(3.dp))
                )
            }
        }

        // 1. Firsts in this month
        if (monthFirsts.isNotEmpty()) {
            Spacer(Modifier.height(14.dp))
            SectionSubhead("ic_heart_fill.webp", "第一次")
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                monthFirsts.forEach { f ->
                    FirstRowChip(f, zone)
                }
            }
        }

        // 2. Played activities with tray illustrations
        if (played.isNotEmpty()) {
            Spacer(Modifier.height(14.dp))
            SectionSubhead("ic_puzzlepiece_fill.webp", "一起玩过 (${played.size})")
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                played.forEach { (p, count) ->
                    PlayMemoryChip(p, count) { onOpenPlay(p.code) }
                }
            }
        }

        // 3. Growth measurement in this month
        if (monthMeasure != null) {
            Spacer(Modifier.height(14.dp))
            SectionSubhead("ic_ruler_fill.webp", "生长测量")
            MeasureMemoryStrip(monthMeasure)
        }

        // 4. Daily average care stats in this month
        if (monthLogs.isNotEmpty()) {
            val careSummary = remember(monthLogs) { computeCareSummary(monthLogs, zone) }
            if (careSummary != null) {
                Spacer(Modifier.height(14.dp))
                SectionSubhead("ic_moon_zzz_fill.webp", "日常照护（记录日平均）")
                Text(
                    careSummary,
                    fontFamily = Numerals,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // 5. Observed items in this month
        if (observed.isNotEmpty()) {
            Spacer(Modifier.height(14.dp))
            SectionSubhead("ic_eye_fill.webp", "留意到的变化 (${observed.size})")
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                observed.take(5).forEach { item ->
                    Text("· $item", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (observed.size > 5) {
                    Text("还有 ${observed.size - 5} 项…", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                }
            }
        }

        if (monthFirsts.isEmpty() && played.isEmpty() && monthMeasure == null && monthLogs.isEmpty() && observed.isEmpty()) {
            Spacer(Modifier.height(10.dp))
            Text(
                "这一站还没有留下记录；点进来可以看看这个月玩什么、留意什么。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SectionSubhead(sticker: String, title: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(bottom = 6.dp),
    ) {
        Sticker(sticker, size = 18.dp)
        Spacer(Modifier.width(6.dp))
        Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
private fun FirstRowChip(f: First, zone: ZoneId) {
    val d = Instant.ofEpochMilli(f.at).atZone(zone).toLocalDate()
    Surface(
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(f.title, style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
                Text(
                    "${d.monthValue}月${d.dayOfMonth}日",
                    fontFamily = Numerals,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (!f.note.isNullOrBlank()) {
                Text(f.note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun PlayMemoryChip(play: Play, count: Int, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
    ) {
        Row(
            Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            TrayArt(play.code, size = 32.dp)
            Text(play.name, style = MaterialTheme.typography.bodySmall)
            if (count > 1) {
                Text(
                    "×$count",
                    fontFamily = Numerals,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun MeasureMemoryStrip(m: Measure) {
    val parts = listOfNotNull(
        m.weightG?.let { "体重 ${"%.2f".format(it / 1000.0)} kg" },
        m.lengthMm?.let { "身长 ${"%.1f".format(it / 10.0)} cm" },
        m.headMm?.let { "头围 ${"%.1f".format(it / 10.0)} cm" },
    )
    Text(
        parts.joinToString("  ·  "),
        fontFamily = Numerals,
        style = MaterialTheme.typography.bodyMedium,
    )
}

private fun computeCareSummary(logs: List<LogEntry>, zone: ZoneId): String? {
    val byDay = logs.groupBy { Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate() }
    if (byDay.isEmpty()) return null
    val feedCounts = byDay.values.map { d -> d.count { it.type == LogType.Nurse || it.type == LogType.Bottle } }.filter { it > 0 }
    val sleepHours = byDay.values.map { d ->
        d.filter { it.type == LogType.Sleep && it.end != null }.sumOf { (it.end!! - it.start).coerceAtLeast(0) } / 3_600_000.0
    }.filter { it > 0.1 }
    val diaperCounts = byDay.values.map { d -> d.count { it.type == LogType.Diaper } }.filter { it > 0 }
    val parts = buildList {
        if (sleepHours.isNotEmpty()) add("日均睡眠 ${"%.1f".format(sleepHours.average())} 小时")
        if (feedCounts.isNotEmpty()) add("喂养 ${Math.round(feedCounts.average())} 次/天")
        if (diaperCounts.isNotEmpty()) add("尿布 ${Math.round(diaperCounts.average())} 片/天")
    }
    return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
}
