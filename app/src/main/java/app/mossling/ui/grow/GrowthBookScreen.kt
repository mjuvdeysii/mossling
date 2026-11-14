package app.mossling.ui.grow

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
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
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SandpaperNumber
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.areaColor
import app.mossling.ui.components.areaGlyph
import app.mossling.ui.ip.HuggedAvatar
import app.mossling.ui.ip.StoryGoesOn
import app.mossling.ui.theme.Numerals
import app.mossling.ui.you.Bar
import java.time.Instant
import java.time.ZoneId

/**
 * The Growth Book ("成长册"):
 * A month-by-month keepsake album (newest lived month first) combining:
 * - Month cover illustration & date span
 * - "第一次" milestones recorded in that month
 * - Plays done in that month with domain badges & counts
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
    val zone = ZoneId.systemDefault()
    val birth = ui.settings.birth
    val allMonths = remember(currentMonth, ui.ticks) {
        val maxTickMonth = ui.ticks.values.maxOfOrNull { it.month } ?: 0
        val top = maxOf(currentMonth, maxTickMonth).coerceIn(0, 36)
        (top downTo 0).toList()
    }
    val recordedMonths = remember(allMonths, ui.ticks, ui.allLogs, ui.firsts, ui.measures, birth) {
        allMonths.filterTo(mutableSetOf()) { m ->
            val startMs = birth?.plusMonths(m.toLong())?.atStartOfDay(zone)?.toInstant()?.toEpochMilli()
            val endMs = birth?.plusMonths((m + 1).toLong())?.atStartOfDay(zone)?.toInstant()?.toEpochMilli()
            val hasPlay = playedInMonth(content, ui.ticks, ui.allLogs, birth, m, zone).isNotEmpty()
            val hasObs = ui.ticks.values.any { it.month == m && it.kind == TickKind.Observed }
            val hasFirst = if (startMs != null && endMs != null) ui.firsts.any { it.at in startMs until endMs } else m == 0 && ui.firsts.isNotEmpty()
            val hasMeas = if (startMs != null && endMs != null) ui.measures.any { it.at in startMs until endMs } else m == 0 && ui.measures.isNotEmpty()
            val hasLogs = if (startMs != null && endMs != null) ui.allLogs.any { it.start in startMs until endMs } else false
            hasPlay || hasObs || hasFirst || hasMeas || hasLogs
        }
    }
    var onlyRecorded by rememberSaveable { mutableStateOf(false) }
    var pagerMode by rememberSaveable { mutableStateOf(true) }
    val monthsToShow = remember(allMonths, recordedMonths, onlyRecorded) {
        if (onlyRecorded && recordedMonths.isNotEmpty()) allMonths.filter { it in recordedMonths } else allMonths
    }
    val listState = rememberLazyListState()
    val jumpRowState = rememberLazyListState()
    val pagerState = rememberPagerState(pageCount = { monthsToShow.size.coerceAtLeast(1) })
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val hasControls = allMonths.size > 1 || recordedMonths.isNotEmpty()
    val effectivePagerMode = pagerMode && monthsToShow.size > 1

    LaunchedEffect(monthsToShow) {
        val maxPage = (monthsToShow.size - 1).coerceAtLeast(0)
        if (pagerState.currentPage > maxPage) {
            pagerState.scrollToPage(maxPage)
        }
    }

    LaunchedEffect(pagerState.currentPage, effectivePagerMode, monthsToShow) {
        if (effectivePagerMode && monthsToShow.size > 1) {
            val offset = if (recordedMonths.isNotEmpty()) 1 else 0
            jumpRowState.animateScrollToItem((pagerState.currentPage + offset).coerceAtLeast(0))
        }
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        state = listState,
        contentPadding = PaddingValues(bottom = 56.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item("bar") {
            Bar("成长册", onBack) {
                TextButton(onClick = openFirsts) { Text("记第一次") }
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

        if (monthsToShow.size > 1) {
            item("mode-switch") {
                SingleChoiceSegmentedButtonRow(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                ) {
                    val modes = listOf("按月翻页" to true, "时间轴 (${monthsToShow.size})" to false)
                    modes.forEachIndexed { idx, (label, isPager) ->
                        SegmentedButton(
                            selected = pagerMode == isPager,
                            onClick = {
                                if (pagerMode != isPager) {
                                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    pagerMode = isPager
                                }
                            },
                            shape = SegmentedButtonDefaults.itemShape(index = idx, count = modes.size),
                            label = { Text(label, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        )
                    }
                }
            }
        }

        if (hasControls) {
            item("controls") {
                LazyRow(
                    state = jumpRowState,
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    if (recordedMonths.isNotEmpty()) {
                        item("filter-recorded") {
                            FilterChip(
                                selected = onlyRecorded,
                                onClick = {
                                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    onlyRecorded = !onlyRecorded
                                },
                                label = { Text("仅看有记录 (${recordedMonths.size})") },
                            )
                        }
                    }
                    if (monthsToShow.size > 1) {
                        itemsIndexed(monthsToShow, key = { _, m -> "jump-$m" }) { idx, m ->
                            val selected = effectivePagerMode && pagerState.currentPage == idx
                            FilterChip(
                                selected = selected,
                                onClick = {
                                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    if (effectivePagerMode) {
                                        scope.launch { pagerState.animateScrollToPage(idx) }
                                    } else {
                                        val prefixItems = 2 + (if (monthsToShow.size > 1) 1 else 0) + (if (hasControls) 1 else 0)
                                        scope.launch { listState.animateScrollToItem(idx + prefixItems) }
                                    }
                                },
                                label = { Text("满 ${m} 月") },
                            )
                        }
                    }
                }
            }
        }

        if (effectivePagerMode) {
            item("book-pager") {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        val activeMonth = monthsToShow.getOrElse(pagerState.currentPage) { currentMonth }
                        Text(
                            "第 ${pagerState.currentPage + 1} / ${monthsToShow.size} 页 · 满 $activeMonth 个月",
                            fontFamily = Numerals,
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f),
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Surface(
                                onClick = {
                                    if (pagerState.currentPage > 0) {
                                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage - 1) }
                                    }
                                },
                                enabled = pagerState.currentPage > 0,
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = if (pagerState.currentPage > 0) 1f else 0.35f),
                                modifier = Modifier.size(34.dp).semantics { contentDescription = "上一页" },
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Glyph(
                                        G.Back,
                                        size = 16.dp,
                                        color = if (pagerState.currentPage > 0) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.outline,
                                    )
                                }
                            }
                            Surface(
                                onClick = {
                                    if (pagerState.currentPage < monthsToShow.lastIndex) {
                                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                                    }
                                },
                                enabled = pagerState.currentPage < monthsToShow.lastIndex,
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = if (pagerState.currentPage < monthsToShow.lastIndex) 1f else 0.35f),
                                modifier = Modifier.size(34.dp).semantics { contentDescription = "下一页" },
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Glyph(
                                        G.Back,
                                        size = 16.dp,
                                        color = if (pagerState.currentPage < monthsToShow.lastIndex) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.outline,
                                        modifier = Modifier.graphicsLayer { rotationZ = 180f },
                                    )
                                }
                            }
                        }
                    }

                    HorizontalPager(
                        state = pagerState,
                        contentPadding = PaddingValues(horizontal = 16.dp),
                        pageSpacing = 12.dp,
                        verticalAlignment = Alignment.Top,
                        modifier = Modifier.fillMaxWidth(),
                    ) { page ->
                        val m = monthsToShow.getOrNull(page) ?: return@HorizontalPager
                        val guide = content.month(m) ?: return@HorizontalPager
                        MonthAlbumPage(
                            ui = ui,
                            guide = guide,
                            month = m,
                            onOpenMonth = { openMonth(m) },
                            onOpenPlay = { code -> openPlay(code, m) },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        } else {
            itemsIndexed(monthsToShow, key = { _, m -> "book-m-$m" }) { _, m ->
                val guide = content.month(m) ?: return@itemsIndexed
                MonthAlbumPage(
                    ui = ui,
                    guide = guide,
                    month = m,
                    onOpenMonth = { openMonth(m) },
                    onOpenPlay = { code -> openPlay(code, m) },
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).animateItem(),
                )
            }
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
    modifier: Modifier = Modifier,
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
        modifier = modifier,
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
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.secondaryContainer,
            ) {
                Text(
                    "月龄详情",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                )
            }
        }

        // Cover illustration
        if (cover != null) {
            Spacer(Modifier.height(14.dp))
            Art(
                name = cover,
                label = "满 $month 个月：${guide.title}",
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp)),
            )
        }

        // 1. Firsts in this month
        if (monthFirsts.isNotEmpty()) {
            Spacer(Modifier.height(14.dp))
            SectionSubhead(G.Heart, "第一次")
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                monthFirsts.forEach { f ->
                    FirstRowChip(f, zone)
                }
            }
        }

        // 2. Played activities with domain badges
        if (played.isNotEmpty()) {
            Spacer(Modifier.height(14.dp))
            SectionSubhead(G.Play, "一起玩过 (${played.size})")
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
            SectionSubhead(G.Ruler, "生长测量")
            MeasureMemoryStrip(monthMeasure)
        }

        // 4. Daily average care stats in this month
        if (monthLogs.isNotEmpty()) {
            val careSummary = remember(monthLogs) { computeCareSummary(monthLogs, zone) }
            if (careSummary != null) {
                Spacer(Modifier.height(14.dp))
                SectionSubhead(G.Moon, "日常照护（记录日平均）")
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
            SectionSubhead(G.Eye, "留意到的变化 (${observed.size})")
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
private fun SectionSubhead(glyph: G, title: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(bottom = 6.dp),
    ) {
        Glyph(glyph, size = 18.dp, color = MaterialTheme.colorScheme.primary)
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
            val d0 = play.domains.firstOrNull() ?: "A"
            val dc = areaColor(d0)
            ShapeBadge(areaGlyph(d0), dc.copy(alpha = 0.16f), dc, shape = Shapes.of(play.code), size = 28.dp)
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
