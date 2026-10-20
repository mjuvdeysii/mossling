package app.mossling.domain

import app.mossling.data.Content
import app.mossling.data.Play
import java.time.DayOfWeek
import java.time.LocalDate

/**
 * The week's shelf, the Montessori way: a few materials (three or four), chosen for this child at this age, set out
 * on a low shelf for the whole week, repeated as often as the child wants, and rotated when the week turns.
 * Stored as "<epoch day of the week's Monday>|CODE,CODE,CODE".
 */
object Shelf {
    const val Max = 4
    data class State(val week: LocalDate, val codes: List<String>)

    fun weekOf(d: LocalDate): LocalDate = d.with(DayOfWeek.MONDAY)

    fun parse(s: String): State? {
        val p = s.split("|"); if (p.size != 2) return null
        val w = p[0].toLongOrNull() ?: return null
        return State(LocalDate.ofEpochDay(w), p[1].split(",").filter { it.isNotBlank() })
    }

    fun format(week: LocalDate, codes: List<String>) = "${weekOf(week).toEpochDay()}|" + codes.take(Max).joinToString(",")

    /** Plays that fit month [m]: the month's own first (its feature leading), then any play whose age range covers it. */
    fun candidates(c: Content, m: Int): List<Play> {
        val mo = c.month(m)
        val own = (listOfNotNull(mo.feature) + mo.activities).distinct().mapNotNull { c.play(it) }
        val range = c.activities.filter { m in it.from..it.to && it !in own }
        return own + range
    }

    /** A fresh shelf for the week: what was not on last week's shelf comes first, so the shelf really rotates. */
    fun suggest(c: Content, m: Int, last: List<String>): List<String> {
        val all = candidates(c, m).map { it.code }
        val fresh = all.filter { it !in last }
        return (fresh + all.filter { it in last }).take(3)
    }

    /** The shelf to show this week, and whether it is last week's (time to rotate). */
    fun current(c: Content, m: Int, stored: String, today: LocalDate): Pair<List<Play>, Boolean> {
        val st = parse(stored)
        val codes = st?.codes?.filter { c.play(it) != null }.orEmpty()
        if (codes.isEmpty()) return suggest(c, m, emptyList()).mapNotNull { c.play(it) } to false
        return codes.mapNotNull { c.play(it) } to (st!!.week != weekOf(today))
    }
}
