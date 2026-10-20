package app.mossling.ui.plan

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.LogEntry
import app.mossling.data.Play
import app.mossling.domain.Shelf
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.Shelf as WoodShelf
import app.mossling.ui.ip.Family
import app.mossling.ui.ip.MaterialStill
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import app.mossling.ui.you.Bar
import java.time.LocalDate

data class PlanActions(
    val back: () -> Unit = {},
    val set: (List<String>) -> Unit = {},
    val openPlay: (String) -> Unit = {},
)

/**
 * Planning the week, the way a Montessori guide prepares a room: watch what the child is working on, choose a few
 * materials that fit, set them out, let the child repeat them, and rotate when interest moves on. The shelf holds at
 * most four. Each play counts how many times it was done this week (from the journal).
 */
@Composable
fun PlanScreen(ui: AppUi, week: List<LogEntry>, a: PlanActions) {
    val c = ui.content ?: return
    val m = ui.babyMonth ?: 0
    val (shelf, stale) = Shelf.current(c, m, ui.settings.shelf, ui.today)
    val codes = shelf.map { it.code }
    val monday = Shelf.weekOf(ui.today)
    fun times(code: String) = week.count { it.type == app.mossling.data.LogType.Play && it.detail?.startsWith(code) == true }
    val candidates = Shelf.candidates(c, m).filter { it.code !in codes }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 48.dp)) {
        item { Bar("", a.back) }
        item {
            Column(Modifier.padding(horizontal = 20.dp)) {
                Text("本周的架子", style = MaterialTheme.typography.headlineLarge)
                Text("${monday.monthValue}月${monday.dayOfMonth}日 — ${monday.plusDays(6).monthValue}月${monday.plusDays(6).dayOfMonth}日 · 满 $m 个月",
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (stale) item {
            Surface(shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.tertiaryContainer, modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                Column(Modifier.padding(16.dp)) {
                    Text("新的一周", style = MaterialTheme.typography.titleMedium)
                    Text("架子上还是上周的玩法。孩子还在反复做的可以留着，不再感兴趣的换下来。", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 4.dp))
                    Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { a.set(Shelf.suggest(c, m, codes)) }, shape = RoundedCornerShape(16.dp)) { Text("按建议轮换") }
                        TextButton(onClick = { a.set(codes) }) { Text("这周继续用") }
                    }
                }
            }
        }
        item {
            SectionTitle("架子上", kicker = "${shelf.size} / ${Shelf.Max} 件")
            WoodShelf(Modifier.fillMaxWidth()) {
                LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(shelf, key = { it.code }) { p ->
                        Slot(p, times(p.code), onOpen = { a.openPlay(p.code) }, onRemove = if (shelf.size > 1) ({ a.set(codes - p.code) }) else null)
                    }
                }
            }
        }
        item {
            SectionTitle("怎么用这个架子", kicker = "观察 · 准备 · 示范 · 重复 · 轮换")
            Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Step("1", "观察", "先看孩子这几天在反复做什么：抓、放、扔、看、发声，还是走来走去。")
                Step("2", "准备", "把架子上的东西放在孩子够得着、看得见的地方，一件一个位置，用完放回原处。")
                Step("3", "示范", "慢慢做一遍，少说话，让孩子看清楚每一个动作。")
                Step("4", "重复", "孩子想做几遍就做几遍，不打断、不催促；累了、转头、烦躁时就停。")
                Step("5", "轮换", "一周左右换一次。还在用的留着，不感兴趣的收起来，过一阵再拿出来。")
            }
        }
        if (candidates.isNotEmpty()) item {
            SectionTitle("也适合这个月", kicker = "${candidates.size} 个，点「放上架」")
        }
        items(candidates, key = { "c" + it.code }) { p ->
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                MaterialStill(Family.of(p.domains), Modifier.width(80.dp), ground = MaterialTheme.colorScheme.surfaceContainerHigh)
                Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                    Text(p.code, fontFamily = Numerals, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                    Text(p.name, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Text(p.age, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                FilledTonalButton(onClick = { a.set(codes + p.code) }, enabled = shelf.size < Shelf.Max, modifier = Modifier.heightIn(min = 48.dp)) { Text("放上架") }
            }
        }
    }
}

@Composable
private fun Step(n: String, title: String, text: String) {
    Row {
        Text(n, fontFamily = Numerals, style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.tertiary, modifier = Modifier.width(32.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(text, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun Slot(p: Play, times: Int, onOpen: () -> Unit, onRemove: (() -> Unit)?) {
    val companion = LocalCompanion.current
    Surface(onClick = onOpen, shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLowest, modifier = Modifier.width(200.dp)) {
        Column(Modifier.padding(14.dp)) {
            MaterialStill(Family.of(p.domains), Modifier.fillMaxWidth(), ground = MaterialTheme.colorScheme.surfaceContainerHigh)
            Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Surface(shape = RoundedCornerShape(10.dp), color = if (companion == app.mossling.ui.ip.Kind.Moss) Palette.Moss else Palette.Rod) {
                    Text(p.code, fontFamily = Numerals, style = MaterialTheme.typography.titleMedium, color = Palette.Paper, modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp))
                }
                Spacer(Modifier.weight(1f))
                if (onRemove != null) IconButton(onClick = onRemove, modifier = Modifier.semantics { contentDescription = "从架子上拿下来" }) { Glyph(G.Close, size = 18.dp) }
            }
            Text(p.name, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 6.dp))
            Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                repeat(7) { i -> Surface(shape = RoundedCornerShape(50), color = if (i < times) Palette.Bead else MaterialTheme.colorScheme.outlineVariant, modifier = Modifier.padding(end = 3.dp).size(10.dp)) {} }
                Text(if (times == 0) "这周还没做" else "这周做过 $times 次", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 4.dp))
            }
        }
    }
}
