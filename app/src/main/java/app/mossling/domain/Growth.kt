package app.mossling.domain

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.pow
import kotlin.math.sqrt

/** The three WHO growth standards this app draws: weight, length/height and head circumference for age. */
enum class Indicator(val key: String, val label: String, val unit: String) {
    Weight("wfa", "体重", "千克"), Length("lhfa", "身长 / 身高", "厘米"), Head("hcfa", "头围", "厘米")
}

@Serializable
data class WhoTables(val source: String, val wfa: Map<String, List<List<Double>>>, val lhfa: Map<String, List<List<Double>>>, val hcfa: Map<String, List<List<Double>>>)

/**
 * WHO Child Growth Standards (2006), by LMS: a value's z-score and percentile at a given age, and the curve values for
 * the percentiles the WHO charts draw (3rd, 15th, 50th, 85th, 97th). Age is in months and may be fractional; the
 * monthly LMS parameters are interpolated linearly.
 */
class Growth(private val t: WhoTables) {
    companion object {
        fun parse(json: String) = Growth(Json { ignoreUnknownKeys = true }.decodeFromString(WhoTables.serializer(), json))
        val Lines = listOf(3, 15, 50, 85, 97)
        private val zOf = mapOf(3 to -1.880794, 15 to -1.036433, 50 to 0.0, 85 to 1.036433, 97 to 1.880794)
    }

    private fun table(i: Indicator, girl: Boolean) = when (i) { Indicator.Weight -> t.wfa; Indicator.Length -> t.lhfa; Indicator.Head -> t.hcfa }[if (girl) "girls" else "boys"]!!

    private fun lms(i: Indicator, girl: Boolean, months: Double): DoubleArray {
        val rows = table(i, girl); val m = months.coerceIn(0.0, 36.0)
        val a = m.toInt().coerceAtMost(35); val f = m - a
        return DoubleArray(3) { k -> rows[a][k] + (rows[a + 1][k] - rows[a][k]) * f }
    }

    /** The value on the curve of [percentile] at [months]. */
    fun at(i: Indicator, girl: Boolean, months: Double, percentile: Int): Double {
        val (l, m, s) = lms(i, girl, months).let { Triple(it[0], it[1], it[2]) }
        val z = zOf[percentile] ?: 0.0
        return if (abs(l) < 1e-6) m * exp(s * z) else m * (1 + l * s * z).pow(1 / l)
    }

    fun z(i: Indicator, girl: Boolean, months: Double, value: Double): Double {
        val (l, m, s) = lms(i, girl, months).let { Triple(it[0], it[1], it[2]) }
        return if (abs(l) < 1e-6) ln(value / m) / s else ((value / m).pow(l) - 1) / (l * s)
    }

    /** Percentile 0–100 of [value]. */
    fun percentile(i: Indicator, girl: Boolean, months: Double, value: Double): Double = 100 * phi(z(i, girl, months, value))

    private fun phi(z: Double): Double {
        // Abramowitz–Stegun 7.1.26
        val t = 1 / (1 + 0.3275911 * abs(z) / sqrt(2.0))
        val y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-z * z / 2)
        return if (z >= 0) (1 + y) / 2 else (1 - y) / 2
    }
}
