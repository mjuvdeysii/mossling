package app.mossling.ui.you

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.toggleableState
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.selection.toggleable
import app.mossling.AppUi
import app.mossling.ui.components.G
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Duo
import app.mossling.ui.ip.HuggedAvatar
import app.mossling.ui.ip.Kind
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.ThemeMode

data class YouActions(
    val pickBirth: () -> Unit = {},
    val setCompanion: (Kind) -> Unit = {},
    val setTheme: (ThemeMode) -> Unit = {},
    val setNightLight: (Boolean) -> Unit = {},
    val setJournal: (Boolean) -> Unit = {},
    val setSex: (String?) -> Unit = {},
    val setLook: (String?) -> Unit = {},
    val setNickname: (String) -> Unit = {},
    val setAppLock: (Boolean) -> Unit = {},
    val openGrowth: () -> Unit = {},
    val openBook: () -> Unit = {},
    val openFirsts: () -> Unit = {},
    val openData: () -> Unit = {},
    val openStory: () -> Unit = {},
    val openTopic: (String) -> Unit = {},
    val openAbout: () -> Unit = {},
    val openAppAbout: () -> Unit = {},
    val shareSummary: () -> Unit = {},
    val shareJson: () -> Unit = {},
    val shareCsv: () -> Unit = {},
    val importJson: () -> Unit = {},
    val clearAll: () -> Unit = {},
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun YouScreen(ui: AppUi, a: YouActions) {
    val age = ui.age
    val content = ui.content ?: return
    var confirmClear by remember { mutableStateOf(false) }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 112.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Surface(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(top = 8.dp),
                shape = RoundedCornerShape(32.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
            ) {
                Column(Modifier.statusBarsPadding().padding(22.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("孩子的出生日期", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.height(4.dp))
                            Text(ui.settings.birth?.toString() ?: "未填写", style = MaterialTheme.typography.headlineLarge)
                            if (age != null) {
                                Text(
                                    "满 ${age.months} 个月 ${age.days} 天 · 出生第 ${age.lived} 天",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(top = 2.dp),
                                )
                            }
                            Spacer(Modifier.height(10.dp))
                            FilledTonalButton(onClick = a.pickBirth, shape = RoundedCornerShape(16.dp)) {
                                Text(if (ui.settings.birth == null) "填写" else "修改日期")
                            }
                        }
                        Spacer(Modifier.width(8.dp))
                        HuggedAvatar(
                            month = age?.bookMonth ?: 0,
                            girl = ui.settings.drawsGirl,
                            companion = ui.settings.companion,
                            size = 84.dp,
                        )
                    }
                    var editName by remember { mutableStateOf(false) }
                    Row(
                        Modifier.padding(top = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text("性别", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        listOf("boy" to "男孩", "girl" to "女孩").forEach { (k, l) ->
                            FilterChip(
                                selected = ui.settings.sex == k,
                                onClick = { a.setSex(if (ui.settings.sex == k) null else k) },
                                label = { Text(l) },
                            )
                        }
                        Spacer(Modifier.weight(1f))
                        TextButton(onClick = { editName = true }) {
                            Text(if (ui.settings.nickname.isBlank()) "加个小名" else "小名：${ui.settings.nickname}")
                        }
                    }
                    Row(
                        Modifier.padding(top = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text("插画形象", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        val activeLook = ui.settings.look ?: ui.settings.sex ?: "boy"
                        listOf("boy" to "男宝形象", "girl" to "女宝形象").forEach { (k, l) ->
                            FilterChip(
                                selected = activeLook == k,
                                onClick = { a.setLook(k) },
                                label = { Text(l) },
                            )
                        }
                    }
                    if (editName) {
                        var draft by remember { mutableStateOf(ui.settings.nickname) }
                        AlertDialog(
                            onDismissRequest = { editName = false },
                            title = { Text("孩子的小名") },
                            text = {
                                OutlinedTextField(
                                    value = draft,
                                    onValueChange = { draft = it.take(20) },
                                    singleLine = true,
                                    placeholder = { Text("只显示在这部手机上") },
                                )
                            },
                            confirmButton = {
                                TextButton(onClick = { a.setNickname(draft); editName = false }) { Text("好") }
                            },
                            dismissButton = {
                                TextButton(onClick = { editName = false }) { Text("取消") }
                            },
                        )
                    }
                }
            }
        }

        // Memory book & Firsts & Growth curves
        item {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Plate(Modifier.weight(1f), onClick = a.openBook) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            ShapeBadge(
                                G.Journal,
                                MaterialTheme.colorScheme.primaryContainer,
                                MaterialTheme.colorScheme.onPrimaryContainer,
                                shape = Shapes.Cookie,
                                size = 38.dp,
                            )
                            Column(Modifier.padding(start = 10.dp)) {
                                Text("成长册", style = MaterialTheme.typography.titleMedium)
                                Text(
                                    "按月留存的记忆",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                    Plate(Modifier.weight(1f), onClick = a.openFirsts) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            ShapeBadge(
                                G.Heart,
                                MaterialTheme.colorScheme.tertiaryContainer,
                                MaterialTheme.colorScheme.onTertiaryContainer,
                                shape = Shapes.Flower,
                                size = 38.dp,
                            )
                            Column(Modifier.padding(start = 10.dp)) {
                                Text("第一次", style = MaterialTheme.typography.titleMedium)
                                Text(
                                    if (ui.firsts.isEmpty()) "记下重要瞬间" else "已记 ${ui.firsts.size} 个",
                                    fontFamily = Numerals,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
                val last = ui.measures.maxByOrNull { it.at }
                val sub = if (last == null) {
                    "记录体重、身长、头围，对照 WHO 生长标准"
                } else {
                    "最近一次：" + listOfNotNull(
                        last.weightG?.let { "${"%.2f".format(it / 1000.0)} kg" },
                        last.lengthMm?.let { "${"%.1f".format(it / 10.0)} cm" },
                        last.headMm?.let { "头围 ${"%.1f".format(it / 10.0)} cm" },
                    ).joinToString(" · ")
                }
                Plate(Modifier.fillMaxWidth(), onClick = a.openGrowth) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        ShapeBadge(
                            G.Ruler,
                            MaterialTheme.colorScheme.secondaryContainer,
                            MaterialTheme.colorScheme.onSecondaryContainer,
                            shape = Shapes.Clover,
                            size = 40.dp,
                        )
                        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                            Text("生长曲线", style = MaterialTheme.typography.titleMedium)
                            Text(sub, fontFamily = Numerals, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Text("进入", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }

        item {
            SectionTitle(
                "谁陪着你",
                kicker = "小苔好奇，奥托点灯；点它们一下会回应你",
                trailing = { TextButton(onClick = a.openStory) { Text("它们的故事") } },
            )
            Column(
                Modifier.padding(horizontal = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Duo(lead = ui.settings.companion, size = 96.dp)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    CompanionChoice(
                        kind = Kind.Moss,
                        name = "小苔 Moss",
                        note = Kind.Moss.trait,
                        selected = ui.settings.companion == Kind.Moss,
                        modifier = Modifier.weight(1f),
                    ) { a.setCompanion(Kind.Moss) }
                    CompanionChoice(
                        kind = Kind.Otto,
                        name = "奥托 Otto",
                        note = Kind.Otto.trait,
                        selected = ui.settings.companion == Kind.Otto,
                        modifier = Modifier.weight(1f),
                    ) { a.setCompanion(Kind.Otto) }
                }
            }
        }

        item {
            SectionTitle("设置")
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                ToggleLine("手帐", "记录喂奶、换尿布与睡眠；关掉不会删掉已记的内容", ui.settings.journal, a.setJournal)
                Spacer(Modifier.height(10.dp))
                ToggleLine("应用锁", "打开应用时用手机的指纹、面容或锁屏密码确认是你本人", ui.settings.appLock, a.setAppLock)
                Spacer(Modifier.height(14.dp))
                Text("外观", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    ThemeMode.entries.forEachIndexed { index, m ->
                        SegmentedButton(
                            selected = ui.settings.theme == m,
                            onClick = { a.setTheme(m) },
                            shape = SegmentedButtonDefaults.itemShape(index = index, count = ThemeMode.entries.size),
                            label = { Text(m.label) },
                        )
                    }
                }
                if (ui.settings.theme == ThemeMode.System) {
                    Spacer(Modifier.height(10.dp))
                    ToggleLine("晚上自动开夜灯", "19:00 至次日 06:00 自动切换为暖黄夜灯模式，夜里喂奶不刺眼", ui.settings.nightLight, a.setNightLight)
                }
            }
        }

        item {
            SectionTitle(
                "记录文件",
                kicker = "只保存在这部手机上 · 可随时导出或恢复",
                trailing = { TextButton(onClick = a.openData) { Text("数据与隐私") } },
            )
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                val tickCount = ui.ticks.size
                Text("已记下 $tickCount 项成长与玩法记录", style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(10.dp))
                FilledTonalButton(
                    onClick = a.shareSummary,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Text("导出给医生或 AI 看的摘要 (.md)")
                }
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    FilledTonalButton(onClick = a.shareJson, modifier = Modifier.weight(1f), shape = RoundedCornerShape(16.dp)) {
                        Text("导出记录（JSON）")
                    }
                    FilledTonalButton(onClick = a.shareCsv, modifier = Modifier.weight(1f), shape = RoundedCornerShape(16.dp)) {
                        Text("导出手帐（CSV 表格）")
                    }
                }
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = a.importJson, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
                    Text("从备份文件恢复（JSON）")
                }
            }
        }

        item {
            SectionTitle("常翻的专题")
            FlowRow(
                Modifier.padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                content.topics.forEach { t ->
                    Surface(
                        onClick = { a.openTopic(t.id) },
                        shape = RoundedCornerShape(18.dp),
                        color = MaterialTheme.colorScheme.surfaceContainerLow,
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    ) {
                        Text(t.title, style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp))
                    }
                }
            }
        }

        item {
            SectionTitle("参考与来源")
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp), onClick = a.openAbout) {
                Text("内容来源、怎么读、可信程度与参考文献", style = MaterialTheme.typography.titleMedium)
                Text(
                    "中国、世界卫生组织、美国、英国、加拿大、澳大利亚等权威机构的公开指南 · 共 ${content.sources.size + 1} 项来源",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
            Spacer(Modifier.height(8.dp))
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp), onClick = a.openAppAbout) {
                Text("关于摸索台灯", style = MaterialTheme.typography.titleMedium)
                Text(
                    "版本、检查更新、隐私政策、医疗免责声明、使用条款与问题反馈",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }

        item {
            TextButton(
                onClick = { confirmClear = true },
                modifier = Modifier.padding(horizontal = 20.dp),
            ) {
                Text("清除全部本地数据", color = MaterialTheme.colorScheme.error)
            }
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text("清除全部本地数据？", style = MaterialTheme.typography.headlineSmall) },
            text = { Text("孩子的出生日期、记下的做过与留意、第一次、生长测量和全部手帐都会从这部手机上移除。") },
            confirmButton = {
                TextButton(onClick = { confirmClear = false; a.clearAll() }) {
                    Text("清除", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = { confirmClear = false }) { Text("取消") } },
        )
    }
}

@Composable
private fun ToggleLine(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .toggleable(
                value = checked,
                role = Role.Switch,
                onValueChange = onCheckedChange,
            )
            .semantics(mergeDescendants = true) {
                toggleableState = ToggleableState(checked)
            },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(checked = checked, onCheckedChange = null)
    }
}

@Composable
private fun CompanionChoice(
    kind: Kind,
    name: String,
    note: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = modifier,
        shape = RoundedCornerShape(24.dp),
        color = if (selected) MaterialTheme.colorScheme.surfaceContainerLowest else MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(
            if (selected) 2.dp else 1.dp,
            if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
        ),
    ) {
        Column(Modifier.padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Creature(kind, Modifier.size(64.dp), mood = if (selected) Mood.Happy else Mood.Calm, interactive = false)
            Spacer(Modifier.height(6.dp))
            Text(name, style = MaterialTheme.typography.titleSmall)
            Text(note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
