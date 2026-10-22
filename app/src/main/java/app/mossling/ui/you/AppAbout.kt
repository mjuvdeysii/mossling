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
                Row(verticalAlignment = Alignment.Bottom) {
                    Creature(Kind.Moss, Modifier.size(64.dp), mood = Mood.Happy)
                    Creature(Kind.Otto, Modifier.size(72.dp))
                }
                Text("Mossling 苔生", fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 6.dp))
                Text("0–3 岁早教活动规划", style = MaterialTheme.typography.bodyMedium)
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
            Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Column {
                    val rows = listOf(
                        Triple(G.Note, "更新日志") { a.doc("CHANGELOG.md") },
                        Triple(G.Shield, "隐私说明") { a.doc("PRIVACY.md") },
                        Triple(G.Journal, "内容来源") { a.sources() },
                        Triple(G.Bead, "开源许可") { a.licenses() },
                        Triple(G.Share, "反馈问题") { open("https://github.com/${Update.Repo}/issues") },
                    )
                    rows.forEachIndexed { i, (g, t, f) ->
                        if (i > 0) androidx.compose.material3.HorizontalDivider(Modifier.padding(start = 56.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
                        Item(g, t, "", f)
                    }
                }
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
                    else -> Text(app.mossling.ui.components.rich(l), style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(vertical = 3.dp))
                }
            }
        }
    }
}
