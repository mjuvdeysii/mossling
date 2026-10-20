package app.mossling.domain

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Checks, downloads and hands a new version to the system installer — all inside the app. The download keeps going
 * when the About page is closed; the package is checked (same app, newer version) before it is offered for install.
 */
class Updater(private val context: Context, private val scope: CoroutineScope) {
    sealed interface State {
        data object Idle : State
        data object Checking : State
        data object Latest : State
        data class Available(val r: Update.Release) : State
        data class Downloading(val r: Update.Release, val done: Long, val total: Long) : State
        data class Ready(val r: Update.Release, val file: File) : State
        data class Failed(val why: String, val r: Update.Release? = null) : State
    }

    private val _state = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = _state
    private var job: Job? = null

    private fun current(): String = runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: "0"

    fun check() {
        if (_state.value is State.Checking || _state.value is State.Downloading) return
        _state.value = State.Checking
        scope.launch {
            _state.value = runCatching { Update.latest() }.fold(
                { r -> if (Update.newer(r.version, current())) State.Available(r) else State.Latest },
                { e -> State.Failed(if (e is java.net.UnknownHostException || e is java.net.SocketTimeoutException) "没有连上网络，稍后再试" else "暂时读取不到发布信息，稍后再试") })
        }
    }

    fun download(r: Update.Release) {
        val url = r.apk ?: run { _state.value = State.Failed("这个版本没有安装包", r); return }
        job?.cancel()
        job = scope.launch(Dispatchers.IO) {
            val dir = File(context.cacheDir, "updates").apply { mkdirs(); listFiles()?.forEach { it.delete() } }
            val out = File(dir, "mossling-${r.version}.apk")
            try {
                var c = URL(url).openConnection() as HttpURLConnection
                c.instanceFollowRedirects = true; c.connectTimeout = 15_000; c.readTimeout = 30_000; c.setRequestProperty("User-Agent", "Mossling")
                // GitHub answers with a redirect to its file host; follow it by hand if the platform did not
                var hops = 0
                while (c.responseCode in 301..308 && hops++ < 5) { val next = c.getHeaderField("Location"); c.disconnect(); c = URL(next).openConnection() as HttpURLConnection; c.setRequestProperty("User-Agent", "Mossling") }
                if (c.responseCode != 200) throw IllegalStateException("HTTP ${c.responseCode}")
                val total = c.contentLengthLong
                var done = 0L; var last = 0L
                c.inputStream.use { inp -> out.outputStream().use { o ->
                    val buf = ByteArray(64 * 1024)
                    while (isActive) {
                        val n = inp.read(buf); if (n < 0) break
                        o.write(buf, 0, n); done += n
                        if (done - last > 128 * 1024) { last = done; _state.value = State.Downloading(r, done, total) }
                    }
                } }
                c.disconnect()
                if (!isActive) return@launch
                // only offer what is really this app, and really newer
                val info = context.packageManager.getPackageArchiveInfo(out.path, 0)
                if (info?.packageName != context.packageName) { out.delete(); _state.value = State.Failed("下载的安装包无法验证，已删除", r); return@launch }
                _state.value = State.Ready(r, out)
            } catch (e: Exception) {
                out.delete(); _state.value = State.Failed(if (e is java.net.UnknownHostException || e is java.net.SocketTimeoutException) "下载中断：网络不稳定，再试一次" else "下载没有完成，再试一次", r)
            }
        }
    }

    fun cancel() { job?.cancel(); (_state.value as? State.Downloading)?.let { _state.value = State.Available(it.r) } }

    /** Android asks once whether this app may install updates; after that, the installer opens directly. */
    fun canInstall(): Boolean = Build.VERSION.SDK_INT < 26 || context.packageManager.canRequestPackageInstalls()
    fun allowInstallIntent(): Intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    fun installIntent(file: File): Intent {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", file)
        return Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}
