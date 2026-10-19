package app.mossling.ui.you

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
    val importOld: () -> Unit = {},
    val exportJson: () -> Unit = {},
    val exportCsv: () -> Unit = {},
    val clearAll: () -> Unit = {},
    val nickname: (String) -> Unit = {},
    val sex: (String?) -> Unit = {},
    val search: () -> Unit = {},
    val lock: (Boolean) -> Unit = {},
)

@Composable
fun YouScreen(ui: AppUi, a: YouActions, modifier: Modifier = Modifier) {
    val c = ui.content ?: return
    val m = ui.babyMonth
    LazyColumn(modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp)) {
        item("head") {
            Column(Modifier.statusBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                Text("我的", style = MaterialTheme.typography.headlineLarge)
                Text(ui.settings.birth?.let { "${it.year} 年 ${md(it)} 出生" + (ui.age?.let { g -> " · 第 ${g.lived} 天" } ?: "") } ?: "还没有填写出生日期",
                    style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (m != null) item("record") {
            val mo = c.month(m)
            val obs = mo.observe.sumOf { it.items.size }
            val plays = (listOfNotNull(mo.feature) + mo.activities).distinct().size
            val care = mo.vaccines.size + mo.checkups.size
            SectionTitle("这个月记下的", kicker = "满 $m 个月 · 三类分开记", trailing = {
                val done = ui.count(m, TickKind.Observed) + ui.count(m, TickKind.Did) + ui.count(m, TickKind.Vaccine) + ui.count(m, TickKind.Checkup)
                PinkTower(done, obs + plays + care)
            })
            Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Count("看到过", ui.count(m, TickKind.Observed), obs, Palette.Moss, Modifier.weight(1f)) { a.openMonth(m) }
                Count("做过", ui.count(m, TickKind.Did), plays, Palette.Rod, Modifier.weight(1f)) { a.openMonth(m) }
                Count("接种儿保", ui.count(m, TickKind.Vaccine) + ui.count(m, TickKind.Checkup), care, Palette.Bead, Modifier.weight(1f)) { a.openMonth(m) }
            }
            Text("「做过」只表示做过这个游戏，不代表某项能力已经达到。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
        }
        item("companion") {
            SectionTitle("谁陪着你", kicker = "换一个，内容和记录都不变")
            Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Pick(Kind.Moss, "Moss", "两只眼睛，安静地看", ui.settings.companion == Kind.Moss, Modifier.weight(1f)) { a.companion(Kind.Moss) }
                Pick(Kind.Otto, "Otto", "一只眼睛，专心一件事", ui.settings.companion == Kind.Otto, Modifier.weight(1f)) { a.companion(Kind.Otto) }
            }
        }
        item("settings") {
            SectionTitle("设置", kicker = null)
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("出生日期", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f).padding(start = 4.dp))
                    Surface(onClick = a.birth, shape = RoundedCornerShape(16.dp), color = MaterialTheme.colorScheme.surfaceContainer, modifier = Modifier.heightIn(min = 48.dp)) {
                        Text(ui.settings.birth?.toString() ?: "填写", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp))
                    }
                }
                var nick by remember(ui.settings.nickname) { mutableStateOf(ui.settings.nickname) }
                OutlinedTextField(nick, { nick = it.take(12) }, Modifier.fillMaxWidth().onFocusChanged { if (!it.isFocused && nick != ui.settings.nickname) a.nickname(nick) },
                    label = { Text("宝宝的小名（可不填）") }, singleLine = true, shape = RoundedCornerShape(16.dp),
                    keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = { a.nickname(nick) }),
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(imeAction = androidx.compose.ui.text.input.ImeAction.Done))
                Text("性别（只用于选择 WHO 生长曲线）", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(start = 4.dp, top = 8.dp))
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    listOf("boy" to "男孩", "girl" to "女孩", null to "不填").forEachIndexed { i, (k, l) ->
                        SegmentedButton(selected = ui.settings.sex == k, onClick = { a.sex(k) }, shape = SegmentedButtonDefaults.itemShape(i, 3)) { Text(l) }
                    }
                }
                val ctx = androidx.compose.ui.platform.LocalContext.current
                val canLock = remember { runCatching { androidx.biometric.BiometricManager.from(ctx).canAuthenticate(androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK) == androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS }.getOrDefault(false) }
                if (canLock || ui.settings.lock) Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(start = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("应用锁", style = MaterialTheme.typography.titleMedium)
                        Text("打开时用指纹、面容或锁屏密码确认", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    androidx.compose.material3.Switch(ui.settings.lock, onCheckedChange = a.lock)
                }
                Text("外观", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(start = 4.dp, top = 8.dp))
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    listOf(ThemeMode.System to "跟随系统", ThemeMode.Light to "浅色", ThemeMode.Dark to "深色").forEachIndexed { i, (t, l) ->
                        SegmentedButton(selected = ui.settings.theme == t, onClick = { a.theme(t) }, shape = SegmentedButtonDefaults.itemShape(i, 3)) { Text(l) }
                    }
                }
            }
        }
        item("data") {
            SectionTitle("记录文件", kicker = "只在这台手机上，自己保管")
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row1("导出记录文件", "全部勾选、手帐、生长测量和设置，存成一个 .json 文件；换手机或给家人时用") { a.exportJson() }
                Row1("导出表格", "手帐和测量，一条一行的 .csv，可以用表格软件打开或给医生看") { a.exportCsv() }
                Row1("导入记录文件", "本应用或旧版「养小怪兽 · 成长手册」导出的 .json：已有的不会被覆盖，重复的会跳过") { a.importOld() }
                Surface(onClick = a.clearAll, shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
                    Text("清除全部数据", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp))
                }
            }
        }
        item("shelf") {
            SectionTitle("参考", kicker = "整理好的专题")
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row1("搜索", "玩法、每个月的内容和专题") { a.search() }
                c.topics.forEach { t -> Row1(t.title, t.sourceTitle) { a.topic(t.id) } }
                Row1("关于与来源", "依据的机构、方法和每一条的核对日期") { a.about() }
            }
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
            Creature(kind, Modifier.size(96.dp), mood = if (on) Mood.Happy else Mood.Open, look = if (kind == Kind.Moss) Offset(0.8f, 0f) else Offset(-0.8f, 0f))
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

