package app.mossling.domain

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Age the way the handbook counts it: a child is "满 m 个月" from the day of the month they were born on (or the last
 * day of a shorter month). [days] counts from that day; [toNext] is the number of days until the next month.
 */
data class Age(val months: Int, val days: Int, val toNext: Int, val lived: Long) {
    /** The handbook month to show: 0…36. */
    val bookMonth: Int get() = months.coerceIn(0, 36)
}

fun ageOn(birth: LocalDate, today: LocalDate): Age {
    if (today.isBefore(birth)) return Age(0, 0, ChronoUnit.DAYS.between(today, birth).toInt(), 0)
    var m = ((today.year - birth.year) * 12 + today.monthValue - birth.monthValue).coerceAtLeast(0)
    if (birth.plusMonths(m.toLong()).isAfter(today)) m--
    val start = birth.plusMonths(m.toLong())
    val next = birth.plusMonths(m + 1L)
    return Age(m, ChronoUnit.DAYS.between(start, today).toInt(), ChronoUnit.DAYS.between(today, next).toInt(), ChronoUnit.DAYS.between(birth, today) + 1)
}

/** The date a given handbook month starts for this child. */
fun monthStart(birth: LocalDate, m: Int): LocalDate = birth.plusMonths(m.toLong())
