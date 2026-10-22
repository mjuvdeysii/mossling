package app.mossling.widget

import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionSendBroadcast
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import app.mossling.MainActivity
import app.mossling.MosslingApp
import app.mossling.R
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.RunningTimer
import app.mossling.domain.ageOn
import app.mossling.journal.TimerActionReceiver
import app.mossling.journal.Timers
import kotlinx.coroutines.flow.first
import java.time.LocalDate

/**
 * The journal on the home screen, the same as in the app: a running feed or sleep with its live time and the buttons
 * to pause, change side or finish it — right there, without opening the app; otherwise the four everyday entries,
 * each saying how long ago it was last done. With the journal off, it shows the age and today's play instead.
 * Follows the phone's light or dark theme; three sizes.
 */
class TodayWidget : GlanceAppWidget() {
    companion object {
        val OPEN = ActionParameters.Key<String>("open")
        private val Small = DpSize(110.dp, 110.dp); private val Wide = DpSize(250.dp, 110.dp); private val Tall = DpSize(250.dp, 200.dp)
        suspend fun refresh(context: Context) = runCatching { TodayWidget().updateAll(context) }
    }
    override val sizeMode = SizeMode.Responsive(setOf(Small, Wide, Tall))

    private data class Data(val title: String, val journal: Boolean, val timer: RunningTimer?, val last: Map<String, Long>, val play: String?)

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val g = (context.applicationContext as MosslingApp).graph
        val s = g.settings.settings.first()
        val dao = g.db.dao()
        val age = s.birth?.let { ageOn(it, LocalDate.now()) }
        val title = listOfNotNull(s.nickname.ifBlank { null }, age?.let { if (it.days > 0) "${it.months} 个月 ${it.days} 天" else "满 ${it.months} 个月" }).joinToString(" · ").ifBlank { "苔生" }
        val timer = dao.timers().first().firstOrNull()
        val last = buildMap<String, Long> {
            listOf(LogType.Nurse, LogType.Bottle, LogType.Sleep, LogType.Diaper).forEach { t -> dao.lastOf(listOf(t))?.let { put(t, it.end ?: it.start) } }
        }
        val play = runCatching {
            val c = g.content.get(); val m = age?.bookMonth ?: 0
            app.mossling.domain.Shelf.current(c, m, s.shelf, LocalDate.now()).first.firstOrNull()?.let { "${it.code} ${it.name}" }
        }.getOrNull()
        val d = Data(title, s.journal, timer, last, play)
        provideContent { GlanceTheme { Body(context, d) } }
    }

    @Composable
    private fun Body(context: Context, d: Data) {
        val size = LocalSize.current
        val bg = ColorProvider(day = Color(0xFFF4F2EC), night = Color(0xFF1B1E19))
        val ink = ColorProvider(day = Color(0xFF1C1D19), night = Color(0xFFE7E4DB))
        val sub = ColorProvider(day = Color(0xFF4A4C43), night = Color(0xFFC3C2B6))
        val tile = ColorProvider(day = Color(0xFFE6E2D8), night = Color(0xFF2B2F28))
        Column(GlanceModifier.fillMaxSize().background(bg).cornerRadius(28.dp).padding(12.dp)) {
            Row(GlanceModifier.fillMaxWidth().clickable(actionStartActivity<MainActivity>()), verticalAlignment = Alignment.CenterVertically) {
                Image(ImageProvider(R.drawable.ic_launcher_foreground), contentDescription = null, modifier = GlanceModifier.size(36.dp))
                Spacer(GlanceModifier.width(6.dp))
                Text(d.title, style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = ink), maxLines = 1)
            }
            Spacer(GlanceModifier.height(8.dp))
            when {
                d.journal && d.timer != null -> Running(context, d.timer, size.width >= Wide.width)
                d.journal -> Quick(d, size.width >= Wide.width, size.height >= Tall.height, ink, sub, tile)
                else -> Text(d.play?.let { "今天一起玩：$it" } ?: "打开苔生，看看今天做什么", style = TextStyle(fontSize = 14.sp, color = sub),
                    modifier = GlanceModifier.clickable(actionStartActivity<MainActivity>()))
            }
        }
    }

    @Composable
    private fun Running(context: Context, t: RunningTimer, wide: Boolean) {
        val tint = if (t.type == LogType.Sleep) Color(0xFF2D4A8C) else Color(0xFFB8382B)
        val white = ColorProvider(day = Color.White, night = Color.White)
        fun send(action: String) = actionSendBroadcast(Intent(context, TimerActionReceiver::class.java).setAction(action).putExtra("type", t.type))
        Column(GlanceModifier.fillMaxWidth().background(tint).cornerRadius(20.dp).padding(12.dp)) {
            Text((if (t.type == LogType.Sleep) "睡觉" else "亲喂") + when (t.side) { "l" -> " · 左边"; "r" -> " · 右边"; else -> "" } + if (t.pausedAt != null) " · 暂停中" else "",
                style = TextStyle(fontSize = 13.sp, color = white))
            val rv = RemoteViews(context.packageName, R.layout.widget_chrono).apply {
                val elapsed = Timers.elapsed(t, System.currentTimeMillis())
                setChronometer(R.id.chrono, SystemClock.elapsedRealtime() - elapsed, null, t.pausedAt == null)
            }
            AndroidRemoteViews(rv)
            Row(GlanceModifier.fillMaxWidth().padding(top = 6.dp)) {
                Pill("结束", GlanceModifier.defaultWeight().clickable(send(Timers.ACTION_STOP)), Color.White, tint)
                Spacer(GlanceModifier.width(6.dp))
                Pill(if (t.pausedAt == null) "暂停" else "继续", GlanceModifier.defaultWeight().clickable(send(Timers.ACTION_PAUSE)), Color.White.copy(alpha = 0.22f), Color.White)
                if (wide && t.type == LogType.Nurse) {
                    Spacer(GlanceModifier.width(6.dp))
                    Pill("换边", GlanceModifier.defaultWeight().clickable(send(Timers.ACTION_SIDE)), Color.White.copy(alpha = 0.22f), Color.White)
                }
            }
        }
    }

    @Composable
    private fun Pill(text: String, modifier: GlanceModifier, bg: Color, fg: Color) {
        Box(modifier.height(40.dp).background(ColorProvider(day = bg, night = bg)).cornerRadius(20.dp), contentAlignment = Alignment.Center) {
            Text(text, style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, color = ColorProvider(day = fg, night = fg)))
        }
    }

    @Composable
    private fun Quick(d: Data, wide: Boolean, tall: Boolean, ink: androidx.glance.unit.ColorProvider, sub: androidx.glance.unit.ColorProvider, tile: androidx.glance.unit.ColorProvider) {
        val kinds = listOf(LogType.Nurse to "亲喂", LogType.Bottle to "瓶喂", LogType.Sleep to "睡觉", LogType.Diaper to "尿布").let { if (wide) it else it.take(2) }
        val now = System.currentTimeMillis()
        fun ago(t: Long?): String = t?.let { val m = ((now - it) / 60_000).toInt(); when { m < 2 -> "刚刚"; m < 60 -> "$m 分钟前"; else -> "${m / 60} 小时前" } } ?: "—"
        Row(GlanceModifier.fillMaxWidth()) {
            kinds.forEachIndexed { i, (t, n) ->
                if (i > 0) Spacer(GlanceModifier.width(6.dp))
                // a tap opens the app straight on that entry's question (how much, which side, wet or dirty)
                Column(GlanceModifier.defaultWeight().height(if (tall) 84.dp else 60.dp).background(tile).cornerRadius(18.dp)
                    .clickable(actionStartActivity<MainActivity>(actionParametersOf(OPEN to "log:$t"))),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalAlignment = Alignment.CenterVertically) {
                    Text(n, style = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = ink))
                    Text(ago(d.last[t]), style = TextStyle(fontSize = 11.sp, color = sub))
                }
            }
        }
    }
}

class TodayWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = TodayWidget() }
