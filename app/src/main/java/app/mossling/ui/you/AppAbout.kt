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

private sealed interface Check {
    data object Idle : Check
    data object Busy : Check
    data object Latest : Check
    data class Found(val r: Update.Release) : Check
    data class Failed(val why: String) : Check
}

/**
 * The app itself: name, version and build, check for updates, what changed, privacy, licences, feedback, and the
 * handbook's sources. The update check is one request when tapped; nothing is checked in the background.
 */
@Composable
fun AppAboutScreen(a: AppAboutActions) {
    val ctx = LocalContext.current
    val info = remember { runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0) }.getOrNull() }
    val version = info?.versionName ?: ""
    val build = info?.let { if (android.os.Build.VERSION.SDK_INT >= 28) it.longVersionCode else @Suppress("DEPRECATION") it.versionCode.toLong() } ?: 0
    var check by remember { mutableStateOf<Check>(Check.Idle) }
    val scope = rememberCoroutineScope()
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
        item {
            Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("检查更新", style = MaterialTheme.typography.titleMedium)
                            Text(when (val c = check) {
                                Check.Idle -> "点一下，读取最新发布的版本号"
                                Check.Busy -> "正在检查…"
                                Check.Latest -> "已经是最新版本"
                                is Check.Found -> "有新版本 ${c.r.version}" + if (c.r.date.isNotBlank()) " · ${c.r.date}" else ""
                                is Check.Failed -> c.why
                            }, style = MaterialTheme.typography.bodySmall, color = if (check is Check.Found) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        if (check == Check.Busy) CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
                        else if (check !is Check.Found) Button(onClick = {
                            check = Check.Busy
                            scope.launch {
                                check = runCatching { Update.latest() }.fold(
                                    { r -> if (Update.newer(r.version, version)) Check.Found(r) else Check.Latest },
                                    { e -> Check.Failed(if (e is java.net.UnknownHostException || e is java.net.SocketTimeoutException) "没有连上网络，稍后再试" else "暂时读取不到发布信息，稍后再试") })
                            }
                        }, shape = RoundedCornerShape(16.dp), modifier = Modifier.heightIn(min = 44.dp)) { Text("检查") }
                    }
                    (check as? Check.Found)?.r?.let { r ->
                        if (r.notes.isNotBlank()) Text(r.notes.take(800), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 10.dp))
                        Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = { open(r.apk ?: r.page) }, shape = RoundedCornerShape(16.dp), modifier = Modifier.heightIn(min = 48.dp)) { Text("下载新版本") }
                            androidx.compose.material3.TextButton(onClick = { open(r.page) }) { Text("在发布页查看") }
                        }
                        Text("下载完成后点开安装包，由系统完成安装；记录不会丢失。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
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
