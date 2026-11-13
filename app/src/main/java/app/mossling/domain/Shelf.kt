package app.mossling.domain

import app.mossling.data.Content
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.Play
import app.mossling.data.Tick
import app.mossling.data.TickKind
import app.mossling.data.tickKey
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * The week's shelf (`ios/Mossling/Domain/Shelf.swift` & `PlayLog.swift`):
 * Three plays set out on a low wooden Montessori shelf for the week.
 * Covers distinct development areas first, favours plays not yet done, and rotates cleanly when a new week begins.
 */
object Shelf {
    /** Monday-based week number since epoch (1970-01-01 was a Thursday). */
    fun week(today: LocalDate): Long = (today.toEpochDay() + 3) / 7

    /** Epoch millisecond range `[mondayStart, nextMondayStart)` for the week containing [today]. */
    fun weekBounds(today: LocalDate, zone: ZoneId = ZoneId.systemDefault()): Pair<Long, Long> {
        val dow = today.dayOfWeek.value // 1 = Monday .. 7 = Sunday
        val monday = today.minusDays((dow - 1).toLong())
        val start = monday.atStartOfDay(zone).toInstant().toEpochMilli()
        val end = monday.plusDays(7).atStartOfDay(zone).toInstant().toEpochMilli()
        return start to end
    }

    /** Saved as `"<week>|A11,A12,N03"`. */
    fun parse(saved: String): Pair<Long, List<String>>? {
        val p = saved.split("|", limit = 2)
        if (p.size != 2) return null
        val w = p[0].toLongOrNull() ?: return null
        val codes = p[1].split(",").filter { it.isNotBlank() }
        return if (codes.isEmpty()) null else w to codes
    }

    fun format(week: Long, codes: List<String>): String = "$week|${codes.distinct().take(4).joinToString(",")}"

    /** Today's explicit pick, saved as `"<epochDay>|A12"`. */
    fun pick(saved: String, today: LocalDate): String? {
        val p = saved.split("|", limit = 2)
        if (p.size != 2) return null
        val d = p[0].toLongOrNull() ?: return null
        return if (d == today.toEpochDay()) p[1].ifBlank { null } else null
    }

    fun formatPick(today: LocalDate, code: String): String = "${today.toEpochDay()}|$code"

    /**
     * Suggests up to 3 plays for [month]:
     * 1. One from each development area first (unplayed and not on last week's shelf preferred),
     * 2. Then unplayed and not on last week's shelf,
     * 3. Then not on last week's shelf,
     * 4. Then anything else in the month's pool.
     */
    fun suggest(
        c: Content,
        month: Int,
        played: Set<String> = emptySet(),
        lastWeek: List<String> = emptyList(),
    ): List<Play> {
        val pool = c.playsFor(month)
        if (pool.size <= 3) return pool
        val last = lastWeek.toSet()
        val fresh = pool.filter { it.code !in played && it.code !in last }
        val unseen = pool.filter { it.code !in played }
        val notLast = pool.filter { it.code !in last }

        val chosen = mutableListOf<Play>()
        val areas = mutableSetOf<String>()

        fun takeDistinctArea(from: List<Play>) {
            for (p in from) {
                if (chosen.size >= 3) return
                val a = p.domains.firstOrNull() ?: ""
                if (p !in chosen && a !in areas) {
                    chosen.add(p)
                    if (a.isNotEmpty()) areas.add(a)
                }
            }
        }

        fun fill(from: List<Play>) {
            for (p in from) {
                if (chosen.size >= 3) return
                if (p !in chosen) chosen.add(p)
            }
        }

        takeDistinctArea(fresh)
        takeDistinctArea(unseen)
        takeDistinctArea(notLast)
        takeDistinctArea(pool)
        fill(fresh)
        fill(unseen)
        fill(notLast)
        fill(pool)
        return chosen
    }

    /**
     * The plays on the shelf right now, and whether the user set them for this week (`true`) or they are the default (`false`).
     */
    fun current(
        c: Content,
        month: Int,
        saved: String,
        today: LocalDate,
        played: Set<String> = emptySet(),
    ): Pair<List<Play>, Boolean> {
        val pool = c.playsFor(month)
        val byCode = pool.associateBy { it.code }
        val parsed = parse(saved)
        if (parsed != null && parsed.first == week(today)) {
            val picked = parsed.second.mapNotNull { byCode[it] }
            if (picked.isNotEmpty()) return picked to true
        }
        return suggest(c, month, played = played, lastWeek = parsed?.second.orEmpty()) to false
    }

    /**
     * Returns a newly formatted shelf string if the saved shelf needs rotation (new week, empty, or outgrown);
     * returns `null` when the saved shelf is already valid for this week and month.
     */
    fun roll(
        c: Content,
        month: Int,
        saved: String,
        today: LocalDate,
        played: Set<String>,
        fresh: Boolean = false,
    ): String? {
        val w = week(today)
        val pool = c.playsFor(month).map { it.code }.toSet()
        val parsed = if (fresh) null else parse(saved)
        if (parsed != null && parsed.first == w && parsed.second.all { it in pool }) {
            return null
        }
        val prev = parsed?.second.orEmpty()
        val next = suggest(c, month, played = played, lastWeek = prev).map { it.code }
        return if (next.isEmpty()) null else format(w, next)
    }

    /**
     * Picks the hero play on the shelf (`ios/Mossling/Domain/Shelf.swift`):
     * - Today's manual pick if present on the shelf,
     * - Otherwise the shelf play done fewest times this week (counted up to start of today so completing today's play
     *   marks it "今天玩过" rather than immediately swapping it away),
     * - Tie-broken by fewest times overall, then shelf order.
     */
    fun first(
        shelf: List<Play>,
        picked: String?,
        weekBeforeTodayCounts: Map<String, Int>,
        totalCounts: Map<String, Int>,
    ): Play? {
        if (picked != null) {
            shelf.firstOrNull { it.code == picked }?.let { return it }
        }
        return shelf.withIndex().minWithOrNull(
            compareBy<IndexedValue<Play>> { weekBeforeTodayCounts[it.value.code] ?: 0 }
                .thenBy { totalCounts[it.value.code] ?: 0 }
                .thenBy { it.index }
        )?.value
    }
}

/**
 * Play history for an activity (`ios/Mossling/Data/PlayLog.swift`).
 */
data class PlayRecord(
    val code: String,
    val total: Int,
    val thisWeek: Int,
    val todayCount: Int,
    val beforeTodayThisWeek: Int,
    val lastAt: Long?,
)

fun playCodeOf(detail: String?): String? =
    detail?.trim()?.substringBefore(" ")?.takeIf { it.isNotBlank() }

fun computePlayRecords(
    ticks: Map<String, Tick>,
    logs: List<LogEntry>,
    month: Int,
    today: LocalDate,
    zone: ZoneId = ZoneId.systemDefault(),
): Map<String, PlayRecord> {
    val (wStart, wEnd) = Shelf.weekBounds(today, zone)
    val dStart = today.atStartOfDay(zone).toInstant().toEpochMilli()
    val dEnd = today.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()

    val byCode = mutableMapOf<String, MutableList<Long>>()
    for (e in logs) {
        if (e.type == LogType.Play) {
            val code = playCodeOf(e.detail) ?: continue
            byCode.getOrPut(code) { mutableListOf() }.add(e.start)
        }
    }
    // Include any legacy/direct ticks that don't have a corresponding play log
    for (t in ticks.values) {
        if (t.kind == TickKind.Did) {
            val code = t.key.substringAfterLast(":")
            val list = byCode.getOrPut(code) { mutableListOf() }
            if (list.isEmpty()) list.add(t.at)
        }
    }

    return byCode.mapValues { (code, times) ->
        val total = times.size
        val thisWeek = times.count { it in wStart until wEnd }
        val todayCount = times.count { it in dStart until dEnd }
        val beforeToday = times.count { it in wStart until dStart }
        val lastAt = times.maxOrNull() ?: ticks[tickKey(month, TickKind.Did, code)]?.at
        PlayRecord(
            code = code,
            total = total,
            thisWeek = thisWeek,
            todayCount = todayCount,
            beforeTodayThisWeek = beforeToday,
            lastAt = lastAt,
        )
    }
}

/**
 * Activities played during baby's [month], with their play counts (`ios/Mossling/Data/PlayLog.swift` `played(in:)`).
 */
fun playedInMonth(
    content: Content,
    ticks: Map<String, Tick>,
    logs: List<LogEntry>,
    birth: LocalDate?,
    month: Int,
    zone: ZoneId = ZoneId.systemDefault(),
): List<Pair<Play, Int>> {
    val counts = mutableMapOf<String, Int>()
    if (birth != null) {
        val mStart = birth.plusMonths(month.toLong()).atStartOfDay(zone).toInstant().toEpochMilli()
        val mEnd = birth.plusMonths((month + 1).toLong()).atStartOfDay(zone).toInstant().toEpochMilli()
        logs.filter { it.type == LogType.Play && it.start in mStart until mEnd }.forEach { e ->
            val code = playCodeOf(e.detail) ?: return@forEach
            counts[code] = (counts[code] ?: 0) + 1
        }
    }
    ticks.values.filter { it.month == month && it.kind == TickKind.Did }.forEach { t ->
        val code = t.key.substringAfterLast(":")
        if ((counts[code] ?: 0) == 0) counts[code] = 1
    }
    return counts.entries.mapNotNull { (code, n) -> content.play(code)?.let { it to n } }
}
