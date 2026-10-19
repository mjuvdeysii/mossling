package app.mossling.ui.components

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale

private val zone get() = ZoneId.systemDefault()

fun hm(t: Long): String { val d = Instant.ofEpochMilli(t).atZone(zone); return "%02d:%02d".format(d.hour, d.minute) }
fun weekday(d: LocalDate): String = d.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.CHINA)
fun md(d: LocalDate): String = "${d.monthValue}月${d.dayOfMonth}日"
fun clock(ms: Long): String { val s = ms / 1000; val h = s / 3600; return if (h > 0) "%d:%02d:%02d".format(h, s / 60 % 60, s % 60) else "%02d:%02d".format(s / 60, s % 60) }
fun minutes(ms: Long): String { val m = (ms / 60000).toInt(); return if (m >= 60) "${m / 60} 小时 ${m % 60} 分" else "$m 分钟" }
fun dayOf(t: Long): LocalDate = Instant.ofEpochMilli(t).atZone(zone).toLocalDate()
fun startOf(d: LocalDate): Long = d.atStartOfDay(zone).toInstant().toEpochMilli()
