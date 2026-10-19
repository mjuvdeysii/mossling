package app.mossling.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
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
import androidx.glance.unit.ColorProvider
import app.mossling.MainActivity
import app.mossling.MosslingApp
import app.mossling.R
import app.mossling.data.LogType
import app.mossling.domain.ageOn
import app.mossling.journal.Timers
import kotlinx.coroutines.flow.first
import java.time.LocalDate

/** On the home screen: the age, the time since the last feed (or the timer running), and one tap to log. */
class TodayWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val g = (context.applicationContext as MosslingApp).graph
        val s = g.settings.settings.first()
        val last = g.db.dao().lastOf(listOf(LogType.Nurse, LogType.Bottle))
        val timers = g.db.dao().timers().first()
        val age = s.birth?.let { ageOn(it, LocalDate.now()) }
        val now = System.currentTimeMillis()
        val line = timers.firstOrNull()?.let { t -> (if (t.type == LogType.Sleep) "在睡觉" else "在喂奶") + " · " + mins(Timers.elapsed(t, now)) }
            ?: last?.let { "上次喂奶 " + mins(now - (it.end ?: it.start)) + "前" } ?: "还没有记录"
        provideContent { Body(age?.let { if (it.days > 0) "${it.months} 个月 ${it.days} 天" else "满 ${it.months} 个月" } ?: "苔生", line) }
    }

    private fun mins(ms: Long): String { val m = (ms / 60000).toInt(); return if (m >= 60) "${m / 60} 小时 ${m % 60} 分" else "$m 分钟" }

    @Composable
    private fun Body(title: String, line: String) {
        val ink = ColorProvider(Color(0xFF1C1D19)); val sub = ColorProvider(Color(0xFF4A4C43))
        Column(GlanceModifier.fillMaxSize().background(Color(0xFFF4F2EC)).cornerRadius(26.dp).padding(14.dp)) {
            Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Image(ImageProvider(R.drawable.ic_launcher_foreground), contentDescription = null, modifier = GlanceModifier.size(48.dp))
                Spacer(GlanceModifier.width(8.dp))
                Column {
                    Text(title, style = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold, color = ink))
                    Text(line, style = TextStyle(fontSize = 13.sp, color = sub))
                }
            }
            Spacer(GlanceModifier.height(10.dp))
            Row(GlanceModifier.fillMaxWidth()) {
                listOf(LogType.Nurse to "亲喂", LogType.Bottle to "瓶喂", LogType.Sleep to "睡觉", LogType.Diaper to "尿布").forEachIndexed { i, (t, n) ->
                    if (i > 0) Spacer(GlanceModifier.width(6.dp))
                    Box(GlanceModifier.defaultWeight().height(44.dp).background(Color(0xFFE6E2D8)).cornerRadius(16.dp)
                        .clickable(actionStartActivity<MainActivity>(actionParametersOf(OPEN to "log:$t"))), contentAlignment = Alignment.Center) {
                        Text(n, style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, color = ink))
                    }
                }
            }
        }
    }

    companion object {
        val OPEN = ActionParameters.Key<String>("open")
        suspend fun refresh(context: Context) = runCatching { TodayWidget().updateAll(context) }
    }
}

class TodayWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = TodayWidget() }

