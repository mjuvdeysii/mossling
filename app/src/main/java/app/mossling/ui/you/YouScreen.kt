package app.mossling.ui.you

import app.mossling.ui.components.Glyph
import app.mossling.ui.components.G
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.material3.OutlinedTextField
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.TickKind
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.NumberRod
import app.mossling.ui.components.PinkTower
import app.mossling.ui.components.md
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Kind
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import app.mossling.ui.theme.ThemeMode

data class YouActions(
    val companion: (Kind) -> Unit = {},
    val theme: (ThemeMode) -> Unit = {},
    val birth: () -> Unit = {},
    val topic: (String) -> Unit = {},
    val about: () -> Unit = {},
    val openMonth: (Int) -> Unit = {},
    val importFile: () -> Unit = {},
    val exportJson: () -> Unit = {},
    val exportCsv: () -> Unit = {},
    val clearAll: () -> Unit = {},
    val nickname: (String) -> Unit = {},
    val sex: (String?) -> Unit = {},
    val search: () -> Unit = {},
    val lock: (Boolean) -> Unit = {},
    val appAbout: () -> Unit = {},
    val journal: (Boolean) -> Unit = {},
)

/**
 * 我的: who the child is and how the app behaves — nothing that belongs to a day or a month. Grouped the way Android
 * settings are: the child, the companion, features, display, records, about. Each row says what it is; values sit on
 * the right; destructive actions are red and last.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun YouScreen(ui: AppUi, a: YouActions, modifier: Modifier = Modifier) {
    var profile by remember { mutableStateOf(false) }
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val canLock = remember { runCatching { androidx.biometric.BiometricManager.from(ctx).canAuthenticate(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK) == androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS }.getOrDefault(false) }
    val version = remember { runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName }.getOrNull() ?: "" }
    LazyColumn(modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 32.dp)) {
        item("head") {
            Text("我的", style = MaterialTheme.typography.headlineLarge, modifier = Modifier.statusBarsPadding().padding(start = 20.dp, top = 12.dp, bottom = 8.dp))
        }
        // the child
        item("child") {
            Surface(onClick = { profile = true }, shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.primaryContainer, contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Creature(ui.settings.companion, Modifier.size(56.dp), mood = Mood.Happy)
                    Column(Modifier.weight(1f).padding(start = 14.dp)) {
                        Text(ui.settings.nickname.ifBlank { "宝宝" }, style = MaterialTheme.typography.titleLarge)
                        Text(ui.settings.birth?.let { "${it.year} 年 ${md(it)} 出生" + (ui.age?.let { g -> " · 第 ${g.lived} 天" } ?: "") } ?: "填写出生日期",
                            style = MaterialTheme.typography.bodySmall)
                    }
                    Glyph(G.Note, size = 20.dp)
                }
            }
        }
        item("companion") {
            Group("伙伴 · 选一位站在前面") {
                Row(Modifier.padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Pick(Kind.Moss, "Moss", "长着薄荷芽，安静地看", ui.settings.companion == Kind.Moss, Modifier.weight(1f)) { a.companion(Kind.Moss) }
                    Pick(Kind.Otto, "Otto", "带着金珠，专心一件事", ui.settings.companion == Kind.Otto, Modifier.weight(1f)) { a.companion(Kind.Otto) }
                }
            }
        }
        item("features") {
            Group("功能") {
                SwitchRow(G.Journal, "手帐", "喂养、睡眠、尿布、体温", ui.settings.journal, a.journal)
                if (canLock || ui.settings.lock) { Divide(); SwitchRow(G.Shield, "应用锁", "指纹、面容或锁屏密码", ui.settings.lock, a.lock) }
            }
        }
        item("display") {
            Group("显示") {
                Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                    Text("外观", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 8.dp))
                    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                        listOf(ThemeMode.System to "跟随系统", ThemeMode.Light to "浅色", ThemeMode.Dark to "深色").forEachIndexed { i, (t, l) ->
                            SegmentedButton(selected = ui.settings.theme == t, onClick = { a.theme(t) }, shape = SegmentedButtonDefaults.itemShape(i, 3)) { Text(l) }
                        }
                    }
                }
            }
        }
        item("data") {
            Group("记录") {
                LinkRow(G.Download, "导出记录文件", "JSON") { a.exportJson() }
                Divide(); LinkRow(G.Chart, "导出表格", "CSV") { a.exportCsv() }
                Divide(); LinkRow(G.Plus, "导入记录文件", "JSON") { a.importFile() }
                Divide(); LinkRow(G.Close, "清除全部数据", null, danger = true) { a.clearAll() }
            }
        }
        item("about") {
            Group("关于") {
                LinkRow(G.Journal, "内容来源", null) { a.about() }
                Divide(); LinkRow(G.Idea, "关于芽芽月历", version.ifBlank { null }) { a.appAbout() }
            }
        }
    }
    if (profile) ProfileSheet(ui, a) { profile = false }
}

/** A titled group of rows on one surface, the way system settings are laid out. */
@Composable
private fun Group(title: String, content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(start = 28.dp, top = 20.dp, bottom = 6.dp))
    Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        Column(content = content)
    }
}

@Composable
private fun Divide() = androidx.compose.material3.HorizontalDivider(Modifier.padding(start = 56.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))

@Composable
private fun SwitchRow(g: G, title: String, sub: String, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 60.dp).toggleable(on, role = androidx.compose.ui.semantics.Role.Switch, onValueChange = onChange).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Glyph(g, size = 22.dp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Column(Modifier.weight(1f).padding(start = 18.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        androidx.compose.material3.Switch(on, onCheckedChange = null)
    }
}

@Composable
private fun LinkRow(g: G, title: String, value: String?, danger: Boolean = false, onClick: () -> Unit) {
    val tint = if (danger) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Glyph(g, size = 22.dp, color = if (danger) tint else MaterialTheme.colorScheme.onSurfaceVariant)
        Text(title, style = MaterialTheme.typography.titleMedium, color = tint, modifier = Modifier.weight(1f).padding(start = 18.dp))
        if (value != null) Text(value, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** The child: nickname, birth date and sex in one place. */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun ProfileSheet(ui: AppUi, a: YouActions, onDismiss: () -> Unit) {
    var nick by remember { mutableStateOf(ui.settings.nickname) }
    androidx.compose.material3.ModalBottomSheet(onDismissRequest = { if (nick != ui.settings.nickname) a.nickname(nick); onDismiss() }, containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 24.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("宝宝", style = MaterialTheme.typography.headlineSmall)
            OutlinedTextField(nick, { nick = it.take(12) }, Modifier.fillMaxWidth(), label = { Text("小名") }, singleLine = true, shape = RoundedCornerShape(16.dp))
            Surface(onClick = a.birth, shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceContainer, modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(horizontal = 16.dp, vertical = 14.dp)) {
                    Text("出生日期", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                    Text(ui.settings.birth?.toString() ?: "填写", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                }
            }
            Text("性别", style = MaterialTheme.typography.titleMedium)
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                listOf("boy" to "男孩", "girl" to "女孩", null to "不填").forEachIndexed { i, (k, l) ->
                    SegmentedButton(selected = ui.settings.sex == k, onClick = { a.sex(k) }, shape = SegmentedButtonDefaults.itemShape(i, 3)) { Text(l) }
                }
            }
            androidx.compose.material3.Button(onClick = { if (nick != ui.settings.nickname) a.nickname(nick); onDismiss() }, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)) { Text("完成") }
        }
    }
}

@Composable
private fun Count(label: String, n: Int, total: Int, tint: Color, modifier: Modifier, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLowest, modifier = modifier) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text("$n", fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, color = tint)
                Text(" / $total", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(bottom = 6.dp))
            }
            Text(label, style = MaterialTheme.typography.labelLarge)
            NumberRod(n, total, Modifier.padding(top = 8.dp), height = 10.dp)
        }
    }
}

@Composable
private fun Pick(kind: Kind, name: String, line: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(28.dp), color = if (on) MaterialTheme.colorScheme.surfaceContainerLowest else MaterialTheme.colorScheme.surfaceContainerLow,
        border = if (on) BorderStroke(2.dp, if (kind == Kind.Moss) Palette.Moss else Palette.Rod) else null, modifier = modifier) {
        Column(Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            androidx.compose.foundation.layout.Box(contentAlignment = Alignment.Center) {
                // the chosen companion stands on a shape that springs from a soft square into a cookie
                app.mossling.ui.components.MorphBlob(on, app.mossling.ui.components.Shapes.Square, app.mossling.ui.components.Shapes.Cookie,
                    (if (kind == Kind.Moss) Palette.Moss else Palette.Rod).copy(alpha = if (on) 0.16f else 0.06f), Modifier.size(112.dp))
                Creature(kind, Modifier.size(96.dp), mood = if (on) Mood.Happy else Mood.Open, look = if (kind == Kind.Moss) Offset(0.8f, 0f) else Offset(-0.8f, 0f))
            }
            Text(name, fontFamily = Numerals, style = MaterialTheme.typography.headlineSmall)
            Text(line, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun Row1(title: String, sub: String, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(horizontal = 18.dp, vertical = 14.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            if (sub.isNotBlank()) Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

