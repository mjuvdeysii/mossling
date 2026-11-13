package app.mossling.ui.components

import android.content.Context
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.io.InputStream

/**
 * Illustration style: 3D soft-vinyl (`Vinyl`, "立体") or 2D picture-book (`Flat`, "平面").
 * Aligned with iOS `ArtStyle` (`ios/Mossling/IP/Creature.swift`).
 */
enum class ArtStyle(val raw: String, val label: String) {
    Vinyl("vinyl", "立体"),
    Flat("flat", "平面");

    fun resolve(name: String): String {
        if (this == Flat && (name.startsWith("ic_") || name.startsWith("tray_") || name.startsWith("child_") || name.startsWith("stage_") || name.startsWith("cover_") || name.startsWith("play_"))) {
            return "2d_$name"
        }
        return name
    }

    companion object {
        fun fromRaw(raw: String?): ArtStyle = entries.firstOrNull { it.raw == raw } ?: Vinyl
    }
}

val LocalArtStyle = compositionLocalOf { ArtStyle.Vinyl }

/**
 * The app's illustrations: play step pictures, month covers, 3D/2D companion sprites, child stages,
 * material trays, and stickers (`assets/art`, `index.json`). Decoded off the main thread and cached.
 */
object ArtIndex {
    /** Screenshot tests read the pictures from the source tree; the app reads them from its assets. */
    @Volatile var source: ((String) -> InputStream)? = null

    internal fun open(ctx: Context, path: String): InputStream {
        source?.let { return it(path) }
        return runCatching { ctx.assets.open(path) }.getOrElse {
            val f1 = File("src/main/assets/$path")
            if (f1.exists()) return f1.inputStream()
            val f2 = File("app/src/main/assets/$path")
            if (f2.exists()) return f2.inputStream()
            throw it
        }
    }

    @Volatile private var loaded: Triple<Map<String, List<String>>, Map<Int, String>, Map<String, Float>>? = null
    private val cache = object : LruCache<String, ImageBitmap>(64 * 1024 * 1024) {
        override fun sizeOf(key: String, value: ImageBitmap) = value.width * value.height * 4
    }

    private fun load(ctx: Context) = loaded ?: runCatching {
        val o = Json.parseToJsonElement(open(ctx, "art/index.json").bufferedReader().readText()).jsonObject
        val plays = o["plays"]!!.jsonObject.mapValues { (_, v) -> v.jsonArray.map { it.jsonPrimitive.content } }
        val covers = o["covers"]!!.jsonObject.entries.associate { it.key.toInt() to it.value.jsonPrimitive.content }
        val ratio = o["size"]!!.jsonObject.mapValues { (_, v) -> v.jsonArray.let { it[0].jsonPrimitive.content.toFloat() / it[1].jsonPrimitive.content.toFloat() } }
        Triple(plays, covers, ratio)
    }.getOrElse { Triple(emptyMap(), emptyMap(), emptyMap()) }.also { loaded = it }

    fun steps(ctx: Context, code: String): List<String> = load(ctx).first[code].orEmpty()
    fun cover(ctx: Context, month: Int): String? = load(ctx).second[month]
    fun ratio(ctx: Context, name: String): Float = load(ctx).third[name] ?: 1.33f

    fun bitmapSync(ctx: Context, name: String, maxWidth: Int = 1024): ImageBitmap? {
        val bucket = maxWidth.coerceAtLeast(64).let { Integer.highestOneBit(it - 1) shl 1 }
        val key = "$name@$bucket"
        cache.get(key)?.let { return it }
        return runCatching {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            open(ctx, "art/$name").use { BitmapFactory.decodeStream(it, null, bounds) }
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= bucket) sample *= 2
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888
            }
            open(ctx, "art/$name").use { BitmapFactory.decodeStream(it, null, opts) }?.also { it.prepareToDraw() }?.asImageBitmap()
        }.getOrNull()?.also { cache.put(key, it) }
    }

    /**
     * Decoded no wider than [maxWidth] pixels, without banding, off the main thread; one cache entry per name and width bucket.
     */
    suspend fun bitmap(ctx: Context, name: String, maxWidth: Int = 4096): ImageBitmap? {
        val bucket = maxWidth.coerceAtLeast(64).let { Integer.highestOneBit(it - 1) shl 1 }
        val key = "$name@$bucket"
        cache.get(key)?.let { return it }
        return withContext(Dispatchers.IO) {
            bitmapSync(ctx, name, bucket)
        }
    }
}

/** One illustration at its own proportions; a quiet placeholder of the same size while it decodes, then a short fade. */
@Composable
fun Art(name: String, label: String, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    val style = LocalArtStyle.current
    val resolved = remember(name, style) { style.resolve(name) }
    val ratio = remember(resolved, name) { ArtIndex.ratio(ctx, resolved).takeIf { it != 1.33f } ?: ArtIndex.ratio(ctx, name) }
    BoxWithConstraints(
        modifier
            .aspectRatio(ratio)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .semantics { contentDescription = label }
    ) {
        val px = constraints.maxWidth.coerceAtLeast(128)
        val inspect = LocalInspectionMode.current
        val syncImg = remember(resolved, name, inspect) {
            if (inspect || ArtIndex.source != null) {
                ArtIndex.bitmapSync(ctx, resolved, px) ?: ArtIndex.bitmapSync(ctx, name, px)
            } else null
        }
        val img by produceState(syncImg, resolved, name, px) {
            if (value == null) {
                value = ArtIndex.bitmap(ctx, resolved, px) ?: ArtIndex.bitmap(ctx, name, px)
            }
        }
        val alpha by animateFloatAsState(if (img != null || inspect) 1f else 0f, tween(180), label = "art")
        img?.let {
            Image(
                bitmap = it,
                contentDescription = null,
                modifier = Modifier.matchParentSize().graphicsLayer { this.alpha = alpha },
                contentScale = ContentScale.Crop,
                filterQuality = FilterQuality.High,
            )
        }
    }
}

/** Transparent sprite / sticker icon (`ic_*.webp`, `tray_*.webp`, `child_*.webp`, `ip_*.webp`) that switches with [LocalArtStyle]. */
@Composable
fun Sticker(
    name: String,
    modifier: Modifier = Modifier,
    size: Dp? = null,
    contentDescription: String? = null,
    scale: ContentScale = ContentScale.Fit,
) {
    val ctx = LocalContext.current
    val style = LocalArtStyle.current
    val file = remember(name, style) {
        val n = if (name.endsWith(".webp")) name else "$name.webp"
        style.resolve(n)
    }
    val fallback = remember(name) { if (name.endsWith(".webp")) name else "$name.webp" }
    val density = LocalDensity.current
    val maxPx = remember(size, density) {
        size?.let { with(density) { (it.toPx() * 2.5f).toInt().coerceAtLeast(128) } } ?: 512
    }
    val inspect = LocalInspectionMode.current
    val initial = remember(file, fallback, maxPx, inspect) {
        ArtIndex.bitmapSync(ctx, file, maxPx) ?: ArtIndex.bitmapSync(ctx, fallback, maxPx)
    }
    val img by produceState(initial, file, fallback, maxPx) {
        if (value == null) {
            value = ArtIndex.bitmap(ctx, file, maxPx) ?: ArtIndex.bitmap(ctx, fallback, maxPx)
        }
    }
    val mod = (if (size != null) modifier.size(size) else modifier).let {
        if (contentDescription != null) it.semantics { this.contentDescription = contentDescription } else it
    }
    Box(mod) {
        img?.let {
            Image(
                bitmap = it,
                contentDescription = null,
                modifier = Modifier.matchParentSize(),
                contentScale = scale,
                filterQuality = FilterQuality.High,
            )
        }
    }
}

/** Wooden activity tray illustration (`tray_a01.webp`..`tray_n06.webp`), switching between 3D vinyl and 2D flat style. */
@Composable
fun TrayArt(code: String, modifier: Modifier = Modifier, size: Dp? = null, label: String? = null) {
    val name = remember(code) { "tray_${code.lowercase()}.webp" }
    Sticker(name = name, modifier = modifier, size = size, contentDescription = label)
}
