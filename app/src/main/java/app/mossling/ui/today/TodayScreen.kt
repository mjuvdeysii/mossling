package app.mossling.ui.today

import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.Month
import app.mossling.data.Play
import app.mossling.data.RunningTimer
import app.mossling.data.TickKind
import app.mossling.domain.monthStart
import app.mossling.journal.Timers
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.Plate
import app.mossling.ui.components.shared
import app.mossling.ui.components.SandpaperNumber
import app.mossling.ui.components.WorkTray
import androidx.compose.foundation.clickable
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.clock
import app.mossling.ui.components.md
import app.mossling.ui.components.weekday
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Kind
import app.mossling.ui.ip.Mood
import app.mossling.ui.journal.LogButton
import app.mossling.ui.journal.LogKinds
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import kotlinx.coroutines.delay
import java.time.LocalTime

data class TodayActions(
    val openPlay: (String, Int) -> Unit = { _, _ -> },
    val openMonth: (Int) -> Unit = {},
    val setBirth: () -> Unit = {},
    val another: () -> Unit = {},
    val skip: (Boolean) -> Unit = {},
    val log: (String) -> Unit = {},
    val pause: (String) -> Unit = {},
    val stop: (String) -> Unit = {},
    val openJournal: () -> Unit = {},
)

/** Today's suggestion: the month's plays, featured one first; [pick] moves through them. */
fun todaysPlays(month: Month, play: (String) -> Play?): List<Play> {
    val codes = (listOfNotNull(month.feature) + month.activities).distinct()
    return codes.mapNotNull(play)
}

@Composable
fun TodayScreen(ui: AppUi, a: TodayActions, modifier: Modifier = Modifier, now: () -> Long = System::currentTimeMillis) {
    val c = ui.content ?: return
    val age = ui.age
    val m = ui.babyMonth ?: 0
    val month = c.month(m)
    val plays = todaysPlays(month) { c.play(it) }
    val pickIndex = ui.settings.pick.split(":").let { p -> if (p.size == 2 && p[0].toIntOrNull() == m) p[1].toIntOrNull() ?: 0 else 0 }
    val play = plays.getOrNull(pickIndex % plays.size.coerceAtLeast(1))
    val skipped = ui.settings.skipDay == ui.today.toEpochDay()
    val companion = LocalCompanion.current
    LazyColumn(modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 32.dp)) {
        item(key = "hero") {
            val t by androidx.compose.runtime.produceState(now()) { while (true) { kotlinx.coroutines.delay(60_000); value = now() } }
            Hero(ui, companion, a, since(ui, t))
        }
        if (age != null && play != null) item(key = "play") {
            Box(Modifier.padding(horizontal = 16.dp)) {
                AnimatedContent(targetState = if (skipped) null else play, transitionSpec = {
                    (slideInHorizontally { it / 6 } + fadeIn()) togetherWith (slideOutHorizontally { -it / 6 } + fadeOut())
                }, label = "play") { p ->
                    if (p == null) SkippedRow(onUndo = { a.skip(false) })
                    else PlayPlate(p, m, plays.size, companion, onOpen = { a.openPlay(p.code, m) }, onAnother = a.another, onSkip = { a.skip(true) })
                }
            }
        }
        val running = ui.timers
        if (running.isNotEmpty()) item(key = "timers") {
            Column(Modifier.padding(horizontal = 16.dp).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                running.forEach { t -> TimerPlate(t, now, a) }
            }
        }
        if (c.months.isNotEmpty()) item(key = "log") {
            SectionTitle("记一下", kicker = "一下就好")
            Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                LogKinds.take(4).forEach { k -> LogButton(k, running.any { it.type == k.type }, onClick = { a.log(k.type) }, modifier = Modifier.weight(1f)) }
            }
        }
        if (age != null) item(key = "next") { NextCare(ui, m, a) }
        if (age != null) item(key = "month") { ThisMonth(month, onOpen = { a.openMonth(m) }) }
    }
}

@Composable
private fun Hero(ui: AppUi, companion: Kind, a: TodayActions, since: String? = null) {
    val age = ui.age
    val hour = LocalTime.now().hour
    val night = hour >= 22 || hour < 6
    Column(Modifier.fillMaxWidth().statusBarsPadding().padding(start = 20.dp, end = 12.dp, top = 12.dp)) {
        Text(listOfNotNull(ui.settings.nickname.ifBlank { null }, "${md(ui.today)} · ${weekday(ui.today)}").joinToString(" · "), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                if (age == null) {
                    Text("你好。", style = MaterialTheme.typography.displaySmall, modifier = Modifier.padding(top = 18.dp))
                    Text("告诉我宝宝哪天出生，这里每天会讲今天该看什么。", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(top = 6.dp))
                    Button(onClick = a.setBirth, modifier = Modifier.padding(top = 16.dp).height(52.dp), shape = RoundedCornerShape(18.dp)) { Text("填写出生日期") }
                } else {
                    // the age on a sandpaper board, the unit and the days beside it
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 10.dp)) {
                        SandpaperNumber("${age.months}", MaterialTheme.typography.displayLarge)
                        Column(Modifier.padding(start = 12.dp)) {
                            Text("个月", style = MaterialTheme.typography.headlineSmall)
                            if (age.days > 0) Row(verticalAlignment = Alignment.Bottom) {
                                Text("${age.days}", style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.primary, modifier = Modifier.alignByBaseline())
                                Text(" 天", style = MaterialTheme.typography.titleLarge, modifier = Modifier.alignByBaseline())
                            }
                        }
                    }
                    Text(if (age.months < 36) "再过 ${age.toNext} 天满 ${age.months + 1} 个月 · 一起走过第 ${age.lived} 天" else "一起走过第 ${age.lived} 天",
                        style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    DayBeads(age.days, age.days + age.toNext, Modifier.padding(top = 12.dp))
                    since?.let { Text(it, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 10.dp)) }
                }
            }
            // it reads the room: asleep while the baby sleeps or late at night, eyes down on a feed, otherwise on the board
            val sleeping = ui.timers.any { it.type == app.mossling.data.LogType.Sleep && it.pausedAt == null }
            val feeding = ui.timers.any { it.type == app.mossling.data.LogType.Nurse && it.pausedAt == null }
            Creature(companion, Modifier.size(124.dp),
                mood = if (night || sleeping) Mood.Sleep else Mood.Open,
                look = if (feeding) Offset(-0.3f, 0.95f) else Offset(-0.85f, 0.25f),
                lid = if (feeding) 0.42f else null,
                label = if (companion == Kind.Moss) "Moss" else "Otto", poke = true)
        }
    }
}

/** This month as a row of beads: one per day, filled up to today. */
@Composable
private fun DayBeads(done: Int, total: Int, modifier: Modifier = Modifier) {
    val on = MaterialTheme.colorScheme.primary
    val off = MaterialTheme.colorScheme.outlineVariant
    Canvas(modifier.fillMaxWidth().height(10.dp)) {
        val n = total.coerceIn(1, 31); val gap = size.width / n; val r = (gap * 0.32f).coerceAtMost(4.dp.toPx())
        for (i in 0 until n) {
            val c = Offset(gap * i + gap / 2, size.height / 2)
            if (i < done) drawCircle(on, r, c) else if (i == done) drawCircle(Palette.Bead, r * 1.25f, c) else drawCircle(off, r, c, style = Stroke(1.2.dp.toPx()))
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun PlayPlate(p: Play, m: Int, total: Int, companion: Kind, onOpen: () -> Unit, onAnother: () -> Unit, onSkip: () -> Unit) {
    WorkTray(Modifier.fillMaxWidth().padding(top = 20.dp).clip(RoundedCornerShape(30.dp)).clickable(onClick = onOpen)) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text("今天一起玩", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                Text(p.name, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 4.dp))
                Text(listOf(p.age, p.domains.joinToString("、")).filter { it.isNotBlank() }.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Specimen(p.code, companion)
        }
        p.steps.firstOrNull()?.let { Text(it, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(top = 14.dp), maxLines = 3, overflow = TextOverflow.Ellipsis) }
        if (p.safety.isNotBlank()) Row(Modifier.padding(top = 10.dp), verticalAlignment = Alignment.Top) {
            Text("安全", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.error, modifier = Modifier.widthIn(min = 40.dp).padding(top = 2.dp, end = 8.dp), softWrap = false)
            Text(p.safety, style = MaterialTheme.typography.bodySmall)
        }
        // wraps rather than clips when the system font is large
        FlowRow(Modifier.fillMaxWidth().padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Button(onClick = onOpen, modifier = Modifier.heightIn(min = 52.dp), shape = RoundedCornerShape(18.dp), contentPadding = PaddingValues(horizontal = 26.dp)) { Text("开始") }
            Spacer(Modifier.width(8.dp))
            if (total > 1) TextButton(onClick = onAnother, modifier = Modifier.heightIn(min = 48.dp)) { Text("换一个") }
            Spacer(Modifier.weight(1f))
            TextButton(onClick = onSkip, modifier = Modifier.heightIn(min = 48.dp)) { Text("今天不做", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

/** The play's code set like a specimen label, the companion peeking over it. */
@Composable
private fun Specimen(code: String, companion: Kind) {
    Box(Modifier.size(width = 84.dp, height = 96.dp)) {
        Surface(color = if (companion == Kind.Moss) Palette.Moss else Palette.Rod, shape = RoundedCornerShape(18.dp), modifier = Modifier.align(Alignment.BottomCenter).size(84.dp, 70.dp).shared("code-$code")) {
            Box(contentAlignment = Alignment.Center) { Text(code, fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, color = Palette.Paper) }
        }
        Creature(companion, Modifier.size(44.dp).align(Alignment.TopEnd).offset(x = 4.dp, y = 2.dp), look = Offset(-0.6f, 0.8f))
    }
}

@Composable
private fun SkippedRow(onUndo: () -> Unit) {
    Surface(Modifier.fillMaxWidth().padding(top = 20.dp), shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainer) {
        Row(Modifier.padding(start = 20.dp, end = 8.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("今天不做游戏，也很好。", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            TextButton(onClick = onUndo, modifier = Modifier.height(48.dp)) { Text("还是看看") }
        }
    }
}

@Composable
private fun TimerPlate(t: RunningTimer, now: () -> Long, a: TodayActions) {
    var tick by remember { mutableLongStateOf(now()) }
    LaunchedEffect(t) { while (true) { tick = now(); delay(1000) } }
    val k = LogKinds.first { it.type == t.type }
    Surface(onClick = a.openJournal, shape = RoundedCornerShape(28.dp), color = k.tint, contentColor = Color.White, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(k.name + when (t.side) { "l" -> " · 左边"; "r" -> " · 右边"; else -> "" } + if (t.pausedAt != null) " · 暂停中" else "", style = MaterialTheme.typography.labelLarge)
                Text(clock(Timers.elapsed(t, tick)), style = MaterialTheme.typography.displaySmall)
            }
            OutlinedButton(onClick = { a.pause(t.type) }, modifier = Modifier.height(48.dp)) { Text(if (t.pausedAt == null) "暂停" else "继续", color = Color.White) }
            Spacer(Modifier.width(8.dp))
            FilledTonalButton(onClick = { a.stop(t.type) }, modifier = Modifier.height(48.dp)) { Text("结束") }
        }
    }
}

@Composable
private fun NextCare(ui: AppUi, m: Int, a: TodayActions) {
    val c = ui.content ?: return
    val birth = ui.settings.birth ?: return
    // the first month from now with a vaccine or check-up not yet recorded
    val next = (m..36).firstOrNull { k ->
        val mo = c.month(k)
        mo.vaccines.indices.any { !ui.ticked(k, TickKind.Vaccine, "$it") } || mo.checkups.indices.any { !ui.ticked(k, TickKind.Checkup, "$it") }
    } ?: return
    val mo = c.month(next)
    val items = mo.vaccines + mo.checkups
    Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 20.dp), color = MaterialTheme.colorScheme.surfaceContainer, onClick = { a.openMonth(next) }) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(44.dp).clip(RoundedCornerShape(14.dp)).background(MaterialTheme.colorScheme.secondaryContainer), contentAlignment = Alignment.Center) {
                Glyph(G.Clock, color = MaterialTheme.colorScheme.onSecondaryContainer)
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(if (next == m) "这个月的接种与儿保" else "下一次 · 满 $next 个月 · ${md(monthStart(birth, next))}", style = MaterialTheme.typography.labelLarge)
                Text(items.first() + if (items.size > 1) " 等 ${items.size} 项" else "", style = MaterialTheme.typography.bodyMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
private fun ThisMonth(month: Month, onOpen: () -> Unit) {
    SectionTitle(month.title, kicker = "满 ${month.month} 个月")
    Column(Modifier.padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        month.highlights.forEach { h ->
            Row {
                Text(h.kind.take(4), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary, modifier = Modifier.width(72.dp).padding(top = 3.dp))
                Text(h.text, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            }
        }
        TextButton(onClick = onOpen, modifier = Modifier.height(48.dp)) { Text("打开这个月") }
    }
}

/** "上次喂奶 2 小时 10 分前 · 醒了 1 小时 5 分" — only what is known, nothing when nothing was logged today or yesterday. */
private fun since(ui: AppUi, now: Long): String? {
    fun ago(ms: Long) = app.mossling.ui.components.minutes(ms.coerceAtLeast(0))
    val day = 36 * 3_600_000L
    val feed = ui.lastFeed?.takeIf { ui.timers.none { t -> t.type == it.type } }?.let { e -> (e.end ?: e.start).let { if (now - it < day) "上次喂奶 ${ago(now - it)}前" else null } }
    val awake = if (ui.timers.any { it.type == app.mossling.data.LogType.Sleep }) null
        else ui.lastSleep?.end?.let { if (now - it < day) "醒了 ${ago(now - it)}" else null }
    return listOfNotNull(feed, awake).joinToString(" · ").ifBlank { null }
}
