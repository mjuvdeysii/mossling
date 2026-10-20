package app.mossling.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import app.mossling.ui.ip.Kind
import app.mossling.ui.theme.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.LocalDate

private val Context.store by preferencesDataStore("settings")

data class Settings(
    val birth: LocalDate? = null,
    val companion: Kind = Kind.Moss,
    val theme: ThemeMode = ThemeMode.System,
    val onboarded: Boolean = false,
    val skipDay: Long = -1,
    val pick: String = "",
    val lastMonth: Int = -1,
    /** "boy" / "girl" / null — only used to pick the WHO growth curves */
    val sex: String? = null,
    val nickname: String = "",
    /** ask for the fingerprint, face or screen lock when the app is opened */
    val lock: Boolean = false,
    /** this week's shelf (see domain.Shelf) */
    val shelf: String = "",
)

class SettingsRepository(private val context: Context) {
    private object K {
        val birth = longPreferencesKey("birth_epoch_day")
        val companion = stringPreferencesKey("companion")
        val theme = stringPreferencesKey("theme")
        val onboarded = booleanPreferencesKey("onboarded")
        val skipDay = longPreferencesKey("skip_day")
        val pick = stringPreferencesKey("pick")
        val lastMonth = longPreferencesKey("last_month")
        val sex = stringPreferencesKey("sex")
        val nickname = stringPreferencesKey("nickname")
        val lock = booleanPreferencesKey("lock")
        val shelf = stringPreferencesKey("shelf")
    }

    val settings: Flow<Settings> = context.store.data.map { p: Preferences ->
        Settings(
            birth = p[K.birth]?.let { LocalDate.ofEpochDay(it) },
            companion = runCatching { Kind.valueOf(p[K.companion] ?: "Moss") }.getOrDefault(Kind.Moss),
            theme = runCatching { ThemeMode.valueOf(p[K.theme] ?: "System") }.getOrDefault(ThemeMode.System),
            onboarded = p[K.onboarded] ?: false,
            skipDay = p[K.skipDay] ?: -1,
            pick = p[K.pick] ?: "",
            lastMonth = (p[K.lastMonth] ?: -1L).toInt(),
            sex = p[K.sex],
            nickname = p[K.nickname] ?: "",
            lock = p[K.lock] ?: false,
            shelf = p[K.shelf] ?: "",
        )
    }

    suspend fun setBirth(d: LocalDate?) = context.store.edit { if (d == null) it.remove(K.birth) else it[K.birth] = d.toEpochDay(); it[K.onboarded] = true }
    suspend fun setCompanion(k: Kind) = context.store.edit { it[K.companion] = k.name }
    suspend fun setTheme(t: ThemeMode) = context.store.edit { it[K.theme] = t.name }
    suspend fun finishOnboarding() = context.store.edit { it[K.onboarded] = true }
    suspend fun skipToday(day: Long?) = context.store.edit { if (day == null) it.remove(K.skipDay) else it[K.skipDay] = day }
    /** "month:index" of today's suggestion, so "another one" survives a restart */
    suspend fun setPick(v: String) = context.store.edit { it[K.pick] = v }
    suspend fun setSex(s: String?) = context.store.edit { if (s == null) it.remove(K.sex) else it[K.sex] = s }
    suspend fun setNickname(n: String) = context.store.edit { val t = n.trim().take(12); if (t.isEmpty()) it.remove(K.nickname) else it[K.nickname] = t }
    suspend fun setLock(on: Boolean) = context.store.edit { it[K.lock] = on }
    suspend fun setShelf(v: String) = context.store.edit { it[K.shelf] = v }
    /** Everything back to a fresh install (the records are cleared separately). */
    suspend fun clear() = context.store.edit { it.clear() }
    suspend fun setLastMonth(m: Int) = context.store.edit { it[K.lastMonth] = m.toLong() }
}
