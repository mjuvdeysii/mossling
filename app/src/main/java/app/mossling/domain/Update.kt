package app.mossling.domain

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL

/**
 * "检查更新": one request, only when the person taps it, to the repository's latest release. Nothing is sent but the
 * request itself; nothing runs in the background.
 */
object Update {
    /** where releases are published */
    const val Repo = "mjuvdeysii/mossling"
    val Page = "https://github.com/$Repo/releases/latest"

    data class Release(val version: String, val notes: String, val apk: String?, val page: String, val date: String)

    suspend fun latest(): Release = withContext(Dispatchers.IO) {
        val c = URL("https://api.github.com/repos/$Repo/releases/latest").openConnection() as HttpURLConnection
        c.connectTimeout = 10_000; c.readTimeout = 10_000
        c.setRequestProperty("Accept", "application/vnd.github+json"); c.setRequestProperty("User-Agent", "Mossling")
        try {
            if (c.responseCode != 200) throw IllegalStateException("HTTP ${c.responseCode}")
            parse(c.inputStream.bufferedReader().readText())
        } finally { c.disconnect() }
    }

    fun parse(json: String): Release {
        val o = Json.parseToJsonElement(json).jsonObject
        fun s(k: String) = o[k]?.jsonPrimitive?.content.orEmpty()
        val apk = o["assets"]?.jsonArray?.map { it.jsonObject }?.firstOrNull { (it["name"]?.jsonPrimitive?.content ?: "").endsWith(".apk") }
            ?.get("browser_download_url")?.jsonPrimitive?.content
        return Release(s("tag_name").removePrefix("v"), s("body"), apk, s("html_url").ifBlank { Page }, s("published_at").take(10))
    }

    /** true when [latest] is a higher version than [current] ("0.1.1", "0.1.1.1012", "0.1.1-dev" all compare by numbers) */
    fun newer(latest: String, current: String): Boolean {
        fun parts(v: String) = v.split('.', '-', '+').map { it.toIntOrNull() ?: -1 }.takeWhile { it >= 0 }
        val a = parts(latest).take(3); val b = parts(current).take(3)
        for (i in 0 until maxOf(a.size, b.size)) { val x = a.getOrElse(i) { 0 }; val y = b.getOrElse(i) { 0 }; if (x != y) return x > y }
        return false
    }
}
