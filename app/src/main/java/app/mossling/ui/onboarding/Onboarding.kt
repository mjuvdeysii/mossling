package app.mossling.ui.onboarding

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mossling.ui.components.Plate
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Kind
import app.mossling.ui.ip.LampScene
import app.mossling.ui.ip.Mood
import app.mossling.ui.you.LegalDoc
import app.mossling.ui.you.LegalSheet
import java.time.LocalDate
import java.time.YearMonth

/**
 * First-run welcome screen (`ios/DESIGN.md` & `docs/IP.md` §5):
 * Opens with the wordless 4-second `LampScene`, lets the parent pick Moss or Otto,
 * set the child's birth date (or look around first), and read the medical disclaimer & legal terms.
 */
@Composable
fun Onboarding(
    onFinish: () -> Unit,
    onSkip: () -> Unit,
) = Onboarding(onFinish = { _, _ -> onFinish() }, onSkip = onSkip)

@Composable
fun Onboarding(
    onFinish: (LocalDate, Kind) -> Unit,
    onSkip: () -> Unit,
) {
    var companion by remember { mutableStateOf(Kind.Moss) }
    var picking by remember { mutableStateOf(false) }
    var legalDoc by remember { mutableStateOf<LegalDoc?>(null) }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 24.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        LampScene(
            modifier = Modifier
                .fillMaxWidth()
                .height(210.dp),
            focus = companion,
            selecting = true,
            onSelect = { companion = it },
        )

        Spacer(Modifier.height(16.dp))
        Text("摸索台灯", style = MaterialTheme.typography.headlineLarge, textAlign = TextAlign.Center)
        Text(
            "孩子摸索，大人点灯",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(top = 2.dp),
        )
        Text(
            "0–36 个月，一个月一站。\n每天在架子上摆一件事，跟着孩子慢慢做。",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 6.dp),
        )

        Spacer(Modifier.height(16.dp))
        Text("选一个陪你的伙伴", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            CompanionCard(
                kind = Kind.Moss,
                name = "小苔 Moss",
                trait = Kind.Moss.trait,
                selected = companion == Kind.Moss,
                modifier = Modifier.weight(1f),
            ) { companion = Kind.Moss }
            CompanionCard(
                kind = Kind.Otto,
                name = "奥托 Otto",
                trait = Kind.Otto.trait,
                selected = companion == Kind.Otto,
                modifier = Modifier.weight(1f),
            ) { companion = Kind.Otto }
        }

        Spacer(Modifier.height(16.dp))
        Plate(Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.surfaceContainerLow) {
            Text("不用注册，也不联网", style = MaterialTheme.typography.titleMedium)
            Text(
                "你记下的一切都只留在这一部手机里，随时可以导出给医生或备份。喂奶、换尿布、睡觉那本手帐默认关着，需要时再开。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                "本应用提供育儿与发育科普信息及个人记录工具，不构成医疗诊断或治疗建议。发热、呼吸异常、精神反应差等情况请及时就医。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp),
            )
            Row(
                Modifier.fillMaxWidth().padding(top = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(onClick = { legalDoc = LegalDoc.Terms }) { Text("使用条款", style = MaterialTheme.typography.labelMedium) }
                Text("·", color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = { legalDoc = LegalDoc.Privacy }) { Text("隐私政策", style = MaterialTheme.typography.labelMedium) }
                Text("·", color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = { legalDoc = LegalDoc.Disclaimer }) { Text("免责声明", style = MaterialTheme.typography.labelMedium) }
            }
        }

        Spacer(Modifier.height(16.dp))
        Button(
            onClick = { picking = true },
            modifier = Modifier.fillMaxWidth().height(54.dp),
            shape = RoundedCornerShape(20.dp),
        ) {
            Text("填写出生日期", style = MaterialTheme.typography.titleMedium)
        }
        TextButton(onClick = onSkip, modifier = Modifier.padding(top = 4.dp)) {
            Text("先看看，稍后再填")
        }
    }

    if (picking) {
        BirthDateDialog(
            initial = LocalDate.now().minusMonths(6),
            onConfirm = { picking = false; onFinish(it, companion) },
            onDismiss = { picking = false },
        )
    }

    legalDoc?.let { doc ->
        LegalSheet(doc = doc, onDismiss = { legalDoc = null })
    }
}

@Composable
private fun CompanionCard(
    kind: Kind,
    name: String,
    trait: String,
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
            Creature(
                kind = kind,
                modifier = Modifier.size(72.dp),
                mood = if (selected) Mood.Happy else Mood.Calm,
                interactive = false,
            )
            Spacer(Modifier.height(6.dp))
            Text(name, style = MaterialTheme.typography.titleMedium)
            Text(
                trait,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/**
 * Guardian privacy & children's personal information rules consent sheet (`ios/COMPLIANCE.md` §1, `ios/Mossling/Data/AppModel.swift`).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConsentSheet(
    onAccept: () -> Unit,
    onDecline: () -> Unit,
    onOpenDoc: (LegalDoc) -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDecline,
        containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 28.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("监护人知情同意", style = MaterialTheme.typography.headlineSmall)
            Text(
                "为了帮你按月龄查看内容、对照 WHO 生长曲线或记录日常照护，摸索台灯需要由你（父母或其他监护人）决定是否在本机保存以下儿童个人信息：",
                style = MaterialTheme.typography.bodyMedium,
            )
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.surfaceContainerLow,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text("· 出生日期、性别、小名（选填）", style = MaterialTheme.typography.bodyMedium)
                    Text("· 身高/身长、体重、头围测量值（选填）", style = MaterialTheme.typography.bodyMedium)
                    Text("· 喂养、睡眠、尿布、体温、第一次等照护记录（选填）", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "以上信息仅保存在你的手机本地，不上传服务器、不用于广告或画像；你可随时在「我的 › 数据」中导出、撤回同意或清除全部数据。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = { onOpenDoc(LegalDoc.Privacy) }) { Text("隐私政策与儿童信息规则") }
                TextButton(onClick = { onOpenDoc(LegalDoc.Terms) }) { Text("使用条款") }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedButton(
                    onClick = onDecline,
                    modifier = Modifier.weight(1f).heightIn(min = 48.dp),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Text("仅浏览内容")
                }
                Button(
                    onClick = onAccept,
                    modifier = Modifier.weight(1f).heightIn(min = 48.dp),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Text("同意并保存")
                }
            }
        }
    }
}

@Composable
fun BirthDateDialog(initial: LocalDate, onConfirm: (LocalDate) -> Unit, onDismiss: () -> Unit) {
    val today = LocalDate.now()
    var year by remember { mutableIntStateOf(initial.year) }
    var month by remember { mutableIntStateOf(initial.monthValue) }
    var day by remember { mutableIntStateOf(initial.dayOfMonth) }
    val maxDay = YearMonth.of(year, month).lengthOfMonth()
    if (day > maxDay) day = maxDay
    val picked = LocalDate.of(year, month, day)
    val valid = !picked.isAfter(today) && !picked.isBefore(today.minusYears(4))

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("孩子的出生日期", style = MaterialTheme.typography.headlineSmall) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("支持满 0–36 个月（已满 3 岁会显示第 36 个月）", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                StepperRow("年", "$year 年", onMinus = { if (year > today.year - 4) year-- }, onPlus = { if (year < today.year) year++ })
                StepperRow("月", "$month 月", onMinus = { month = if (month > 1) month - 1 else 12 }, onPlus = { month = if (month < 12) month + 1 else 1 })
                StepperRow("日", "$day 日", onMinus = { day = if (day > 1) day - 1 else maxDay }, onPlus = { day = if (day < maxDay) day + 1 else 1 })
                if (!valid) Text("不能晚于今天", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
        },
        confirmButton = { TextButton(onClick = { onConfirm(picked) }, enabled = valid) { Text("确定") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } },
    )
}

@Composable
private fun StepperRow(label: String, value: String, onMinus: () -> Unit, onPlus: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onMinus, shape = RoundedCornerShape(12.dp)) { Text("−") }
            Text(value, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(horizontal = 8.dp))
            OutlinedButton(onClick = onPlus, shape = RoundedCornerShape(12.dp)) { Text("+") }
        }
    }
}
