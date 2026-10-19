package app.mossling.ui.grow

import androidx.compose.ui.platform.testTag
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.Month
import app.mossling.data.Play
import app.mossling.data.TickKind
import app.mossling.ui.components.BeadChain
import app.mossling.ui.components.Plate
import app.mossling.ui.components.shared
import app.mossling.ui.components.SandpaperNumber
import app.mossling.ui.components.Shelf
import app.mossling.ui.components.ColorTablet
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.areaColor
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Kind
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette

data class GrowActions(
    val select: (Int) -> Unit = {},
    val openPlay: (String, Int) -> Unit = { _, _ -> },
    val tick: (Int, String, String, String) -> Unit = { _, _, _, _ -> },
)

@Composable
fun GrowScreen(ui: AppUi, month: Int, a: GrowActions, modifier: Modifier = Modifier) {
    val c = ui.content ?: return
    val baby = ui.babyMonth
    val companion = LocalCompanion.current
    Column(modifier.fillMaxSize()) {
        Column(Modifier.fillMaxWidth().statusBarsPadding().padding(top = 8.dp)) {
            Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                AnimatedContent(month, transitionSpec = {
                    val dir = if (targetState > initialState) 1 else -1
                    (slideInHorizontally(tween(220)) { dir * it / 3 } + fadeIn(tween(220))) togetherWith (slideOutHorizontally(tween(180)) { -dir * it / 3 } + fadeOut(tween(160)))
                }, label = "month", modifier = Modifier.weight(1f)) { m ->
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            SandpaperNumber("$m", MaterialTheme.typography.displayMedium)
                            Text("  个月", style = MaterialTheme.typography.titleLarge)
                        }
                        Text(c.month(m).title, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                }
                val look = when { baby == null -> Offset.Zero; month < baby -> Offset(-0.9f, 0.1f); month > baby -> Offset(0.9f, 0.1f); else -> Offset(0f, 0.6f) }
                Box(contentAlignment = Alignment.Center) {
                    Creature(companion, Modifier.size(72.dp), look = look)
                }
            }
            if (baby != null) {
                Row(Modifier.padding(horizontal = 20.dp, vertical = 6.dp)) {
                    val text = when { month == baby -> "宝宝现在在这里"; month < baby -> "以前的月份"; else -> "以后的月份" }
                    AssistChip(onClick = { a.select(baby) }, label = { Text(if (month == baby) text else "$text · 回到满 $baby 个月") })
                }
            }
            BeadChain(month, baby, a.select)
        }
        key(month) {
            MonthBody(ui, c.month(month), month, a, companion) { c.play(it) }
        }
    }
}

@Composable
private fun MonthBody(ui: AppUi, mo: Month, m: Int, a: GrowActions, companion: Kind, play: (String) -> Play?) {
    val list = rememberLazyListState()
    LazyColumn(state = list, contentPadding = PaddingValues(bottom = 40.dp), modifier = Modifier.fillMaxSize().testTag("grow")) {
        item("hi") {
            Column(Modifier.padding(horizontal = 20.dp).padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                mo.highlights.forEach { h ->
                    Row {
                        Text(h.kind.take(4), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary, modifier = Modifier.width(72.dp).padding(top = 3.dp))
                        Text(h.text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                    }
                }
            }
        }
        val plays = (listOfNotNull(mo.feature) + mo.activities).distinct().mapNotNull(play)
        if (plays.isNotEmpty()) item("plays") {
            SectionTitle("这个月玩什么", kicker = "${plays.size} 个游戏")
            Shelf(Modifier.fillMaxWidth()) {
                LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(plays, key = { it.code }) { p -> PlayCard(p, ui.ticked(m, TickKind.Did, p.code), companion) { a.openPlay(p.code, m) } }
                }
            }
        }
        item("areas") {
            SectionTitle("六个方面", kicker = "家里可以这样做")
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                mo.domains.forEach { d ->
                    Plate(Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            ColorTablet(areaColor(d.key))
                            Spacer(Modifier.width(10.dp))
                            Text(d.name, style = MaterialTheme.typography.titleSmall, color = areaColor(d.key))
                            if (d.key == mo.focus) { Spacer(Modifier.width(8.dp)); Text("本月重点", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.tertiary) }
                        }
                        Text(d.text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 8.dp))
                    }
                }
            }
        }
        if (mo.observe.isNotEmpty()) item("observe") {
            SectionTitle("可以留意", kicker = "看到了就勾上，不是考核")
            Column(Modifier.padding(horizontal = 12.dp)) {
                mo.observe.forEachIndexed { gi, g ->
                    Text(g.area, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 8.dp, top = 12.dp, bottom = 2.dp))
                    g.items.forEachIndexed { ii, t ->
                        val id = "$gi-$ii"
                        CheckRow(t, ui.ticked(m, TickKind.Observed, id)) { a.tick(m, TickKind.Observed, id, t) }
                    }
                }
            }
        }
        if (mo.vaccines.isNotEmpty() || mo.checkups.isNotEmpty()) item("care") {
            SectionTitle("接种与儿保", kicker = "打过、做过的才勾")
            Column(Modifier.padding(horizontal = 12.dp)) {
                mo.vaccines.forEachIndexed { i, t -> CheckRow(t, ui.ticked(m, TickKind.Vaccine, "$i"), tag = "接种") { a.tick(m, TickKind.Vaccine, "$i", t) } }
                mo.checkups.forEachIndexed { i, t -> CheckRow(t, ui.ticked(m, TickKind.Checkup, "$i"), tag = "儿保") { a.tick(m, TickKind.Checkup, "$i", t) } }
            }
        }
        if (mo.notes.isNotEmpty()) item("notes") {
            SectionTitle("这个月还要知道", kicker = null)
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                mo.notes.forEach { n ->
                    Plate(Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                        Text(n.topic, style = MaterialTheme.typography.titleSmall)
                        Text(n.text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 6.dp))
                    }
                }
            }
        }
        if (mo.who.isNotBlank()) item("who") {
            SectionTitle("一天的节奏", kicker = "睡眠、活动与屏幕")
            Text(mo.who, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(horizontal = 20.dp))
        }
    }
}

@Composable
private fun PlayCard(p: Play, did: Boolean, companion: Kind, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(26.dp), color = MaterialTheme.colorScheme.surfaceContainerLowest, modifier = Modifier.width(220.dp)) {
        Column(Modifier.padding(16.dp)) {
            app.mossling.ui.ip.MaterialStill(app.mossling.ui.ip.Family.of(p.domains), Modifier.fillMaxWidth().padding(bottom = 10.dp).clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surfaceContainer))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(shape = RoundedCornerShape(12.dp), color = if (companion == Kind.Moss) Palette.Moss else Palette.Rod, modifier = Modifier.shared("code-${p.code}")) {
                    Text(p.code, fontFamily = Numerals, style = MaterialTheme.typography.titleLarge, color = Palette.Paper, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp))
                }
                Spacer(Modifier.weight(1f))
                if (did) Text("做过", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
            }
            Text(p.name, style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 12.dp), maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(p.age, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun CheckRow(text: String, on: Boolean, tag: String? = null, onToggle: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(RoundedCornerShape(16.dp)).clickable(role = Role.Checkbox, onClick = onToggle).padding(end = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Checkbox(checked = on, onCheckedChange = { onToggle() })
        Column(Modifier.weight(1f)) {
            if (tag != null) Text(tag, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
            Text(text, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
