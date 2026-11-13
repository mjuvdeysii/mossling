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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.CrashLog
import app.mossling.domain.Updater
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.ip.Duo
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals

data class AppAboutActions(
    val openContentAbout: () -> Unit = {},
    val openLicenses: () -> Unit = {},
    val openStory: () -> Unit = {},
    val back: () -> Unit = {},
)

enum class LegalDoc(val title: String) {
    Privacy("隐私政策与儿童信息规则"),
    Terms("使用条款"),
    Disclaimer("医疗免责声明"),
    Changelog("更新日志"),
}

private const val REPO = "https://github.com/ViewWay/Mossling"
private const val ISSUES = "https://github.com/ViewWay/Mossling/issues"
private const val RELEASES = "https://github.com/ViewWay/Mossling/releases/latest"
private const val MAIL = "contact@mossling.app"

/**
 * Everything about the app itself: version, update check, feedback, privacy & children's info rules,
 * terms of use, medical disclaimer, and open-source licenses.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppAboutScreen(a: AppAboutActions, updater: Updater? = null) {
    val ctx = LocalContext.current
    val uri = LocalUriHandler.current
    val clip = LocalClipboardManager.current
    val companion = LocalCompanion.current
    val version = remember { runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName }.getOrNull() ?: "1.3.0" }
    var doc by remember { mutableStateOf<LegalDoc?>(null) }
    var crash by remember { mutableStateOf(CrashLog.read(ctx)) }
    var copied by remember { mutableStateOf(false) }
    val upState = updater?.state?.collectAsState()?.value ?: Updater.State.Idle

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item { Bar("关于摸索台灯", a.back) }
        item {
            Surface(
                shape = RoundedCornerShape(32.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                Row(
                    Modifier.padding(22.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("摸索台灯", style = MaterialTheme.typography.headlineLarge)
                        Text(
                            "Moss & Otto · 孩子摸索，大人点灯",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.padding(top = 8.dp),
                        ) {
                            Text(
                                "版本 $version",
                                fontFamily = Numerals,
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            TextButton(onClick = a.openStory) { Text("它们的故事") }
                        }
                    }
                    Duo(companion, size = 80.dp)
                }
            }
        }
        item {
            SectionTitle("版本与更新", kicker = "平时完全离线；仅在你点下面按钮时连接 GitHub Releases")
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                when (upState) {
                    Updater.State.Idle -> {
                        Text("当前版本 $version", fontFamily = Numerals, style = MaterialTheme.typography.titleMedium)
                        Text(
                            "点下面按钮查询是否有新版本；若有，会在应用内下载 APK 并交给系统安装器。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 2.dp),
                        )
                        Spacer(Modifier.height(10.dp))
                        FilledTonalButton(onClick = { updater?.check() }, shape = RoundedCornerShape(16.dp)) { Text("检查更新") }
                    }
                    Updater.State.Checking -> Text("正在连接 GitHub Releases…", style = MaterialTheme.typography.bodyMedium)
                    Updater.State.Latest -> {
                        Text("已是最新版本（$version）", fontFamily = Numerals, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                        Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            TextButton(onClick = { updater?.check() }) { Text("再查一次") }
                            TextButton(onClick = { runCatching { uri.openUri(RELEASES) } }) { Text("打开版本页面") }
                        }
                    }
                    is Updater.State.Available -> {
                        val r = upState.r
                        Text(
                            "发现新版本 ${r.version}" + if (r.date.isNotBlank()) " · ${r.date}" else "",
                            fontFamily = Numerals,
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        if (r.notes.isNotBlank()) {
                            Text(r.notes, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
                        }
                        Spacer(Modifier.height(10.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            if (r.apk != null) {
                                Button(onClick = { updater?.download(r) }, shape = RoundedCornerShape(16.dp)) { Text("下载并安装") }
                            }
                            OutlinedButton(onClick = { runCatching { uri.openUri(r.page.ifBlank { RELEASES }) } }, shape = RoundedCornerShape(16.dp)) { Text("查看发布页") }
                        }
                    }
                    is Updater.State.Downloading -> {
                        val pct = if (upState.total > 0) ((upState.done * 100) / upState.total).toInt() else null
                        Text(
                            "正在下载 ${upState.r.version}" + (pct?.let { " · $it%" } ?: "…"),
                            fontFamily = Numerals,
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text("下载完成后会自动调起系统安装器。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 2.dp))
                    }
                    is Updater.State.Ready -> {
                        Text("${upState.r.version} 已下载", fontFamily = Numerals, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.height(8.dp))
                        Button(
                            onClick = {
                                val u = updater ?: return@Button
                                ctx.startActivity(if (u.canInstall()) u.installIntent(upState.file) else u.allowInstallIntent())
                            },
                            shape = RoundedCornerShape(16.dp),
                        ) { Text("安装更新") }
                    }
                    is Updater.State.Failed -> {
                        Text("未能完成：${upState.why}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
                        Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilledTonalButton(onClick = { updater?.check() }, shape = RoundedCornerShape(16.dp)) { Text("重试") }
                            TextButton(onClick = { runCatching { uri.openUri(RELEASES) } }) { Text("在浏览器打开下载页") }
                        }
                    }
                }
            }
        }
        item {
            SectionTitle("说明与条款", kicker = "离线可读全文")
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                DocCard("隐私政策与儿童个人信息规则", "不联网、无账号、无 SDK；儿童信息仅存本机，可导出、撤回与彻底删除") { doc = LegalDoc.Privacy }
                DocCard("医疗免责声明", "本应用提供育儿科普与个人记录工具，不代替医生面诊与医嘱") { doc = LegalDoc.Disclaimer }
                DocCard("使用条款", "Apache 2.0 开源许可下的使用约定与责任限制") { doc = LegalDoc.Terms }
                DocCard("更新日志", "这几个版本改了什么") { doc = LegalDoc.Changelog }
                DocCard("内容来源与分级方法", "权威指南、参考文献与核对过的说法") { a.openContentAbout() }
                DocCard("开源许可", "字体、组件库与 WHO 生长标准数据的署名与许可证") { a.openLicenses() }
            }
        }
        item {
            SectionTitle("反馈与支持", kicker = "遇到问题或内容存疑")
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Text("每一条内容都可以核对出处；若发现笔误、过期指南或界面问题，欢迎告诉我们。", style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilledTonalButton(onClick = { runCatching { uri.openUri(ISSUES) } }, shape = RoundedCornerShape(16.dp)) { Text("提交问题") }
                    OutlinedButton(
                        onClick = {
                            runCatching {
                                ctx.startActivity(
                                    Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$MAIL?subject=${Uri.encode("摸索台灯反馈 ($version)")}"))
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                            }
                        },
                        shape = RoundedCornerShape(16.dp),
                    ) { Text("写邮件") }
                    OutlinedButton(
                        onClick = { runCatching { uri.openUri(REPO) } },
                        shape = RoundedCornerShape(16.dp),
                    ) { Text("开源代码") }
                }
            }
        }
        if (crash != null) {
            item {
                SectionTitle("本机崩溃诊断", kicker = "仅保存在本机，不会自动发送")
                Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                    Text(crash!!.take(600), fontFamily = Numerals, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilledTonalButton(onClick = { clip.setText(AnnotatedString(crash!!)); copied = true }, shape = RoundedCornerShape(14.dp)) {
                            Text(if (copied) "已复制" else "复制诊断信息")
                        }
                        TextButton(onClick = { CrashLog.clear(ctx); crash = null }) { Text("清除") }
                    }
                }
            }
        }
    }

    doc?.let { LegalSheet(doc = it, onDismiss = { doc = null }) }
}

/**
 * Dedicated Data & Privacy Control Screen ("数据"):
 * Export Doctor/AI Markdown summary, full JSON backup, CSV table, restore from JSON backup,
 * withdraw guardian consent, or clear all local data.
 */
@Composable
fun DataScreen(
    ui: AppUi,
    onShareSummary: () -> Unit,
    onShareJson: () -> Unit,
    onShareCsv: () -> Unit,
    onImportJson: () -> Unit,
    onWithdrawConsent: () -> Unit,
    onClearAll: () -> Unit,
    onBack: () -> Unit,
) {
    var askWithdraw by remember { mutableStateOf(false) }
    var askClear by remember { mutableStateOf(false) }
    var legalDoc by remember { mutableStateOf<LegalDoc?>(null) }

    val tickCount = ui.ticks.size
    val logCount = ui.allLogs.size
    val measureCount = ui.measures.size
    val firstCount = ui.firsts.size

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item { Bar("数据与备份", onBack) }

        item {
            Surface(
                shape = RoundedCornerShape(28.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("只保存在这部手机上", style = MaterialTheme.typography.headlineSmall)
                    Text(
                        "已记下 $tickCount 项成长与玩法 · $logCount 条手帐 · $measureCount 次生长测量 · $firstCount 个第一次",
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        "没有云端账号，卸载或换机前请先导出备份文件。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        item {
            SectionTitle("导出与恢复", kicker = "随时带走你的全部记录")
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Text("给儿保医生或 AI 助手看的摘要（Markdown）", style = MaterialTheme.typography.titleMedium)
                Text(
                    "把孩子的月龄、第一次、生长测量与百分位、每天喂养睡眠汇总整理成一份清晰的 .md 文档，方便门诊或发给 AI 工具参考。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp),
                )
                Spacer(Modifier.height(10.dp))
                Button(
                    onClick = onShareSummary,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Text("导出给医生或 AI 看的记录 (.md)")
                }

                HorizontalDivider(Modifier.padding(vertical = 14.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))

                Text("完整备份与表格", style = MaterialTheme.typography.titleMedium)
                Text(
                    "JSON 包含设置、勾选、手帐、生长测量与第一次，可在换机或重装后完整恢复；CSV 可用表格软件打开。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp),
                )
                Spacer(Modifier.height(10.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    FilledTonalButton(onClick = onShareJson, modifier = Modifier.weight(1f), shape = RoundedCornerShape(16.dp)) {
                        Text("导出完整备份 (.json)")
                    }
                    FilledTonalButton(onClick = onShareCsv, modifier = Modifier.weight(1f), shape = RoundedCornerShape(16.dp)) {
                        Text("导出表格 (.csv)")
                    }
                }
                Spacer(Modifier.height(8.dp))
                OutlinedButton(
                    onClick = onImportJson,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Text("从备份文件恢复 (.json)")
                }
            }
        }

        item {
            SectionTitle("隐私与儿童个人信息控制")
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Text(
                    "你可以随时查阅《隐私政策与儿童信息规则》，撤回监护人同意（清除出生日期、小名、性别并关闭手帐），或彻底清除本机全部数据。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { legalDoc = LegalDoc.Privacy }) { Text("隐私政策与儿童信息规则") }
                    TextButton(onClick = { legalDoc = LegalDoc.Disclaimer }) { Text("医疗免责声明") }
                }
                Spacer(Modifier.height(6.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedButton(
                        onClick = { askWithdraw = true },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        Text("撤回同意")
                    }
                    OutlinedButton(
                        onClick = { askClear = true },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                    ) {
                        Text("清除全部数据")
                    }
                }
            }
        }
    }

    if (askWithdraw) {
        AlertDialog(
            onDismissRequest = { askWithdraw = false },
            title = { Text("撤回监护人同意？", style = MaterialTheme.typography.headlineSmall) },
            text = { Text("撤回后将清除本机保存的出生日期、性别、小名并关闭手帐，切换为仅浏览科普内容模式。") },
            confirmButton = {
                TextButton(onClick = { askWithdraw = false; onWithdrawConsent() }) {
                    Text("确认撤回", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = { askWithdraw = false }) { Text("取消") } },
        )
    }

    if (askClear) {
        AlertDialog(
            onDismissRequest = { askClear = false },
            title = { Text("清除全部本地数据？", style = MaterialTheme.typography.headlineSmall) },
            text = { Text("孩子的出生日期、记下的做过与留意、第一次、生长测量和全部手帐都会从这部手机上彻底移除，无法恢复。") },
            confirmButton = {
                TextButton(onClick = { askClear = false; onClearAll() }) {
                    Text("确认清除", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = { askClear = false }) { Text("取消") } },
        )
    }

    legalDoc?.let { LegalSheet(doc = it, onDismiss = { legalDoc = null }) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LegalSheet(doc: LegalDoc, onDismiss: () -> Unit) {
    val raw = when (doc) {
        LegalDoc.Privacy -> PRIVACY_TEXT
        LegalDoc.Disclaimer -> DISCLAIMER_TEXT
        LegalDoc.Terms -> TERMS_TEXT
        LegalDoc.Changelog -> CHANGELOG_TEXT
    }
    val sections = remember(doc) { raw.split("\n\n").map { it.trim() }.filter { it.isNotEmpty() } }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(doc.title, style = MaterialTheme.typography.headlineSmall)
            sections.forEachIndexed { idx, block ->
                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = if (idx == 0) MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.55f) else MaterialTheme.colorScheme.surfaceContainerLow,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        val lines = block.lines()
                        if (lines.size > 1 && lines.first().length <= 28) {
                            Text(
                                lines.first(),
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Text(
                                lines.drop(1).joinToString("\n"),
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        } else {
                            Text(
                                block,
                                style = MaterialTheme.typography.bodyMedium,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DocCard(title: String, sub: String, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(horizontal = 18.dp, vertical = 14.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

private const val PRIVACY_TEXT = """生效日期：2026年10月26日

简短结论：摸索台灯不收集、不上传、不共享你或孩子的任何信息。应用不设账号、不嵌第三方统计或广告 SDK；平时完全不联网，仅在你主动点击「关于摸索台灯 › 检查更新」时连接 GitHub Releases 查询版本。

一、我们处理的本地数据
应用处理的全部数据均由你（父母或其他监护人）在设备本地自愿录入，仅保存在你的手机内部存储中：
1. 孩子的基本资料（选填）：出生日期、性别（仅用于对照 WHO 生长曲线）、插画形象偏好、小名。
2. 成长与玩法记录（选填）：你勾选的「做过」「可以留意」「疫苗」「儿保」及「第一次」。
3. 日常照护手帐（默认关闭，选填）：亲喂、瓶喂、辅食、睡眠、换尿布、洗澡、体温、用药、备注及计时器状态。
4. 生长测量（选填）：体重、身长/身高、头围数值与测量日期。

二、儿童个人信息保护规则（未满 14 周岁）
1. 仅限监护人使用：本应用面向婴幼儿的父母或其他监护人，不直接向儿童提供交互服务。
2. 最小必要与全部选填：不填写出生日期、小名或性别，同样可以完整浏览 0–36 个月的全部内容与玩法。
3. 查阅、更正、导出、撤回同意与删除：你可以在「我的 › 数据与备份」中随时导出 Markdown 摘要、JSON 完整备份或 CSV 表格，也可以随时撤回同意或点击「清除全部数据」立即从设备中彻底抹除所有记录。"""

private const val DISCLAIMER_TEXT = """重要提示：摸索台灯（Mossling）提供的全部文字、插画、月龄观察、疫苗与儿保时间表、生长百分位曲线及日常记录工具，仅供育儿科普与个人参考，不构成医疗诊断、临床评估或治疗建议，不能替代执业医师的当面诊疗。

1. 关于「可以留意」与发育里程碑：每个孩子的发展节奏都有个体差异。「可以留意」列表不是发育筛查量表或打分考试。如果你对孩子的发育有任何担忧，请直接咨询儿科或儿童保健科医生。
2. 关于 WHO 生长标准曲线：生长百分位表示孩子在同龄同性别参考人群中的位置，不是「达标分数」。判断生长状况需结合连续趋势与儿保医生的综合评估。
3. 关于疫苗与儿保：各地接种程序和医院安排可能存在差异，请以孩子手中的《预防接种证》及当地社区卫生服务中心通知为准。
4. 紧急情况：未满 3 个月婴儿体温 ≥ 38.0 ℃，或任何月龄出现呼吸困难、口唇发紫、抽搐、精神反应极差、持续高热不退或疑似误吞异物等紧急情况，请勿依赖本应用，立即前往医院急诊或拨打急救电话。"""

private const val TERMS_TEXT = """生效日期：2026年10月26日

1. 适用范围：摸索台灯是一款免费的开源本地应用（源代码采用 Apache License 2.0 许可）。使用本应用即表示你同意本条款。
2. 使用者资格：本应用供成年监护人（父母或其他法定监护人）使用。
3. 个人记录与备份责任：应用不提供云同步或远程恢复服务。你的所有记录仅保存在本机，卸载应用、清除应用数据、设备丢失或损坏都会导致本地记录丢失。请定期使用「我的 › 数据与备份」自行保存备份。
4. 非医疗服务：本应用不提供医疗诊断或咨询服务，详见《医疗免责声明》。"""

private const val CHANGELOG_TEXT = """1.3.0（2026-10-26）
· 原生矢量伙伴升级：小苔（Moss）与奥托（Otto）新增完整的动作状态机、夜灯暖黄光晕、轻拍回应、连点彩蛋，以及晚间台灯剧场（LampScene）与拥抱头像（HuggedAvatar）。
· 跟着做模式：玩法详情支持全屏分步「跟着做」，带顶部蒙氏串珠进度条、常亮屏幕与中途续做提醒。
· 成长册与第一次：新增按月装帧的「成长册」与「第一次」里程碑记录，自动汇总当月玩过的活动、生长测量与日均照护。
· 亲喂与睡眠计时：支持左右侧分侧计时与一键切换、超时自检提醒，以及体温 ≥ 38.0 ℃ 就医提示。
· 数据与医生摘要：新增导出给儿保医生或 AI 工具阅读的 Markdown 摘要报告（.md）及独立的数据与隐私控制页。

0.2.0（2026-10-20）
· 新增 0–36 个月「成长地图」与「本周的架子」。
· 新增 JSON 备份导入恢复与应用内更新检查。"""
