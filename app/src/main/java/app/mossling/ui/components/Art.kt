package app.mossling.ui.components

import android.content.Context
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * The handbook's illustrations: a picture for each step of each play, and a cover for most months
 * (assets/art, index.json). Decoded off the main thread and kept in a small cache.
 */
object ArtIndex {
    @Volatile private var loaded: Triple<Map<String, List<String>>, Map<Int, String>, Map<String, Float>>? = null
    private val cache = object : LruCache<String, ImageBitmap>(24 * 1024 * 1024) {
        override fun sizeOf(key: String, value: ImageBitmap) = value.width * value.height * 4
    }

    private fun load(ctx: Context) = loaded ?: runCatching {
        val o = Json.parseToJsonElement(ctx.assets.open("art/index.json").bufferedReader().readText()).jsonObject
        val plays = o["plays"]!!.jsonObject.mapValues { (_, v) -> v.jsonArray.map { it.jsonPrimitive.content } }
        val covers = o["covers"]!!.jsonObject.entries.associate { it.key.toInt() to it.value.jsonPrimitive.content }
        val ratio = o["size"]!!.jsonObject.mapValues { (_, v) -> v.jsonArray.let { it[0].jsonPrimitive.content.toFloat() / it[1].jsonPrimitive.content.toFloat() } }
        Triple(plays, covers, ratio)
    }.getOrElse { Triple(emptyMap(), emptyMap(), emptyMap()) }.also { loaded = it }

    fun steps(ctx: Context, code: String): List<String> = load(ctx).first[code].orEmpty()
    fun cover(ctx: Context, month: Int): String? = load(ctx).second[month]
    fun ratio(ctx: Context, name: String): Float = load(ctx).third[name] ?: 1.33f

    suspend fun bitmap(ctx: Context, name: String): ImageBitmap? = cache.get(name) ?: withContext(Dispatchers.IO) {
        runCatching { ctx.assets.open("art/$name").use { BitmapFactory.decodeStream(it) }?.asImageBitmap() }.getOrNull()?.also { cache.put(name, it) }
    }
}

/** One illustration at its own proportions; a quiet placeholder of the same size while it decodes. */
@Composable
fun Art(name: String, label: String, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val ratio = remember(name) { ArtIndex.ratio(ctx, name) }
    val img by produceState<ImageBitmap?>(null, name) { value = ArtIndex.bitmap(ctx, name) }
    val m = modifier.aspectRatio(ratio).semantics { contentDescription = label }
    val b = img
    if (b != null) Image(b, null, m, contentScale = ContentScale.Crop)
    else Box(m.background(MaterialTheme.colorScheme.surfaceContainerHigh))
}
