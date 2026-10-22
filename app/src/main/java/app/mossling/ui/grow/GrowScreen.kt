package app.mossling.ui.grow

import app.mossling.ui.components.Glyph
import app.mossling.ui.components.G
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.material3.TextButton
import androidx.compose.material3.IconButton
import androidx.compose.foundation.horizontalScroll
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
    val openMap: () -> Unit = {},
    val openPlan: () -> Unit = {},
    val openGrowth: () -> Unit = {},
)

/**
 * Browsing the months. Its own job only: the month's picture and title, the chain to move between months, then
 * what the month holds. The child's age, the companion and the week's shelf belong to Today and are not repeated here.
 */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun GrowScreen(ui: AppUi, month: Int, a: GrowActions, modifier: Modifier = Modifier) {
    val c = ui.content ?: return
    val baby = ui.babyMonth
    val companion = LocalCompanion.current
    val mo = c.month(month)
    val m = month
    val play: (String) -> Play? = { c.play(it) }
    val list = rememberLazyListState()
    LazyColumn(state = list, contentPadding = PaddingValues(bottom = 40.dp), modifier = modifier.fillMaxSize().testTag("grow")) {
        item("cover") {
            val ctx = androidx.compose.ui.platform.LocalContext.current
            AnimatedContent(month, transitionSpec = {
                val dir = if (targetState > initialState) 1 else -1
                (slideInHorizontally(tween(240)) { dir * it / 4 } + fadeIn(tween(240))) togetherWith (slideOutHorizontally(tween(200)) { -dir * it / 4 } + fadeOut(tween(160)))
            }, label = "month", modifier = Modifier.fillMaxWidth().statusBarsPadding().padding(top = 8.dp)) { mm ->
                Column(Modifier.padding(horizontal = 16.dp)) {
                    androidx.compose.runtime.remember(mm) { app.mossling.ui.components.ArtIndex.cover(ctx, mm) }?.let { f ->
                        app.mossling.ui.components.Art(f, "满 $mm 个月：${c.month(mm).title}", Modifier.fillMaxWidth().clip(RoundedCornerShape(32.dp)))
                    }
                    Row(Modifier.padding(top = 12.dp, start = 4.dp), verticalAlignment = Alignment.Bottom) {
                        Text("$mm", fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.primary)
                        Text(" 个月", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 6.dp))
                        if (baby != null && mm != baby) Text(if (mm < baby) " · 以前的月份" else " · 以后的月份", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(bottom = 8.dp))
                    }
                    Text(c.month(mm).title, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(start = 4.dp))
                }
            }
        }
        // the chain stays at the top while the month is read
        stickyHeader("chain") {
            Surface(color = MaterialTheme.colorScheme.background) {
                Row(Modifier.fillMaxWidth().padding(start = 4.dp, end = 4.dp, top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    BeadChain(month, baby, a.select, Modifier.weight(1f))
                    IconButton(onClick = a.openMap, modifier = Modifier.semantics { contentDescription = "成长地图" }) { Glyph(G.Walk, size = 22.dp) }
                }
            }
        }
        if (baby != null && month != baby) item("back") {
            TextButton(onClick = { a.select(baby) }, modifier = Modifier.padding(start = 12.dp)) { Text("回到满 $baby 个月") }
        }
        item("hi") {
            // the month at a glance: each point as its own card, label above the words, nothing cut short
            Column(Modifier.padding(horizontal = 16.dp).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                // a point that only names a play is already on the shelf below, so it is not said twice
                mo.highlights.filter { h -> c.play(h.anchor ?: "") == null }.forEachIndexed { i, h ->
                    val (bg, fg) = when (i % 2) {
                        0 -> MaterialTheme.colorScheme.primaryContainer to MaterialTheme.colorScheme.onPrimaryContainer
                        else -> MaterialTheme.colorScheme.tertiaryContainer to MaterialTheme.colorScheme.onTertiaryContainer
                    }
                    Surface(shape = RoundedCornerShape(24.dp), color = bg, contentColor = fg, modifier = Modifier.fillMaxWidth()) {
                        Row(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.Top) {
                            app.mossling.ui.components.ShapeBadge(if (i % 2 == 0) G.Eye else G.Shield, fg.copy(alpha = 0.12f), fg,
                                shape = if (i % 2 == 0) app.mossling.ui.components.Shapes.Cookie else app.mossling.ui.components.Shapes.Gem, size = 40.dp)
                            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                                Text(h.kind, style = MaterialTheme.typography.labelLarge)
                                Text(h.text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 2.dp))
                            }
                        }
                    }
                }
            }
        }
        val plays = (listOfNotNull(mo.feature) + mo.activities).distinct().mapNotNull(play)
        if (plays.isNotEmpty()) item("plays") {
            SectionTitle("这个月玩什么", kicker = "${plays.size} 个游戏")
            // every play of the month in view: two to a row on the shelf, nothing hidden off the edge
            Shelf(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    plays.chunked(2).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            row.forEach { p -> PlayCard(p, ui.ticked(m, TickKind.Did, p.code), companion, Modifier.weight(1f)) { a.openPlay(p.code, m) } }
                            if (row.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
        item("areas") {
            SectionTitle("六个方面", kicker = "家里可以这样做")
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                mo.domains.forEach { d ->
                    Plate(Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            app.mossling.ui.components.ShapeBadge(app.mossling.ui.components.areaGlyph(d.key), areaColor(d.key).copy(alpha = 0.14f), areaColor(d.key),
                                shape = app.mossling.ui.components.Shapes.all[d.key.first().code % app.mossling.ui.components.Shapes.all.size], size = 40.dp)
                            Spacer(Modifier.width(12.dp))
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
                        Row(verticalAlignment = Alignment.Top) {
                            app.mossling.ui.components.ShapeBadge(G.Idea, app.mossling.ui.theme.Palette.Bead.copy(alpha = 0.16f), MaterialTheme.colorScheme.tertiary, shape = app.mossling.ui.components.Shapes.of(n.topic), size = 40.dp)
                            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                                Text(n.topic, style = MaterialTheme.typography.titleSmall)
                                Text(n.text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 6.dp))
                            }
                        }
                    }
                }
            }
        }
        if (mo.who.isNotBlank()) item("who") {
            SectionTitle("一天的节奏", kicker = "睡眠、活动与屏幕")
            // one tile per part of the day, each with its own picture
            val parts = mo.who.removePrefix("WHO").split('；', ';').map { it.trim().trimEnd('。') }.filter { it.isNotBlank() }
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                parts.forEach { t ->
                    val (g, col) = when {
                        "睡" in t -> G.Moon to app.mossling.ui.theme.Palette.Rod
                        "屏幕" in t -> G.Eye to app.mossling.ui.theme.Palette.RedRod
                        "活动" in t || "趴" in t || "坐" in t || "久" in t -> G.Walk to app.mossling.ui.theme.Palette.Moss
                        else -> G.Clock to app.mossling.ui.theme.Palette.Bead
                    }
                    Surface(shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            app.mossling.ui.components.ShapeBadge(g, col.copy(alpha = 0.14f), col, shape = app.mossling.ui.components.Shapes.Flower, size = 40.dp)
                            Text(t, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f).padding(start = 12.dp))
                        }
                    }
                }
                Surface(onClick = a.openGrowth, shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.secondaryContainer, contentColor = MaterialTheme.colorScheme.onSecondaryContainer, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        app.mossling.ui.components.ShapeBadge(G.Ruler, MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.12f), MaterialTheme.colorScheme.onSecondaryContainer, shape = app.mossling.ui.components.Shapes.Clover, size = 40.dp)
                        Column(Modifier.weight(1f).padding(start = 12.dp)) {
                            Text("生长曲线", style = MaterialTheme.typography.titleSmall)
                            Text("体重、身长、头围对照世界卫生组织标准", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PlayCard(p: Play, did: Boolean, companion: Kind, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(26.dp), color = MaterialTheme.colorScheme.surfaceContainerLowest, modifier = modifier) {
        Column(Modifier.padding(16.dp)) {
            // the play's own first picture, so each card shows what is actually done
            val ctx = androidx.compose.ui.platform.LocalContext.current
            val first = androidx.compose.runtime.remember(p.code) { app.mossling.ui.components.ArtIndex.steps(ctx, p.code).firstOrNull() }
            if (first != null) app.mossling.ui.components.Art(first, "", Modifier.fillMaxWidth().padding(bottom = 10.dp).clip(RoundedCornerShape(16.dp)))
            else app.mossling.ui.ip.MaterialStill(app.mossling.ui.ip.Family.of(p.domains), Modifier.fillMaxWidth().padding(bottom = 10.dp).clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.surfaceContainer))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Surface(shape = RoundedCornerShape(12.dp), color = if (companion == Kind.Moss) Palette.Moss else Palette.Rod, modifier = Modifier.shared("code-${p.code}")) {
                    Text(p.code, fontFamily = Numerals, style = MaterialTheme.typography.titleLarge, color = Palette.Paper, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp))
                }
                Spacer(Modifier.weight(1f))
                if (did) Text("做过", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
            }
            Text(p.name, style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 12.dp))
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
