package app.mossling.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import app.mossling.ui.ip.Kind
import app.mossling.ui.theme.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.LocalDate

private val Context.store by preferencesDataStore(name = "settings")

object Consent {
    const val Version = "2026-10-26"
}

data class Settings(
    val birth: LocalDate? = null,
    val companion: Kind = Kind.Moss,
    val theme: ThemeMode = ThemeMode.System,
    val nightLight: Boolean = true,
    val journal: Boolean = false,
    val onboarded: Boolean = false,
    /** "boy" or "girl", for WHO growth curves; null until the user chooses. */
    val sex: String? = null,
    /** "boy" or "girl", for how the child is drawn in illustrations; defaults to [sex]. */
    val look: String? = null,
    /** Optional nickname, shown only on device. */
    val nickname: String = "",
    /** Require the phone's screen lock (fingerprint/face/PIN) when opening the app. */
    val appLock: Boolean = false,
    /** This week's shelf: `"<epochWeek>|A11,A12,N03"`. */
    val shelf: String = "",
    /** Today's chosen play on the shelf: `"<epochDay>|A12"`. */
    val todayPick: String = "",
    /** In-progress follow-along play session: `"CODE|month|step"`. */
    val session: String = "",
    /** Guardian privacy & children's info rules consent version (`Consent.Version`, `"declined"`, or `""`). */
    val consent: String = Consent.Version,
) {
    val ta: String get() = when (sex) {
        "girl" -> "她"
        "boy" -> "他"
        else -> "孩子"
    }

    val drawsGirl: Boolean get() = (look ?: sex) == "girl"

    val consented: Boolean get() = consent == Consent.Version

    val playing: Triple<String, Int, Int>?
        get() {
            val p = session.split("|")
            if (p.size != 3) return null
            val m = p[1].toIntOrNull() ?: return null
            val s = p[2].toIntOrNull() ?: return null
            return if (p[0].isBlank()) null else Triple(p[0], m, s)
        }
}

class SettingsRepository(private val context: Context) {
    private val kBirth = stringPreferencesKey("birth")
    private val kComp = stringPreferencesKey("companion")
    private val kTheme = stringPreferencesKey("theme")
    private val kNightLight = booleanPreferencesKey("night_light")
    private val kJournal = booleanPreferencesKey("journal")
    private val kOnboard = booleanPreferencesKey("onboarded")
    private val kSex = stringPreferencesKey("sex")
    private val kLook = stringPreferencesKey("look")
    private val kNick = stringPreferencesKey("nickname")
    private val kLock = booleanPreferencesKey("app_lock")
    private val kShelf = stringPreferencesKey("shelf")
    private val kPick = stringPreferencesKey("today_pick")
    private val kSession = stringPreferencesKey("session")
    private val kConsent = stringPreferencesKey("consent")

    val settings: Flow<Settings> = context.store.data.map { p ->
        Settings(
            birth = p[kBirth]?.takeIf { it.isNotEmpty() }?.let { runCatching { LocalDate.parse(it) }.getOrNull() },
            companion = p[kComp]?.let { runCatching { Kind.valueOf(it) }.getOrNull() } ?: Kind.Moss,
            theme = p[kTheme]?.let { runCatching { ThemeMode.valueOf(it) }.getOrNull() } ?: ThemeMode.System,
            nightLight = p[kNightLight] ?: true,
            journal = p[kJournal] ?: false,
            onboarded = p[kOnboard] ?: false,
            sex = p[kSex]?.takeIf { it == "boy" || it == "girl" },
            look = p[kLook]?.takeIf { it == "boy" || it == "girl" },
            nickname = p[kNick] ?: "",
            appLock = p[kLock] ?: false,
            shelf = p[kShelf] ?: "",
            todayPick = p[kPick] ?: "",
            session = p[kSession] ?: "",
            consent = p[kConsent] ?: Consent.Version,
        )
    }

    suspend fun setBirth(date: LocalDate?) {
        context.store.edit {
            if (date == null) it.remove(kBirth) else it[kBirth] = date.toString()
            it[kOnboard] = true
        }
        app.mossling.widget.TodayWidget.refresh(context)
    }

    suspend fun skipOnboarding() {
        context.store.edit { it[kOnboard] = true }
    }

    suspend fun setCompanion(k: Kind) {
        context.store.edit { it[kComp] = k.name }
    }

    suspend fun setTheme(m: ThemeMode) {
        context.store.edit { it[kTheme] = m.name }
    }

    suspend fun setNightLight(on: Boolean) {
        context.store.edit { it[kNightLight] = on }
    }

    suspend fun setJournal(on: Boolean) {
        context.store.edit { it[kJournal] = on }
        app.mossling.widget.TodayWidget.refresh(context)
    }

    suspend fun setSex(s: String?) {
        context.store.edit {
            if (s == null) it.remove(kSex) else it[kSex] = s
        }
    }

    suspend fun setLook(l: String?) {
        context.store.edit {
            if (l == null) it.remove(kLook) else it[kLook] = l
        }
    }

    suspend fun setNickname(n: String) {
        context.store.edit { it[kNick] = n.trim().take(20) }
        app.mossling.widget.TodayWidget.refresh(context)
    }

    suspend fun setAppLock(on: Boolean) {
        context.store.edit { it[kLock] = on }
    }

    suspend fun setShelf(s: String) {
        context.store.edit { it[kShelf] = s }
        app.mossling.widget.TodayWidget.refresh(context)
    }

    suspend fun setTodayPick(s: String) {
        context.store.edit { it[kPick] = s }
    }

    suspend fun saveSession(code: String, month: Int, step: Int) {
        context.store.edit { it[kSession] = "$code|$month|$step" }
    }

    suspend fun clearSession(code: String? = null) {
        context.store.edit {
            val cur = it[kSession] ?: ""
            if (code == null || cur.startsWith("$code|")) {
                it.remove(kSession)
            }
        }
    }

    suspend fun acceptConsent() {
        context.store.edit { it[kConsent] = Consent.Version }
    }

    suspend fun declineConsent() {
        context.store.edit { it[kConsent] = "declined" }
    }

    suspend fun withdrawConsent() {
        context.store.edit {
            it.remove(kBirth)
            it.remove(kSex)
            it.remove(kLook)
            it.remove(kNick)
            it.remove(kShelf)
            it.remove(kPick)
            it.remove(kSession)
            it[kJournal] = false
            it[kConsent] = "declined"
        }
        app.mossling.widget.TodayWidget.refresh(context)
    }

    /** Once at startup: if the preference was never written, keep the journal on only when logs already exist. */
    suspend fun settleJournal(hasLogs: suspend () -> Boolean) {
        context.store.edit { if (kJournal !in it) it[kJournal] = hasLogs() }
    }

    suspend fun clear() {
        context.store.edit { it.clear() }
        app.mossling.widget.TodayWidget.refresh(context)
    }
}
