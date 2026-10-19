package app.mossling

import app.mossling.domain.Growth
import app.mossling.domain.Indicator
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

class GrowthTest {
    private val g = Growth.parse(File("src/main/assets/who_growth.json").readText())

    @Test fun medianIsM() {
        assertEquals(3.3464, g.at(Indicator.Weight, false, 0.0, 50), 1e-4)
        assertEquals(49.8842, g.at(Indicator.Length, false, 0.0, 50), 1e-4)
    }
    @Test fun medianIsFiftiethPercentile() = assertEquals(50.0, g.percentile(Indicator.Weight, true, 6.0, g.at(Indicator.Weight, true, 6.0, 50)), 0.1)
    @Test fun publishedSd2AtSixMonthsBoys() {
        // WHO table: boys weight-for-age, 6 months, −2 SD = 6.4 kg, +2 SD = 9.8 kg → about the 2.3rd and 97.7th percentile
        assertEquals(2.3, g.percentile(Indicator.Weight, false, 6.0, 6.4), 0.4)
        assertEquals(97.7, g.percentile(Indicator.Weight, false, 6.0, 9.8), 0.4)
    }
}
