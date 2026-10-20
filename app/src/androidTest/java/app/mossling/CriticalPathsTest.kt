package app.mossling

import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** The paths a parent takes every day, on a fresh install: in, log a feed, see it in the journal, mark a play done. */
@RunWith(AndroidJUnit4::class)
class CriticalPathsTest {
    @get:Rule val rule = createAndroidComposeRule<MainActivity>()

    private fun waitFor(text: String, ms: Long = 8000) = rule.waitUntil(ms) { rule.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty() }
    private fun tap(text: String) = rule.onAllNodes(hasText(text) and hasClickAction()).onFirst().performClick()

    @Test fun dailyPaths() {
        // first run: look around without a birth date
        waitFor("先看看"); tap("先看看")
        // the journal is optional: turn it on in 我的
        tap("我的"); rule.onNode(hasText("手帐") and androidx.compose.ui.test.isToggleable()).performScrollTo().performClick()
        tap("今天"); waitFor("记一下")

        // a bottle feed: one tap, the amount, done
        tap("瓶喂"); waitFor("喝了多少")
        tap("150"); tap("记下来")
        waitFor("记下了")

        // it is in the journal
        tap("手帐"); waitFor("150 毫升")

        // a play from this month's shelf, marked done
        tap("成长")
        rule.waitUntil(8000) { rule.onAllNodes(hasTestTag("grow")).fetchSemanticsNodes().isNotEmpty() }
        rule.onNode(hasTestTag("grow")).performScrollToNode(hasText("N01"))
        rule.onAllNodesWithText("N01").onFirst().performClick()
        waitFor("记为做过"); tap("记为做过")
        waitFor("这个月做过了")
    }
}
