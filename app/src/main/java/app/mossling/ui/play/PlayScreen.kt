package app.mossling.ui.play

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.mossling.data.AreaNames
import app.mossling.data.Play
import app.mossling.domain.PlayRecord
import app.mossling.ui.components.Art
import app.mossling.ui.components.ArtIndex
import app.mossling.ui.components.ColorTablet
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SandpaperNumber
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.Tagged
import app.mossling.ui.components.areaColor
import app.mossling.ui.components.areaGlyph
import app.mossling.ui.components.shared
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.LocalMascotDirector
import app.mossling.ui.ip.MascotEvent
import app.mossling.ui.ip.MaterialStill
import app.mossling.ui.ip.Mood
import app.mossling.ui.ip.familyOf
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PlayScreen(
    play: Play,
    month: Int,
    done: Boolean,
    onToggleDone: () -> Unit,
    onBack: () -> Unit,
    record: PlayRecord? = null,
    initialStep: Int? = null,
    savedStep: Int? = null,
    onSaveSession: (Int) -> Unit = {},
    onClearSession: () -> Unit = {},
    onRecordPlay: ((String?) -> Unit)? = null,
    onPickToday: (() -> Unit)? = null,
) {
    val companion = LocalCompanion.current
    val director = LocalMascotDirector.current
    val ctx = LocalContext.current
    val pics = remember(play.code) { ArtIndex.steps(ctx, play.code) }

    var following by rememberSaveable { mutableStateOf(initialStep != null) }
    var stepIndex by rememberSaveable { mutableIntStateOf(initialStep ?: savedStep ?: 0) }

    if (following) {
        FollowAlongPlayer(
            play = play,
            pics = pics,
            stepIndex = stepIndex,
            onStepChange = { next ->
                stepIndex = next
                if (next < play.steps.size) {
                    onSaveSession(next)
                }
            },
            onClose = {
                if (stepIndex < play.steps.size) {
                    onSaveSession(stepIndex)
                }
                following = false
            },
            onFinish = { note ->
                if (onRecordPlay != null) {
                    onRecordPlay(note)
                } else if (!done) {
                    onToggleDone()
                }
                onClearSession()
                director.handle(MascotEvent.RecordPersistSuccess, companion)
                following = false
            },
        )
        return
    }

    val totalCount = maxOf(record?.total ?: 0, if (done) 1 else 0)

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Row(
                Modifier.statusBarsPadding().padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) {
                    Glyph(G.Back)
                }
                Text(
                    "${play.code} · 满 ${play.months.first()}–${play.months.last()} 个月",
                    fontFamily = Numerals,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f).shared("play-code-${play.code}"),
                )
                if (onPickToday != null) {
                    TextButton(onClick = onPickToday) { Text("今天玩这个") }
                }
            }
        }

        item {
            Surface(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                shape = RoundedCornerShape(32.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
            ) {
                Column(Modifier.padding(22.dp)) {
                    Row(verticalAlignment = Alignment.Top) {
                        Column(Modifier.weight(1f)) {
                            FlowRow(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                play.domains.forEach { d ->
                                    val c = areaColor(d)
                                    Surface(shape = RoundedCornerShape(10.dp), color = c.copy(alpha = 0.14f)) {
                                        Row(
                                            Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                                        ) {
                                            ColorTablet(c)
                                            Text(AreaNames[d] ?: d, style = MaterialTheme.typography.labelMedium, color = c)
                                        }
                                    }
                                }
                                if (totalCount > 0) {
                                    Surface(
                                        shape = RoundedCornerShape(10.dp),
                                        color = Palette.Bead.copy(alpha = 0.22f),
                                    ) {
                                        Text(
                                            if ((record?.todayCount ?: 0) > 0) "今天玩过 · 共 $totalCount 次" else "做过 ×$totalCount",
                                            fontFamily = Numerals,
                                            style = MaterialTheme.typography.labelMedium,
                                            color = MaterialTheme.colorScheme.onSurface,
                                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                        )
                                    }
                                }
                            }
                            Spacer(Modifier.height(10.dp))
                            Text(
                                play.name,
                                style = MaterialTheme.typography.headlineLarge,
                                modifier = Modifier.shared("play-title-${play.code}"),
                            )
                        }
                        Spacer(Modifier.width(12.dp))
                        val d0 = play.domains.firstOrNull() ?: "A"
                        val dc = areaColor(d0)
                        Row(
                            verticalAlignment = Alignment.Bottom,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            ShapeBadge(areaGlyph(d0), dc.copy(alpha = 0.16f), dc, shape = Shapes.of(play.code), size = 44.dp)
                            Creature(
                                companion,
                                Modifier.size(56.dp),
                                mood = if (done) Mood.Happy else Mood.Listening,
                                look = Offset(-0.7f, 0.2f),
                            )
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        FilledTonalButton(
                            onClick = {
                                stepIndex = savedStep ?: 0
                                following = true
                            },
                            modifier = Modifier.weight(1f).heightIn(min = 50.dp),
                            shape = RoundedCornerShape(18.dp),
                        ) {
                            Glyph(G.Play, size = 18.dp)
                            Spacer(Modifier.width(6.dp))
                            Text(
                                if (savedStep != null && savedStep in play.steps.indices) "接着做 · 第 ${savedStep + 1} 步"
                                else "跟着做",
                                style = MaterialTheme.typography.titleMedium,
                            )
                        }
                        Button(
                            onClick = {
                                onToggleDone()
                                if (!done) director.handle(MascotEvent.RecordPersistSuccess, companion)
                            },
                            modifier = Modifier.weight(1f).heightIn(min = 50.dp),
                            shape = RoundedCornerShape(18.dp),
                            colors = if (done) {
                                ButtonDefaults.buttonColors(
                                    containerColor = Palette.Bead,
                                    contentColor = Palette.Ink,
                                )
                            } else ButtonDefaults.buttonColors(),
                        ) {
                            Glyph(G.Check, size = 18.dp)
                            Spacer(Modifier.width(6.dp))
                            Text(
                                if (done) "这个月做过了" else "记为做过",
                                style = MaterialTheme.typography.titleMedium,
                            )
                        }
                    }
                }
            }
        }

        if (pics.isEmpty()) {
            item {
                MaterialStill(
                    familyOf(play.domains),
                    Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .clip(RoundedCornerShape(28.dp)),
                    ground = MaterialTheme.colorScheme.surfaceContainerLow,
                )
            }
        }

        item {
            SectionTitle("怎么做", kicker = "一步一步来 · 点任意一步直接跟着做")
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                play.steps.forEachIndexed { i, s ->
                    Plate(
                        modifier = Modifier.fillMaxWidth(),
                        onClick = {
                            stepIndex = i
                            following = true
                        },
                    ) {
                        pics.getOrNull(i)?.let { pic ->
                            Art(
                                pic,
                                label = "${play.name}，第 ${i + 1} 步：$s",
                                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)),
                            )
                            Spacer(Modifier.height(14.dp))
                        }
                        Row(verticalAlignment = Alignment.Top) {
                            SandpaperNumber("${i + 1}", MaterialTheme.typography.titleMedium)
                            Spacer(Modifier.width(14.dp))
                            Text(s, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f).padding(top = 2.dp))
                        }
                    }
                }
            }
        }

        item {
            SectionTitle("做的时候")
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Tagged("准备", play.prepare.ifEmpty { "不需要道具" })
                if (play.observe.isNotEmpty()) Tagged("看到什么", play.observe)
                if (play.stop.isNotEmpty()) Tagged("停一下", play.stop)
                if (play.safety.isNotEmpty()) Tagged("注意", play.safety, tagColor = MaterialTheme.colorScheme.error)
            }
        }

        if (play.variations.isNotEmpty()) {
            item {
                SectionTitle("再来一点", kicker = "换个花样")
                Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                    play.variations.forEachIndexed { i, v ->
                        if (i > 0) Spacer(Modifier.height(8.dp))
                        Text(v, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }
}

/**
 * Full-screen interactive step-by-step player ("跟着做"):
 * - Keeps screen awake while playing with the baby.
 * - Top bead progress chain (completed steps turn gold).
 * - One step per screen with large illustration; tap left for previous, right for next.
 * - Final card shows observation/stop cues and a one-tap "做完了，记一次" button.
 */
@Composable
private fun FollowAlongPlayer(
    play: Play,
    pics: List<String>,
    stepIndex: Int,
    onStepChange: (Int) -> Unit,
    onClose: () -> Unit,
    onFinish: (String?) -> Unit,
) {
    val view = LocalView.current
    DisposableEffect(view) {
        val prev = view.keepScreenOn
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = prev }
    }

    val totalPages = play.steps.size + 1 // steps + final summary page
    val page = stepIndex.coerceIn(0, totalPages - 1)
    var note by rememberSaveable { mutableStateOf("") }
    val companion = LocalCompanion.current

    Column(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        // Top bar with close button and Montessori bead progress bar
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onClose, modifier = Modifier.semantics { contentDescription = "退出跟着做" }) {
                Glyph(G.Close)
            }
            StepBeadBar(
                current = page,
                total = totalPages,
                modifier = Modifier.weight(1f).padding(horizontal = 12.dp),
            )
            Text(
                if (page < play.steps.size) "${page + 1}/${play.steps.size}" else "完成",
                fontFamily = Numerals,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(end = 8.dp),
            )
        }

        if (page < play.steps.size) {
            val stepText = play.steps[page]
            val pic = pics.getOrNull(page)
            val haptic = androidx.compose.ui.platform.LocalHapticFeedback.current
            var dragTotal by remember(page) { androidx.compose.runtime.mutableFloatStateOf(0f) }
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .pointerInput(page) {
                        detectHorizontalDragGestures(
                            onDragStart = { dragTotal = 0f },
                            onDragEnd = {
                                if (dragTotal > 64.dp.toPx() && page > 0) {
                                    haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove)
                                    onStepChange(page - 1)
                                } else if (dragTotal < -64.dp.toPx()) {
                                    haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove)
                                    onStepChange(page + 1)
                                }
                                dragTotal = 0f
                            },
                            onHorizontalDrag = { _, dragAmount ->
                                dragTotal += dragAmount
                            },
                        )
                    }
                    .pointerInput(page) {
                        detectTapGestures { offset ->
                            haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove)
                            if (offset.x < size.width * 0.35f) {
                                if (page > 0) onStepChange(page - 1)
                            } else {
                                onStepChange(page + 1)
                            }
                        }
                    }
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    "${play.code} · ${play.name}",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                if (pic != null) {
                    Art(
                        name = pic,
                        label = "${play.name}，第 ${page + 1} 步",
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(28.dp)),
                    )
                } else {
                    MaterialStill(
                        family = familyOf(play.domains),
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(28.dp)),
                        ground = MaterialTheme.colorScheme.surfaceContainerLow,
                    )
                }
                Plate(Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.Top) {
                        SandpaperNumber("${page + 1}", MaterialTheme.typography.headlineSmall)
                        Spacer(Modifier.width(14.dp))
                        Text(
                            stepText,
                            style = MaterialTheme.typography.headlineSmall,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    if (page == 0 && play.prepare.isNotBlank() && play.prepare != "无") {
                        Spacer(Modifier.height(12.dp))
                        Tagged("准备", play.prepare)
                    }
                    if (play.safety.isNotBlank()) {
                        Spacer(Modifier.height(8.dp))
                        Tagged("注意", play.safety, tagColor = MaterialTheme.colorScheme.error)
                    }
                }
                Text(
                    "左右滑动，或点左半边回上一步、点右半边去下一步",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.align(Alignment.CenterHorizontally),
                )
            }

            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = { if (page > 0) onStepChange(page - 1) else onClose() },
                    modifier = Modifier.weight(1f).heightIn(min = 52.dp),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Text(if (page > 0) "上一步" else "稍后继续")
                }
                Button(
                    onClick = { onStepChange(page + 1) },
                    modifier = Modifier.weight(1f).heightIn(min = 52.dp),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Text(if (page == play.steps.lastIndex) "看小结" else "下一步")
                }
            }
        } else {
            // Final summary & one-tap completion page
            Column(
                Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    MaterialStill(
                        family = familyOf(play.domains),
                        modifier = Modifier.width(128.dp).clip(RoundedCornerShape(18.dp)),
                        ground = MaterialTheme.colorScheme.surfaceContainerLow,
                    )
                    Creature(companion, Modifier.size(76.dp), mood = Mood.Happy)
                }
                Text(play.name, style = MaterialTheme.typography.headlineMedium)
                Plate(Modifier.fillMaxWidth()) {
                    Text("做的时候", style = MaterialTheme.typography.titleMedium)
                    Spacer(Modifier.height(6.dp))
                    if (play.observe.isNotEmpty()) Tagged("看到什么", play.observe)
                    if (play.stop.isNotEmpty()) Tagged("停一下", play.stop)
                    if (play.safety.isNotEmpty()) Tagged("注意", play.safety, tagColor = MaterialTheme.colorScheme.error)
                }
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it.take(120) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(18.dp),
                    label = { Text("顺手记一句孩子的反应（选填）") },
                    singleLine = true,
                )
            }
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = { onStepChange(play.steps.lastIndex) },
                    modifier = Modifier.weight(1f).heightIn(min = 52.dp),
                    shape = RoundedCornerShape(18.dp),
                ) {
                    Text("回上一步")
                }
                Button(
                    onClick = { onFinish(note) },
                    modifier = Modifier.weight(1.4f).heightIn(min = 52.dp),
                    shape = RoundedCornerShape(18.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Palette.Bead,
                        contentColor = Palette.Ink,
                    ),
                ) {
                    Glyph(G.Check, size = 18.dp, color = Palette.Ink)
                    Spacer(Modifier.width(6.dp))
                    Text("做完了，记一次", style = MaterialTheme.typography.titleMedium)
                }
            }
        }
    }
}

@Composable
private fun StepBeadBar(current: Int, total: Int, modifier: Modifier = Modifier) {
    val line = MaterialTheme.colorScheme.outlineVariant
    val future = MaterialTheme.colorScheme.outline
    Canvas(modifier.height(24.dp)) {
        val n = total.coerceAtLeast(1)
        val pad = 10.dp.toPx()
        val w = (size.width - pad * 2).coerceAtLeast(1f)
        val cy = size.height / 2f
        drawLine(line, Offset(pad, cy), Offset(size.width - pad, cy), 1.6.dp.toPx())
        for (i in 0 until n) {
            val x = if (n == 1) size.width / 2f else pad + (w * i) / (n - 1)
            val c = Offset(x, cy)
            when {
                i < current -> {
                    drawCircle(Palette.Bead, 5.5.dp.toPx(), c)
                    drawCircle(Palette.BeadLight, 2.dp.toPx(), c + Offset(-1.5.dp.toPx(), -1.5.dp.toPx()))
                }
                i == current -> {
                    drawCircle(Palette.Bead, 7.dp.toPx(), c)
                    drawCircle(Palette.Paper, 2.5.dp.toPx(), c)
                }
                else -> {
                    drawCircle(future, 4.5.dp.toPx(), c, style = Stroke(1.5.dp.toPx()))
                }
            }
        }
    }
}
