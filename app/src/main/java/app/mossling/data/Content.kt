package app.mossling.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** The content, as data: assets/content.json. */
@Serializable
data class Content(
    val version: Int = 1,
    val months: List<Month>,
    val activities: List<Play>,
    val topics: List<Topic> = emptyList(),
    val health: List<Note> = emptyList(),
    val domains: List<DomainBoard> = emptyList(),
    val who: List<WhoRow> = emptyList(),
    val sources: List<Source> = emptyList(),
    val about: About = About(),
) {
    private val playIndex by lazy { activities.associateBy { it.code } }
    fun play(code: String): Play? = playIndex[code]
    fun month(m: Int): Month = months[m.coerceIn(0, months.lastIndex)]
    fun source(code: String): Source? = sources.firstOrNull { it.code == code }
}

@Serializable
data class Month(
    val month: Int,
    val title: String,
    val focus: String? = null,
    val feature: String? = null,
    val highlights: List<Highlight> = emptyList(),
    val official: String = "",
    val who: String = "",
    val basis: String = "",
    val refs: List<String> = emptyList(),
    val domains: List<Area> = emptyList(),
    val activities: List<String> = emptyList(),
    val observe: List<ObserveGroup> = emptyList(),
    val vaccines: List<String> = emptyList(),
    val checkups: List<String> = emptyList(),
    val notes: List<Note> = emptyList(),
)

@Serializable data class Highlight(val kind: String, val text: String, val anchor: String = "", val tag: String = "")
@Serializable data class Area(val key: String, val name: String, val text: String, val refs: List<String> = emptyList())
@Serializable data class ObserveGroup(val area: String, val items: List<String>)
@Serializable data class Note(val topic: String, val text: String, val refs: List<String> = emptyList())

@Serializable
data class Play(
    val code: String,
    val name: String,
    val age: String = "",
    val domains: List<String> = emptyList(),
    val from: Int = 0,
    val to: Int = 36,
    val prepare: String = "",
    val steps: List<String> = emptyList(),
    val observe: String = "",
    val pause: String = "",
    val safety: String = "",
    val refs: List<String> = emptyList(),
)

@Serializable
data class Block(
    val type: String,
    val text: String? = null,
    val items: List<String>? = null,
    val head: List<String>? = null,
    val rows: List<List<String>>? = null,
)

@Serializable data class Topic(val id: String, val title: String, @SerialName("source_title") val sourceTitle: String = "", val blocks: List<Block> = emptyList())
@Serializable data class BoardRow(val age: String, @SerialName("do") val action: String, val notice: String)
@Serializable data class DomainBoard(val title: String, val key: String, val rows: List<BoardRow>)
@Serializable data class WhoRow(val age: String, val act: String, val sleep: String, val screen: String, val restrain: String)
@Serializable data class Source(val code: String, val org: String, val title: String, val date: String = "", val scope: String = "", val url: String = "", val checked: String = "")
@Serializable data class LedgerRow(val id: String, val claim: String, val age: String, val source: String, val level: String, val checked: String, val limit: String)

@Serializable
data class About(
    val method: List<Block> = emptyList(),
    val confidence: List<Block> = emptyList(),
    val top: List<Block> = emptyList(),
    val ledger: List<LedgerRow> = emptyList(),
    @SerialName("vaccine_note") val vaccineNote: String = "",
    @SerialName("checkup_note") val checkupNote: String = "",
)

object ContentJson {
    val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    fun parse(text: String): Content = json.decodeFromString(Content.serializer(), text)
}

class ContentRepository(private val context: Context) {
    private val lock = Mutex()
    @Volatile private var cached: Content? = null
    val now: Content? get() = cached

    suspend fun get(): Content = cached ?: lock.withLock {
        cached ?: withContext(Dispatchers.IO) {
            context.assets.open("content.json").bufferedReader().use { ContentJson.parse(it.readText()) }
        }.also { cached = it }
    }
}
