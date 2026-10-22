package app.mossling.ui.you

import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.background
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
 * content sources. The update check is one request when tapped; nothing is checked in the background.
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
                app.mossling.ui.ip.Duo(app.mossling.ui.theme.LocalCompanion.current, size = 88.dp)
                Text("小苔花", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 8.dp))
                Text("Mossling · 0–3 岁早教活动规划", style = MaterialTheme.typography.bodyMedium)
                Text("苔花如米小，也学牡丹开。", style = MaterialTheme.typography.bodySmall, fontStyle = androidx.compose.ui.text.font.FontStyle.Normal, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 10.dp))
                Text("清 · 袁枚《苔》", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("版本 $version · 构建 $build", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
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
                        Text("记录只保存在本机。", style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 4.dp))
                        Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = {
                                val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_SUBJECT, "小苔花异常退出记录").putExtra(Intent.EXTRA_TEXT, text)
                                runCatching { ctx.startActivity(Intent.createChooser(send, "分享异常记录")) }
                            }, shape = RoundedCornerShape(16.dp)) { Text("分享记录") }
                            androidx.compose.material3.TextButton(onClick = { app.mossling.CrashLog.clear(ctx); crash = null }) { Text("删除") }
                        }
                    }
                }
            }
        }
        item {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                ListGroup("条款与声明", listOf(
                    Triple(G.Check, "使用条款") { a.doc("TERMS.md") },
                    Triple(G.Shield, "隐私政策") { a.doc("PRIVACY.md") },
                    Triple(G.Idea, "免责声明") { a.doc("DISCLAIMER.md") },
                ))
                ListGroup("资料", listOf(
                    Triple(G.Journal, "内容来源") { a.sources() },
                    Triple(G.Bead, "开源许可") { a.licenses() },
                    Triple(G.Clock, "更新日志") { a.doc("CHANGELOG.md") },
                    Triple(G.Share, "反馈问题") { open("https://github.com/${Update.Repo}/issues"); Unit },
                ))
            }
        }
        item {
            Column(Modifier.fillMaxWidth().padding(horizontal = 28.dp, vertical = 20.dp)) {
                Text("免责声明", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("本应用内容仅供家庭养育参考，不构成医疗诊断或治疗建议。如对儿童健康或发育有疑虑，请咨询儿科医生或当地妇幼保健机构。",
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
            }
        }
    }
}

@Composable
private fun ListGroup(title: String, rows: List<Triple<G, String, () -> Unit>>) {
    Column {
        Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(start = 16.dp, bottom = 6.dp))
        Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
            Column {
                rows.forEachIndexed { i, (g, t, f) ->
                    if (i > 0) androidx.compose.material3.HorizontalDivider(Modifier.padding(start = 56.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
                    Item(g, t, "", f)
                }
            }
        }
    }
}

@Composable
private fun Item(g: G, title: String, sub: String, onClick: () -> Unit) {
    Surface(onClick = onClick, color = Color.Transparent, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.heightIn(min = 56.dp).padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Glyph(g, size = 22.dp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                if (sub.isNotBlank()) Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/**
 * A document from the repository (privacy statement, change log), typeset like a document: one title, numbered
 * section headings, body text at reading size, lists with hanging indents, tables as ruled grids.
 */
@Composable
fun DocScreen(name: String, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val lines = remember(name) { runCatching { ctx.assets.open(name).bufferedReader().readLines() }.getOrDefault(listOf("读取不到这份文件。")) }
    // group consecutive table lines into one table
    val blocks = remember(lines) {
        val out = mutableListOf<Pair<String, List<String>>>()
        lines.forEach { l ->
            val t = l.trimEnd()
            if (t.startsWith("|")) { if (out.lastOrNull()?.first == "table") out[out.lastIndex] = "table" to (out.last().second + t) else out += "table" to listOf(t) }
            else out += "line" to listOf(t)
        }
        out
    }
    val rule = MaterialTheme.colorScheme.outlineVariant
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 40.dp)) {
        item { Bar("", onBack) }
        items(blocks.size) { i ->
            val (kind, ls) = blocks[i]
            if (kind == "table") {
                val rows = ls.map { r -> r.trim('|').split("|").map { it.trim() } }.filterNot { r -> r.all { it.matches(Regex(":?-{3,}:?")) } }
                Surface(shape = RoundedCornerShape(12.dp), color = Color.Transparent, border = androidx.compose.foundation.BorderStroke(1.dp, rule), modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                    Column {
                        rows.forEachIndexed { ri, r ->
                            if (ri > 0) androidx.compose.material3.HorizontalDivider(color = rule)
                            Row(Modifier.fillMaxWidth().then(if (ri == 0) Modifier.background(MaterialTheme.colorScheme.surfaceContainer) else Modifier).padding(horizontal = 12.dp, vertical = 8.dp)) {
                                r.forEachIndexed { ci, c ->
                                    Text(app.mossling.ui.components.rich(c), style = if (ri == 0) MaterialTheme.typography.labelLarge else MaterialTheme.typography.bodySmall,
                                        modifier = if (ci == 0) Modifier.width(88.dp).padding(end = 8.dp) else Modifier.weight(1f))
                                }
                            }
                        }
                    }
                }
            } else {
                val l = ls.first()
                when {
                    l.isBlank() -> Spacer(Modifier.size(4.dp))
                    l.startsWith("# ") -> Text(l.drop(2), style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 4.dp, bottom = 12.dp))
                    l.startsWith("## ") -> Column(Modifier.padding(top = 18.dp, bottom = 6.dp)) {
                        androidx.compose.material3.HorizontalDivider(color = rule)
                        Text(l.drop(3), style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 14.dp))
                    }
                    l.startsWith("### ") -> Text(l.drop(4), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 12.dp, bottom = 4.dp))
                    l.startsWith("- ") || l.startsWith("  - ") -> Row(Modifier.padding(start = if (l.startsWith("  ")) 16.dp else 0.dp, top = 3.dp, bottom = 3.dp)) {
                        Text("•", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary, modifier = Modifier.width(16.dp))
                        Text(app.mossling.ui.components.rich(l.trimStart().drop(2)), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                    }
                    Regex("^\\d+\\. ").containsMatchIn(l) -> Row(Modifier.padding(top = 3.dp, bottom = 3.dp)) {
                        val n = l.substringBefore(". ")
                        Text("$n.", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary, fontFamily = Numerals, modifier = Modifier.width(22.dp))
                        Text(app.mossling.ui.components.rich(l.substringAfter(". ")), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                    }
                    l.startsWith("适用于") || l.startsWith("生效日期") -> Text(l, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    else -> Text(app.mossling.ui.components.rich(l), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(vertical = 3.dp))
                }
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
                            shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth().padding(top = 12.dp).heightIn(min = 52.dp)) { Text(if (canInstall) "安装 ${r.version}" else "允许小苔花安装更新") }
                        Text(if (canInstall) "由系统安装器完成安装，记录不会丢失。" else "Android 需要你允许一次「安装未知应用」，之后回到这里点安装。",
                            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
                    }
                    else -> Unit
                }
            }
        }
    }
}
