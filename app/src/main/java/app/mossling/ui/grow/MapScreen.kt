package app.mossling.ui.grow

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.MonthGuide
import app.mossling.data.TickKind
import app.mossling.ui.components.Art
import app.mossling.ui.components.ArtIndex
import app.mossling.ui.components.NumberRod
import app.mossling.ui.components.SandpaperNumber
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.GrowingChild
import app.mossling.ui.ip.Mood
import app.mossling.ui.ip.StoryGoesOn
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import app.mossling.ui.you.Bar

/**
 * The whole first three years on one screen: 37 stations from birth to three, grouped into the seven stages the
 * child figure grows through.
 */
@Composable
fun MapScreen(ui: AppUi, open: (Int) -> Unit, onBack: () -> Unit) {
    val c = ui.content ?: return
    val here = ui.age?.bookMonth
    val stages = listOf(
        Triple("0–2 个月", "刚来的时候 · 看黑白、趴一会儿、听你说话", 0..2),
        Triple("3–5 个月", "抬起头看世界 · 翻身、够东西、笑出声", 3..5),
        Triple("6–8 个月", "坐起来空出双手 · 换手、尝第一口辅食、找藏起的东西", 6..8),
        Triple("9–11 个月", "自己去想去的地方 · 爬、扶站、捏小东西、指给你看", 9..11),
        Triple("12–17 个月", "迈出第一步 · 走、投进拿出、说出第一个词", 12..17),
        Triple("18–23 个月", "我来 · 叠高、配对、把两个词连在一起", 18..23),
        Triple("24–36 个月", "讲自己的事 · 跑跳、假装游戏、自己穿脱与收拾", 24..36),
    )
    val startIndex = remember(here) {
        if (here == null) 0 else 2 + stages.takeWhile { here !in it.third }.sumOf { 1 + it.third.count() }
    }
    val state = rememberLazyListState(initialFirstVisibleItemIndex = startIndex)
    val totalPlays = ui.ticks.values.count { it.kind == TickKind.Did }
    val totalWatch = ui.ticks.values.count { it.kind == TickKind.Observed }

    LazyColumn(Modifier.fillMaxSize(), state = state, contentPadding = PaddingValues(bottom = 48.dp)) {
        item { Bar("成长地图 · 0–36 个月", onBack) }
        item {
            Surface(
                shape = RoundedCornerShape(28.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            if (here != null) "现在在第 $here 站 · 共 37 站" else "出生到满 3 岁 · 共 37 站",
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text(
                            if (totalPlays + totalWatch > 0) "一路记下 $totalPlays 个玩法 · $totalWatch 项留意" else "点任一站都能翻看那个月玩什么、留意什么",
                            fontFamily = Numerals,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                    Creature(ui.settings.companion, Modifier.size(64.dp), mood = Mood.Happy)
                }
            }
        }
        stages.forEach { (title, sub, range) ->
            item(key = "stage-$title") {
                Row(
                    Modifier.fillMaxWidth().padding(start = 8.dp, end = 20.dp, top = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SectionTitle(title, kicker = sub, modifier = Modifier.weight(1f))
                    GrowingChild(month = range.first, modifier = Modifier.size(64.dp))
                }
            }
            items(range.toList(), key = { "m-$it" }) { m ->
                val g = c.month(m) ?: return@items
                val plays = c.playsSplit(m).first
                val did = ui.ticks.values.count { it.month == m && it.kind == TickKind.Did }
                val obsTotal = g.observe.sumOf { it.items.size }
                val obsDone = ui.ticks.values.count { it.month == m && it.kind == TickKind.Observed }
                StationCard(
                    g = g,
                    here = m == here,
                    past = here != null && m < here,
                    playsDone = did,
                    playsTotal = plays.size,
                    obsDone = obsDone,
                    obsTotal = obsTotal,
                    birth = ui.settings.birth?.plusMonths(m.toLong()),
                ) { open(m) }
            }
        }
        item("story-goes-on") {
            StoryGoesOn(month = here ?: 6, companion = ui.settings.companion)
        }
    }
}

@Composable
private fun StationCard(
    g: MonthGuide,
    here: Boolean,
    past: Boolean,
    playsDone: Int,
    playsTotal: Int,
    obsDone: Int,
    obsTotal: Int,
    birth: java.time.LocalDate?,
    onClick: () -> Unit,
) {
    val ctx = LocalContext.current
    val cover = remember(g.month) { ArtIndex.cover(ctx, g.month) }
    val border = if (here) BorderStroke(2.dp, Palette.Bead) else null
    val bg = when {
        here -> MaterialTheme.colorScheme.surfaceContainerHighest
        past -> MaterialTheme.colorScheme.surfaceContainerLow
        else -> MaterialTheme.colorScheme.surfaceContainerLowest
    }
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(24.dp),
        color = bg,
        border = border,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 5.dp),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            if (cover != null) {
                Art(
                    cover,
                    label = "满 ${g.month} 个月",
                    modifier = Modifier.size(width = 88.dp, height = 66.dp).clip(RoundedCornerShape(16.dp)),
                )
            } else {
                SandpaperNumber("${g.month}", MaterialTheme.typography.headlineSmall)
            }
            Column(Modifier.weight(1f).padding(start = 14.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        "满 ${g.month} 个月",
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.labelLarge,
                        color = if (here) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    birth?.let {
                        Text(
                            "· ${it.year}.${it.monthValue}",
                            fontFamily = Numerals,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (here) {
                        Box(Modifier.size(8.dp).background(Palette.Bead, CircleShape))
                        Text("现在", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                    }
                }
                Text(g.title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 2.dp))
                if (playsDone > 0 || obsDone > 0) {
                    Spacer(Modifier.height(6.dp))
                    NumberRod(playsDone + obsDone, (playsTotal + obsTotal).coerceAtLeast(1), height = 8.dp)
                    Text(
                        "玩过 $playsDone/$playsTotal · 留意 $obsDone/$obsTotal",
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
        }
    }
}
