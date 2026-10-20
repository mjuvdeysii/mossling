package app.mossling.ui.you

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.mossling.domain.Update
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Kind
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.Numerals
import kotlinx.coroutines.launch

data class AppAboutActions(
    val back: () -> Unit = {},
    val sources: () -> Unit = {},
    val licenses: () -> Unit = {},
    val doc: (String) -> Unit = {},
)

/**
 * The app itself: name, version and build, check for updates, what changed, privacy, licences, feedback, and the
 * handbook's sources. The update check is one request when tapped; nothing is checked in the background.
 */
@Composable
fun AppAboutScreen(a: AppAboutActions, updater: app.mossling.domain.Updater? = null) {
    val ctx = LocalContext.current
    val info = remember { runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0) }.getOrNull() }
    val version = info?.versionName ?: ""
    val build = info?.let { if (android.os.Build.VERSION.SDK_INT >= 28) it.longVersionCode else @Suppress("DEPRECATION") it.versionCode.toLong() } ?: 0
    val idle = remember { kotlinx.coroutines.flow.MutableStateFlow<app.mossling.domain.Updater.State>(app.mossling.domain.Updater.State.Idle) }
    val st by (updater?.state ?: idle).collectAsState()
    fun open(url: String) = runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 48.dp)) {
        item { Bar("", a.back) }
        item {
            Column(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Creature(Kind.Moss, Modifier.size(84.dp), mood = Mood.Happy)
                    Creature(Kind.Otto, Modifier.size(96.dp))
                }
                Text("Mossling", fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.primary)
                Text("苔生 · 0–3 岁养育手帐", style = MaterialTheme.typography.titleMedium)
                Text("版本 $version（$build）", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
            }
        }
        item { UpdateCard(st, updater) { open(it) } }
        item {
            var crash by remember { mutableStateOf(app.mossling.CrashLog.read(ctx)) }
            crash?.let { text ->
                Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.errorContainer, contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 16.dp)) {
                    Column(Modifier.padding(16.dp)) {
                        Text("上次异常退出", style = MaterialTheme.typography.titleMedium)
                        Text("原因记在这台手机上，没有发送到任何地方。分享给开发者可以更快修好。", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 4.dp))
                        Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = {
                                val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_SUBJECT, "苔生异常退出记录").putExtra(Intent.EXTRA_TEXT, text)
                                runCatching { ctx.startActivity(Intent.createChooser(send, "分享异常记录")) }
                            }, shape = RoundedCornerShape(16.dp)) { Text("分享记录") }
                            androidx.compose.material3.TextButton(onClick = { app.mossling.CrashLog.clear(ctx); crash = null }) { Text("删除") }
                        }
                    }
                }
            }
        }
        item {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Item(G.Note, "更新日志", "每个版本改了什么") { a.doc("CHANGELOG.md") }
                Item(G.Check, "隐私说明", "不收集任何数据；联网只用于检查更新") { a.doc("PRIVACY.md") }
                Item(G.Journal, "内容来源", "法规、指南和机构原始文件，集中在这里") { a.sources() }
                Item(G.Bead, "开源许可", "字体与开源库") { a.licenses() }
                Item(G.Share, "反馈问题", "在 GitHub 上提交") { open("https://github.com/${Update.Repo}/issues") }
            }
        }
        item {
            Text("本应用提供养育参考信息，不能代替医生的诊断和建议。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth().padding(20.dp))
        }
    }
}

@Composable
private fun Item(g: G, title: String, sub: String, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Glyph(g, size = 22.dp, color = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** A Markdown file from the repository shown as it is written: headings, paragraphs, lists and tables. */
@Composable
fun DocScreen(name: String, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val lines = remember(name) { runCatching { ctx.assets.open(name).bufferedReader().readLines() }.getOrDefault(listOf("读取不到这份文件。")) }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 48.dp)) {
        item { Bar("", onBack) }
        items(lines.size) { i ->
            val l = lines[i].trimEnd()
            fun plain(s: String) = s.replace("**", "").replace("`", "")
            when {
                l.isBlank() -> Spacer(Modifier.size(6.dp))
                l.startsWith("# ") -> Text(plain(l.drop(2)), style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(vertical = 8.dp))
                l.startsWith("## ") -> Text(plain(l.drop(3)), style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 16.dp, bottom = 4.dp))
                l.startsWith("- ") -> Row(Modifier.padding(vertical = 3.dp)) { Text("·", modifier = Modifier.width(16.dp), fontWeight = FontWeight.Bold); Text(plain(l.drop(2)), style = MaterialTheme.typography.bodyMedium) }
                l.startsWith("|") -> {
                    val cells = l.trim('|').split("|").map { plain(it.trim()) }
                    if (cells.all { it.matches(Regex("-{3,}")) }) Unit
                    else Row(Modifier.padding(vertical = 4.dp)) {
                        cells.forEachIndexed { j, c -> Text(c, style = if (j == 0) MaterialTheme.typography.titleSmall else MaterialTheme.typography.bodyMedium, modifier = if (j == 0) Modifier.width(96.dp) else Modifier.weight(1f)) }
                    }
                }
                else -> Text(plain(l), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(vertical = 2.dp))
            }
        }
    }
}

/** Check → download (with progress, cancellable) → install, without leaving the app. */
@Composable
private fun UpdateCard(st: app.mossling.domain.Updater.State, u: app.mossling.domain.Updater?, open: (String) -> Unit) {
    val ctx = LocalContext.current
    Surface(shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(16.dp)) {
        Column(Modifier.padding(18.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("检查更新", style = MaterialTheme.typography.titleMedium)
                    Text(when (st) {
                        is app.mossling.domain.Updater.State.Idle -> "点一下，读取最新发布的版本"
                        is app.mossling.domain.Updater.State.Checking -> "正在检查…"
                        is app.mossling.domain.Updater.State.Latest -> "已经是最新版本"
                        is app.mossling.domain.Updater.State.Available -> "有新版本 ${st.r.version}" + if (st.r.date.isNotBlank()) " · ${st.r.date}" else ""
                        is app.mossling.domain.Updater.State.Downloading -> "正在下载 ${st.r.version}" + if (st.total > 0) " · ${st.done * 100 / st.total}%" else ""
                        is app.mossling.domain.Updater.State.Ready -> "${st.r.version} 已下载，可以安装"
                        is app.mossling.domain.Updater.State.Failed -> st.why
                    }, style = MaterialTheme.typography.bodySmall,
                        color = if (st is app.mossling.domain.Updater.State.Available || st is app.mossling.domain.Updater.State.Ready) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                }
                when (st) {
                    is app.mossling.domain.Updater.State.Checking -> CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
                    is app.mossling.domain.Updater.State.Idle, is app.mossling.domain.Updater.State.Latest -> Button(onClick = { u?.check() }, shape = RoundedCornerShape(16.dp), modifier = Modifier.heightIn(min = 44.dp)) { Text("检查") }
                    is app.mossling.domain.Updater.State.Failed -> Button(onClick = { st.r?.let { u?.download(it) } ?: u?.check() }, shape = RoundedCornerShape(16.dp), modifier = Modifier.heightIn(min = 44.dp)) { Text("重试") }
                    else -> Unit
                }
            }
            val rel = when (st) { is app.mossling.domain.Updater.State.Available -> st.r; is app.mossling.domain.Updater.State.Downloading -> st.r; is app.mossling.domain.Updater.State.Ready -> st.r; else -> null }
            rel?.let { r ->
                if (r.notes.isNotBlank()) Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainerLowest, modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
                    Text(r.notes.replace("**", "").take(900), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(14.dp))
                }
                when (st) {
                    is app.mossling.domain.Updater.State.Available -> Button(onClick = { u?.download(r) }, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth().padding(top = 12.dp).heightIn(min = 52.dp)) { Text("下载并安装") }
                    is app.mossling.domain.Updater.State.Downloading -> {
                        val f = if (st.total > 0) st.done.toFloat() / st.total else 0f
                        androidx.compose.material3.LinearProgressIndicator(progress = { f }, modifier = Modifier.fillMaxWidth().padding(top = 14.dp).heightIn(min = 8.dp))
                        Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text("%.1f / %.1f MB".format(st.done / 1048576f, st.total.coerceAtLeast(0) / 1048576f), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                            androidx.compose.material3.TextButton(onClick = { u?.cancel() }) { Text("取消") }
                        }
                    }
                    is app.mossling.domain.Updater.State.Ready -> {
                        val canInstall = u?.canInstall() ?: false
                        Button(onClick = { runCatching { ctx.startActivity(if (canInstall) u!!.installIntent(st.file) else u!!.allowInstallIntent()) } },
                            shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth().padding(top = 12.dp).heightIn(min = 52.dp)) { Text(if (canInstall) "安装 ${r.version}" else "允许苔生安装更新") }
                        Text(if (canInstall) "由系统安装器完成安装，记录不会丢失。" else "Android 需要你允许一次「安装未知应用」，之后回到这里点安装。",
                            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
                    }
                    else -> Unit
                }
            }
        }
    }
}
