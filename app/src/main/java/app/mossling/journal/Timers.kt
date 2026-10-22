package app.mossling.journal

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import app.mossling.MainActivity
import app.mossling.MosslingApp
import app.mossling.R
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.RecordDao
import app.mossling.data.RunningTimer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Feeds and sleeps that are timed. The timer lives in the database (it survives the app being closed), and while it
 * runs an ongoing notification shows a live chronometer with pause and stop — no service needed, the system ticks it.
 * Starting twice does nothing; stopping twice writes one entry.
 */
class Timers(private val context: Context, private val dao: RecordDao) {
    private val lock = Mutex()

    suspend fun start(type: String, side: String? = null, at: Long = System.currentTimeMillis()) = lock.withLock {
        if (dao.timer(type) != null) return@withLock
        val t = RunningTimer(type, at, side)
        dao.putTimer(t); notify(t); app.mossling.widget.TodayWidget.refresh(context)
    }

    suspend fun togglePause(type: String, now: Long = System.currentTimeMillis()) = lock.withLock {
        val t = dao.timer(type) ?: return@withLock
        val n = if (t.pausedAt == null) t.copy(pausedAt = now) else t.copy(pausedAt = null, pausedTotal = t.pausedTotal + (now - t.pausedAt))
        dao.putTimer(n); notify(n); app.mossling.widget.TodayWidget.refresh(context)
    }

    suspend fun switchSide(type: String) = lock.withLock {
        val t = dao.timer(type) ?: return@withLock
        val n = t.copy(side = if (t.side == "l") "r" else "l"); dao.putTimer(n); notify(n)
    }

    /** Ends the timer and writes the entry. Returns the entry, or null when there was nothing running. */
    suspend fun stop(type: String, now: Long = System.currentTimeMillis()): LogEntry? = lock.withLock {
        val t = dao.timer(type) ?: return@withLock null
        if (dao.dropTimer(type) == 0) return@withLock null
        cancel(type)
        val paused = t.pausedTotal + (t.pausedAt?.let { now - it } ?: 0L)
        val end = (t.pausedAt ?: now)
        val e = LogEntry(type = type, start = t.start, end = end, side = t.side, detail = if (paused > 0) "paused:$paused" else null)
        e.copy(id = dao.putLog(e)).also { app.mossling.widget.TodayWidget.refresh(context) }
    }

    /** "It started earlier than I pressed": move the start back (or forward), never into the future. */
    suspend fun shift(type: String, deltaMs: Long, now: Long = System.currentTimeMillis()) = lock.withLock {
        val t = dao.timer(type) ?: return@withLock
        val n = t.copy(start = (t.start + deltaMs).coerceAtMost(now)); dao.putTimer(n); notify(n); app.mossling.widget.TodayWidget.refresh(context)
    }

    suspend fun discard(type: String) = lock.withLock { dao.dropTimer(type); cancel(type) }

    private fun channel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = context.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel(CHANNEL, context.getString(R.string.channel_timer), NotificationManager.IMPORTANCE_LOW).apply { setShowBadge(false) })
        }
    }

    private fun notify(t: RunningTimer) {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        channel()
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java).putExtra("open", "journal").addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        fun action(a: String) = PendingIntent.getBroadcast(context, (t.type + a).hashCode(), Intent(context, TimerActionReceiver::class.java).setAction(a).putExtra("type", t.type), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val title = when (t.type) { LogType.Nurse -> "亲喂" + when (t.side) { "l" -> " · 左边"; "r" -> " · 右边"; else -> "" }; LogType.Sleep -> "睡觉"; else -> "计时" }
        val b = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(title)
            .setOngoing(true).setOnlyAlertOnce(true).setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setContentIntent(open)
            .addAction(0, if (t.pausedAt == null) "暂停" else "继续", action(ACTION_PAUSE))
            .addAction(0, "结束", action(ACTION_STOP))
        if (t.pausedAt == null) b.setUsesChronometer(true).setShowWhen(true).setWhen(t.start + t.pausedTotal)
        else b.setContentText("已暂停").setShowWhen(false)
        NotificationManagerCompat.from(context).notify(t.type.hashCode(), b.build())
    }

    private fun cancel(type: String) = NotificationManagerCompat.from(context).cancel(type.hashCode())

    /** After a restart the notification is gone; put it back for every timer still running. */
    suspend fun restore(list: List<RunningTimer>) = list.forEach { notify(it) }

    companion object {
        const val CHANNEL = "timer"
        const val ACTION_PAUSE = "app.mossling.timer.PAUSE"
        const val ACTION_STOP = "app.mossling.timer.STOP"
        const val ACTION_START = "app.mossling.timer.START"
        const val ACTION_SIDE = "app.mossling.timer.SIDE"
        fun elapsed(t: RunningTimer, now: Long): Long = ((t.pausedAt ?: now) - t.start - t.pausedTotal).coerceAtLeast(0)
    }
}

class TimerActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val type = intent.getStringExtra("type") ?: return
        val timers = (context.applicationContext as MosslingApp).graph.timers
        val done = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                when (intent.action) {
                    Timers.ACTION_PAUSE -> timers.togglePause(type); Timers.ACTION_STOP -> timers.stop(type)
                    Timers.ACTION_START -> timers.start(type, intent.getStringExtra("side")); Timers.ACTION_SIDE -> timers.switchSide(type)
                }
            } finally { done.finish() }
        }
    }
}
