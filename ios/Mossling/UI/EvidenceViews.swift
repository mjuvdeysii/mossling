import AVFoundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Gentle Offline Voice Reader

/// Calm on-device speech synthesizer for hands-free bedside or holding-baby reading.
@MainActor
@Observable
final class SpeechReader {
    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        let onFinish: @MainActor @Sendable (ObjectIdentifier) -> Void

        init(onFinish: @escaping @MainActor @Sendable (ObjectIdentifier) -> Void) {
            self.onFinish = onFinish
            super.init()
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor [onFinish] in onFinish(id) }
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor [onFinish] in onFinish(id) }
        }
    }

    private var synthesizer: AVSpeechSynthesizer?
    private var delegate: Delegate?
    private var activeUtteranceID: ObjectIdentifier?
    var isSpeaking = false

    init() {}

    @MainActor
    private final class WeakBox {
        weak var owner: SpeechReader?
    }

    func toggle(text: String) {
        if isSpeaking || synthesizer?.isSpeaking == true {
            stop()
            return
        }
        guard !FirstVoiceController.shared.isRecording else { return }
        if !SoundscapeEngine.shared.isPlaying {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? session.setActive(true)
        }
        let synth = synthesizer ?? {
            let instance = AVSpeechSynthesizer()
            let box = WeakBox()
            box.owner = self
            let del = Delegate { finishedID in
                guard let owner = box.owner, owner.activeUtteranceID == finishedID else { return }
                owner.activeUtteranceID = nil
                owner.isSpeaking = false
                if !SoundscapeEngine.shared.isPlaying && !FirstVoiceController.shared.isRecording && FirstVoiceController.shared.playingID == nil {
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
            instance.delegate = del
            delegate = del
            synthesizer = instance
            return instance
        }()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: L10n.isEnglish ? "en-US" : "zh-CN")
        utterance.rate = 0.47
        activeUtteranceID = ObjectIdentifier(utterance)
        isSpeaking = true
        synth.speak(utterance)
    }

    func stop() {
        activeUtteranceID = nil
        if synthesizer?.isSpeaking == true {
            synthesizer?.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        if !SoundscapeEngine.shared.isPlaying && !FirstVoiceController.shared.isRecording && FirstVoiceController.shared.playingID == nil {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

// MARK: - Gentle Three-State Observation Row

/// Replaces rigid pass/fail checkboxes on developmental items with three warm, low-anxiety states.
struct ObservationStateRow: View {
    let text: String
    let state: ObservationState
    let accent: Color
    let dark: Bool
    var last: Bool = false
    let onSelect: (ObservationState) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: state.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(stateColor(state))
                    .padding(.top, 2)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            WrapLayout(spacing: 6) {
                ForEach(ObservationState.allCases, id: \.self) { choice in
                    let active = (state == choice)
                    let tint = stateColor(choice)
                    Button {
                        TactileEngine.shared.beadClick()
                        onSelect(active && choice != .notYet ? .notYet : choice)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: choice.symbol)
                                .font(.caption2.weight(.bold))
                            Text(choice.label)
                                .font(.caption.weight(active ? .bold : .medium))
                        }
                        .foregroundStyle(active ? .white : (dark ? tint.mix(with: .white, by: 0.28) : Crayon.ink(tint)))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(active ? Crayon.fill(tint, dark) : tint.opacity(dark ? 0.16 : 0.10)))
                        .overlay(
                            Capsule()
                                .strokeBorder(tint.opacity(active ? 0 : 0.25), lineWidth: 0.7)
                        )
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("\(text)，\(choice.label)", "\(text), \(choice.label)"))
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(.leading, 26)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        if !last {
            Divider().padding(.leading, 16)
        }
    }

    private func stateColor(_ item: ObservationState) -> Color {
        switch item {
        case .observed: accent
        case .notYet: Crayon.caramel
        case .askDoctor: Crayon.tangerine
        }
    }
}

// MARK: - WHO MGRS (2006) Six-Band Gross Motor Healthy Achievement Spectrum

/// Vertical light-band overview of the 6 WHO gross motor achievement windows (1st–99th percentile).
struct WHOMotorSpectrumCard: View {
    let currentMonth: Double?
    let dark: Bool
    @State private var expanded = false

    private let maxAxisMonth = 20.0

    var body: some View {
        CalmAccordion(isExpanded: $expanded, spacing: 12) { open in
            HStack(spacing: 12) {
                IconTile(symbol: "figure.walk", color: Crayon.teal, size: 30, round: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("大运动健康宽带图谱", "Healthy Motor Range Spectrum"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(L10n.t(
                        "WHO 2006 1st–99th 百分位宽区间 · 每个孩子跨度都很宽",
                        "WHO 2006 1st–99th healthy spans · wide normal variation"
                    ))
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(WHOMotorWindow.all) { window in
                    windowRow(window)
                }

                WrapLayout(spacing: 10) {
                    legendDot(color: Crayon.teal.opacity(0.65), text: L10n.t("WHO 健康宽带", "WHO Healthy Span"))
                    legendDot(color: Crayon.sunflower, text: L10n.t("CDC 75% 常规节点", "CDC 75% Check-in"))
                    if currentMonth != nil {
                        legendDot(color: Palette.bead, text: L10n.t("宝宝当前位置", "Current Age"))
                    }
                }
                .padding(.top, 2)

                Text(L10n.t(
                    "依据 WHO MGRS (2006) 与 CDC 修订指南：约 4.3% 健康婴儿不经手膝爬行直接扶走或独走；若满 18 月龄仍未独走，可在下次儿保时请医生评估。",
                    "Based on WHO MGRS (2006) & CDC 75% milestones: ~4.3% of healthy infants skip hands-and-knees crawling. Discuss with your pediatrician if not walking independently by 18 months."
                ))
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .padding(LayoutSpec.cardPad)
        .printCard(radius: Radius.card)
    }

    private func windowRow(_ window: WHOMotorWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text(window.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    if window.variableOrder {
                        Text(L10n.t("顺序可变", "Variable"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Crayon.ink(Crayon.caramel))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Crayon.caramel.opacity(dark ? 0.22 : 0.15)))
                    }
                    Spacer(minLength: 4)
                    Text(String(format: L10n.t("%.1f–%.1f 月", "%.1f–%.1f mo"), window.startMonth, window.endMonth))
                        .font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(window.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        if window.variableOrder {
                            Text(L10n.t("顺序可变", "Variable"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Crayon.ink(Crayon.caramel))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Crayon.caramel.opacity(dark ? 0.22 : 0.15)))
                        }
                        Text(String(format: L10n.t("%.1f–%.1f 月", "%.1f–%.1f mo"), window.startMonth, window.endMonth))
                            .font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
            }

            GeometryReader { geo in
                let w = max(1, geo.size.width)
                let startX = w * CGFloat(min(1, max(0, window.startMonth / maxAxisMonth)))
                let endX = w * CGFloat(min(1, max(0, window.endMonth / maxAxisMonth)))
                let line18X = w * CGFloat(WHOMotorWindow.clinicalLineMonth / maxAxisMonth)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(dark ? 0.08 : 0.06))
                        .frame(height: 12)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Crayon.teal.opacity(0.32), Crayon.teal.opacity(0.68)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(12, endX - startX), height: 12)
                        .offset(x: startX)

                    Rectangle()
                        .fill(Crayon.tangerine.opacity(0.45))
                        .frame(width: 1, height: 14)
                        .offset(x: line18X)

                    if let cdc = window.cdcBenchmarkMonth {
                        Circle()
                            .fill(Crayon.sunflower)
                            .frame(width: 6, height: 6)
                            .offset(x: w * CGFloat(cdc / maxAxisMonth) - 3)
                    }

                    if let cur = currentMonth {
                        let cx = w * CGFloat(min(maxAxisMonth, max(0, cur)) / maxAxisMonth)
                        Circle()
                            .fill(Palette.bead)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: 1))
                            .frame(width: 9, height: 9)
                            .offset(x: cx - 4.5)
                    }
                }
            }
            .frame(height: 14)

            Text(window.note)
                .font(.caption2)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption2).foregroundStyle(Palette.secondaryText)
        }
    }
}

// MARK: - Daily 3-Layer Micro-Intuition Spotlight Card (L1 / L2 / L3)

/// Presents the current stage's evidence-backed micro-intuition card with voice read-aloud and family sharing.
struct LampCardSpotlightCard: View {
    @Environment(AppModel.self) private var app
    let card: LampCard
    let dark: Bool
    @State private var showDetail = false
    @State private var reader = SpeechReader()

    var body: some View {
        let h5URL = CardWebCodec.encodeURL(from: card, babyName: app.nickname, month: app.babyMonth ?? card.minMonth)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(symbol: "lightbulb.max.fill", color: Crayon.sunflower, size: 30, round: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.stageTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Crayon.ink(Crayon.sunflower))
                    Text(card.headline)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }

            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Palette.bead)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("此时可以对宝宝说", "You can say aloud"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Crayon.ink(Crayon.sunflower))
                    Text("“\(card.sayAloud)”")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .fill(Crayon.sunflower.opacity(dark ? 0.16 : 0.10))
            )

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.accent)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("手边微动作", "Micro-Action"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                    Text(card.microAction)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            WrapLayout(spacing: 8) {
                Button {
                    TactileEngine.shared.beadClick()
                    reader.toggle(text: L10n.t("\(card.headline)。\(card.sayAloud)。\(card.microAction)", "\(card.headline). \(card.sayAloud). \(card.microAction)"))
                } label: {
                    Label(
                        reader.isSpeaking ? L10n.t("停止朗读", "Stop Voice") : L10n.t("读给我听", "Read Aloud"),
                        systemImage: reader.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill"
                    )
                    .dsPill(.tinted(Crayon.sky), height: 34)
                }
                .buttonStyle(.toy)

                if let h5URL {
                    ShareLink(item: h5URL, message: Text(card.shareMessage())) {
                        Label(L10n.t("发给家人", "Family Card"), systemImage: "square.and.arrow.up")
                            .dsPill(.tinted(Crayon.caramel), height: 34)
                    }
                    .accessibilityLabel(L10n.t("生成长辈卡发给家人", "Share grandparent card with family"))
                } else {
                    ShareLink(item: card.shareMessage()) {
                        Label(L10n.t("发给家人", "Share with Family"), systemImage: "square.and.arrow.up")
                            .dsPill(.tinted(Crayon.caramel), height: 34)
                    }
                }

                Button {
                    TactileEngine.shared.beadClick()
                    reader.stop()
                    showDetail = true
                } label: {
                    Label(L10n.t("解读与循证", "Why & Sources"), systemImage: "book.pages.fill")
                        .dsPill(.tinted(Palette.accent), height: 34)
                }
                .buttonStyle(.toy)
            }
        }
        .padding(LayoutSpec.cardPad)
        .printCard(radius: Radius.card)
        .sheet(isPresented: $showDetail) {
            LampCardDetailSheet(card: card)
                .lampPresented()
        }
        .onDisappear {
            reader.stop()
        }
    }
}

/// Three-layer drill-down sheet: L1 Intuition, L2 Empathy & Grandparent Note, L3 Clinical Evidence & Red Flags.
struct LampCardDetailSheet: View {
    @Environment(AppModel.self) private var app
    let card: LampCard
    @Environment(\.dismiss) private var dismiss
    @State private var reader = SpeechReader()

    var body: some View {
        let h5URL = CardWebCodec.encodeURL(from: card, babyName: app.nickname, month: app.babyMonth ?? card.minMonth)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Card(title: L10n.t("此刻手边做法", "Immediate Action"), symbol: "lightbulb.fill", color: Crayon.sunflower) {
                        Text(card.headline).font(.headline).fixedSize(horizontal: false, vertical: true)
                        Text("“\(card.sayAloud)”").font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        Text(card.microAction).font(.footnote).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                    }

                    Card(title: L10n.t("宝宝视角与家人话术", "Child's View & Family Note"), symbol: "heart.text.square.fill", color: Crayon.caramel) {
                        Text(card.translation)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Text(L10n.t("给长辈和同住家人的一段话", "For Grandparents & Caregivers"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                        Text(card.grandparentNote)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Card(title: L10n.t("临床依据与就诊提示", "Clinical Evidence & Red Flags"), symbol: "cross.case.fill", color: Crayon.teal) {
                        WrapLayout(spacing: 6) {
                            ForEach(card.clinicalTerms, id: \.self) { term in
                                Text(LampCard.localizedClinicalTerm(term))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Crayon.ink(Crayon.teal))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Crayon.teal.opacity(0.12)))
                            }
                        }
                        Text(card.redFlag)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()
                        Text(card.meta.sources.map(\.title).joined(separator: "\n"))
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(card.meta.tiers.map(\.label).joined(separator: " · ")) · \(card.meta.reviewLabel)")
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText)
                        Text(card.meta.limitation)
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .pageBackground()
            .navigationTitle(card.stageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        reader.toggle(text: L10n.t("\(card.translation)。\(card.grandparentNote)", "\(card.translation). \(card.grandparentNote)"))
                    } label: {
                        Image(systemName: reader.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                    }
                    .accessibilityLabel(L10n.t("朗读解读", "Read explanation aloud"))
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let h5URL {
                        ShareLink(item: h5URL, message: Text(card.shareMessage())) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(L10n.t("分享给家人", "Share family card"))
                    } else {
                        ShareLink(item: card.shareMessage()) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button(L10n.t("完成", "Done")) { dismiss() }
                }
            }
        }
        .onDisappear { reader.stop() }
    }
}

// MARK: - One-Page Printable Clinic Visit PDF Snapshot

struct ClinicSnapshotPDFTransfer: Transferable {
    let filename: String
    let render: @MainActor @Sendable () -> Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { item in
            await MainActor.run { item.render() }
        }
        .suggestedFileName { item in
            item.filename
        }
    }
}

/// Generates a clean single-page printable PDF summarizing feeding, sleep, growth, and doctor questions.
enum ClinicSnapshotPDF {
    @MainActor
    static func summaryLines(
        app: AppModel,
        logs: [LogEntry],
        measures: [Measure],
        questions: [String] = [],
        foods: [FoodRecord] = [],
        region: HealthRegion = HealthRegion.defaultRegion(),
        days: Int = 7
    ) -> [(section: String, lines: [String])] {
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let sexText = app.sex == "girl" ? L10n.t("女孩", "Girl") : app.sex == "boy" ? L10n.t("男孩", "Boy") : L10n.t("未填写", "Not set")
        var identity: [String] = [
            L10n.t("姓名/小名：\(who) · 性别：\(sexText)", "Child: \(who) · Sex: \(sexText)")
        ]
        if let birth = app.birth {
            let birthStr = String(format: "%04d-%02d-%02d", birth.y, birth.m, birth.d)
            if let actual = app.actualAge {
                identity.append(L10n.t("出生日期：\(birthStr) · 实际月龄：\(actual.months) 个月 \(actual.days) 天", "DOB: \(birthStr) · Actual age: \(actual.months)m \(actual.days)d"))
            }
            if let gw = app.gestationalWeeks, let ca = app.correctedAge {
                identity.append(L10n.t("早产 \(gw) 周 · 矫正月龄：\(ca.months) 个月 \(ca.days) 天", "Preterm \(gw) wks · Corrected age: \(ca.months)m \(ca.days)d"))
            }
        }

        // Compute recent `days`-day averages ending on `app.today`
        var loggedDays = 0
        var totalFeeds = 0
        var totalSleepSec = 0.0
        var totalDiapers = 0
        var tempRecords: [LogEntry] = []
        var medRecords: [LogEntry] = []
        let cutoffDay = app.today.plus(days: -max(1, days) + 1)
        for offset in 0..<max(1, days) {
            let d = app.today.plus(days: -offset)
            let dayLogs = logs.filter { log in
                let sd = Day(log.startDate)
                if sd == d { return true }
                if let end = log.end, end > d.date.timeIntervalSince1970 * 1000, sd.epochDay < d.epochDay {
                    return true
                }
                return false
            }
            if !dayLogs.isEmpty {
                loggedDays += 1
                totalFeeds += dayLogs.feedCount(from: d.date.timeIntervalSince1970 * 1000)
                totalSleepSec += dayLogs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: d) }
                totalDiapers += dayLogs.filter { $0.type == LogType.diaper && !$0.carriedOver(into: d) }.count
            }
        }
        for log in logs where Day(log.startDate).epochDay >= cutoffDay.epochDay {
            if log.type == LogType.temp { tempRecords.append(log) }
            if log.type == LogType.medicine { medRecords.append(log) }
        }
        let denom = max(1, loggedDays)
        let avgSleepHr = (totalSleepSec / Double(denom)) / 3600.0
        let avgFeeds = Double(totalFeeds) / Double(denom)
        let avgDiapers = Double(totalDiapers) / Double(denom)
        var careLines = loggedDays == 0
            ? [L10n.t("近 \(days) 天暂无喂睡与尿布记录", "No feed, sleep, or diaper logs in the past \(days) days.")]
            : [
                L10n.t("有记录天数：\(loggedDays) / \(days) 天", "Logged days: \(loggedDays) of \(days)"),
                String(format: L10n.t("日均喂奶：%.1f 次 · 日均睡眠：%.1f 小时 · 日均尿布：%.1f 片", "Daily avg · Feeds: %.1f · Sleep: %.1f h · Diapers: %.1f"), avgFeeds, avgSleepHr, avgDiapers)
            ]
        if let maxTemp = tempRecords.compactMap(\.amount).max() {
            careLines.append(L10n.t("近 \(days) 天体温记录（\(tempRecords.count) 次），最高：\(L10n.temperature(tenthsC: maxTemp))", "Temp logs (\(tempRecords.count)) in past \(days)d · peak: \(L10n.temperature(tenthsC: maxTemp))"))
        }
        if !medRecords.isEmpty {
            let meds = medRecords.sorted(by: { $0.start > $1.start }).prefix(3).compactMap(\.detail).filter { !$0.isEmpty }
            let medDetail = meds.isEmpty ? L10n.t("共 \(medRecords.count) 次用药记录", "\(medRecords.count) medication logs") : meds.joined(separator: L10n.t("、", ", "))
            careLines.append(L10n.t("近期用药/补充：", "Recent meds/supplements: ") + medDetail)
        }

        // Latest growth measurement + WHO percentiles (per-measurement preterm adjustment under 24m)
        var growthLines: [String] = []
        if let latest = measures.sorted(by: { $0.at < $1.at }).last {
            let d = Day(Date(timeIntervalSince1970: latest.at / 1000))
            let measBirth = GrowthView.developmentalBirth(for: latest, birth: app.birth, gestationalWeeks: app.gestationalWeeks)
            let mo = measBirth.map { Double($0.days(to: d)) / 30.4375 }
            let ageSuffix = measBirth != nil && measBirth != app.birth ? L10n.t(" · 矫正月龄", " · Corrected") : ""
            func formatMetric(_ raw: Int?, _ ind: Indicator, _ div: Double) -> String? {
                guard let raw, raw > 0 else { return nil }
                let val = Double(raw) / div
                let base = "\(ind.short) \(ind.fmt(val)) \(ind.unitShort)"
                if let mo, app.sex != nil, mo >= 0, mo <= 36 {
                    let p = app.growth.percentile(ind, girl: app.girl, months: mo, value: val)
                    if p.isFinite {
                        return "\(base) (\(pctText(p)))"
                    }
                }
                return base
            }
            let items = [
                formatMetric(latest.weightG, .weight, 1000),
                formatMetric(latest.lengthMm, .length, 10),
                formatMetric(latest.headMm, .head, 10)
            ].compactMap { $0 }
            if !items.isEmpty {
                growthLines.append(L10n.t("最近测量（\(String(format: "%04d-%02d-%02d", d.y, d.m, d.d))\(ageSuffix)）：", "Latest (\(String(format: "%04d-%02d-%02d", d.y, d.m, d.d))\(ageSuffix)): ") + items.joined(separator: " · "))
            }
        }
        if growthLines.isEmpty {
            growthLines.append(L10n.t("暂无体重/身长/头围测量记录", "No growth measurements recorded yet."))
        }

        // Solids & common allergen summary (when recorded or >= 5 months)
        var foodLines: [String] = []
        if !foods.isEmpty {
            let allergenNames = foods.compactMap { rec -> String? in
                guard let item = FoodItem.item(id: rec.foodId), item.isCommonAllergen else { return nil }
                return item.name
            }.sorted()
            let watchSkinNames = foods.compactMap { rec -> String? in
                guard rec.watchSkin, let item = FoodItem.item(id: rec.foodId) else { return nil }
                return item.name
            }.sorted()
            foodLines.append(
                L10n.t(
                    "已解锁食物：\(foods.count) 种（常见致敏物已引入 \(allergenNames.count) 种）",
                    "Foods introduced: \(foods.count) (\(allergenNames.count) common allergens tried)"
                )
            )
            if !watchSkinNames.isEmpty {
                foodLines.append(
                    L10n.t("待观察皮肤/消化反应：", "Skin/reaction watchlist: ")
                    + watchSkinNames.joined(separator: L10n.t("、", ", "))
                )
            }
        }

        let flagged = app.askDoctorObservations()
        let obsLines = flagged.isEmpty
            ? [L10n.t("发育观察中暂无标记“留给医生看看”的条目", "No developmental items flagged to ask doctor.")]
            : flagged.map { L10n.t("\($0.month)月龄：\($0.label)", "\($0.month)m: \($0.label)") }

        var checkupFocusLines: [String] = []
        if let m = app.actualAge?.months, let cue = HealthRegion.screeningCue(for: region, month: m) {
            checkupFocusLines.append(cue)
        }
        if let upcoming = HealthRegion.daysUntilNextCheckup(birth: app.birth, today: app.today, region: region) {
            let timing = upcoming.daysRemaining <= 0
                ? L10n.t("满 \(upcoming.month) 月龄儿保窗口就在这几天", "\(upcoming.month)-month checkup window is open now")
                : L10n.t("距满 \(upcoming.month) 月龄儿保窗口还有 \(upcoming.daysRemaining) 天", "\(upcoming.daysRemaining) days to \(upcoming.month)-month checkup window")
            checkupFocusLines.append(timing)
        }

        let questionLines = questions.isEmpty
            ? [L10n.t("（家长可手写或打印后补充本页问题）", "(Space below for additional parent questions)")]
            : questions.enumerated().map { "\($0.offset + 1). \($0.element)" }

        var result: [(section: String, lines: [String])] = [
            (L10n.t("基本资料", "Child Profile"), identity),
            (L10n.t("近期照护节律（近 \(days) 天）", "Recent Routine (\(days)-Day Summary)"), careLines),
            (L10n.t("生长测量与 WHO 常模参考", "Growth & WHO (2006) Percentiles"), growthLines)
        ]
        if !foodLines.isEmpty {
            result.append((L10n.t("辅食与致敏物记录", "Solids & Allergen Introduction"), foodLines))
        }
        if !checkupFocusLines.isEmpty {
            result.append((L10n.t("当前月龄儿保筛查重点", "Well-Child Screening Cue"), checkupFocusLines))
        }
        result.append((L10n.t("留给医生看看（发育观察）", "Flagged Observations (Ask Doctor)"), obsLines))
        result.append((L10n.t("本次就诊想请教的问题", "Parent Questions for Pediatrician"), questionLines))
        return result
    }

    @MainActor
    static func render(
        app: AppModel,
        logs: [LogEntry],
        measures: [Measure],
        questions: [String] = [],
        foods: [FoodRecord] = [],
        region: HealthRegion = HealthRegion.defaultRegion(),
        days: Int = 7
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let sections = summaryLines(
            app: app,
            logs: logs,
            measures: measures,
            questions: questions,
            foods: foods,
            region: region,
            days: days
        )

        return renderer.pdfData { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1).cgColor)
            cg.fill(pageRect)

            let margin: CGFloat = 40
            let contentWidth = pageRect.width - margin * 2
            var y: CGFloat = 38

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor(red: 0.14, green: 0.12, blue: 0.10, alpha: 1)
            ]
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10.5, weight: .medium),
                .foregroundColor: UIColor(red: 0.42, green: 0.39, blue: 0.36, alpha: 1)
            ]
            let secTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12.5, weight: .bold),
                .foregroundColor: UIColor(red: 0.04, green: 0.49, blue: 0.45, alpha: 1)
            ]
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1)
            ]

            let footer = L10n.t(
                "摸索台灯 Moss & Otto · 生长常模参考 WHO (2006) 儿童生长标准 · 医学判断请以儿保医生现场评估为准。",
                "Moss & Otto · Reference: WHO Child Growth Standards (2006) · Does not replace professional pediatric care."
            )
            var pageNo = 1
            let genDate = String(format: "%04d-%02d-%02d", app.today.y, app.today.m, app.today.d)

            func drawFooter() {
                let pageLabel = L10n.t("第 \(pageNo) 页", "Page \(pageNo)")
                let pageAttr = NSAttributedString(string: pageLabel, attributes: subAttr)
                let pw = ceil(pageAttr.size().width)
                let footerAttr = NSAttributedString(string: footer, attributes: subAttr)
                footerAttr.draw(in: CGRect(x: margin, y: pageRect.height - 46, width: max(120, contentWidth - pw - 12), height: 32))
                pageAttr.draw(in: CGRect(x: margin + contentWidth - pw, y: pageRect.height - 46, width: pw, height: 32))
            }

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageRect.height - 58 {
                    drawFooter()
                    ctx.beginPage()
                    pageNo += 1
                    cg.setFillColor(UIColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1).cgColor)
                    cg.fill(pageRect)
                    y = 38
                    let contHead = NSAttributedString(
                        string: L10n.t("摸索台灯 · 儿保诊室一页摘要（续 · \(genDate)）", "Moss & Otto · Pediatric Clinic Snapshot (cont. · \(genDate))"),
                        attributes: subAttr
                    )
                    contHead.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 18))
                    y += 24
                }
            }

            func measureHeight(_ string: String, attrs: [NSAttributedString.Key: Any]) -> (NSAttributedString, CGFloat) {
                let ns = NSAttributedString(string: string, attributes: attrs)
                let box = ns.boundingRect(
                    with: CGSize(width: contentWidth, height: pageRect.height - 96),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                return (ns, ceil(box.height) + 2)
            }

            func drawText(_ string: String, attrs: [NSAttributedString.Key: Any], spacingAfter: CGFloat = 6) {
                let (ns, h) = measureHeight(string, attrs: attrs)
                ensureSpace(h)
                ns.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += h + spacingAfter
            }

            drawText(L10n.t("摸索台灯 · 儿保诊室一页摘要", "Moss & Otto · Pediatric Clinic Snapshot"), attrs: titleAttr, spacingAfter: 4)
            drawText(L10n.t("生成日期：\(genDate) · 所有数据来自家长本地记录，仅供就诊沟通参考", "Generated \(genDate) · Parent-entered offline care record · Non-diagnostic summary"), attrs: subAttr, spacingAfter: 14)

            for sec in sections {
                let firstLineH = sec.lines.first.map { measureHeight("• " + $0, attrs: bodyAttr).1 } ?? 18
                let secHeaderH = measureHeight(sec.section, attrs: secTitleAttr).1
                ensureSpace(secHeaderH + firstLineH + 18)

                cg.setStrokeColor(UIColor(red: 0.85, green: 0.82, blue: 0.77, alpha: 1).cgColor)
                cg.setLineWidth(0.75)
                cg.move(to: CGPoint(x: margin, y: y))
                cg.addLine(to: CGPoint(x: margin + contentWidth, y: y))
                cg.strokePath()
                y += 8

                drawText(sec.section, attrs: secTitleAttr, spacingAfter: 4)
                for line in sec.lines {
                    drawText("• " + line, attrs: bodyAttr, spacingAfter: 4)
                }
                y += 8
            }

            drawFooter()
        }
    }
}

/// Interactive preview and PDF export sheet for pediatrician well-child visits.
struct ClinicSnapshotSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @State private var draftQuestion = ""
    @State private var customQuestions: [String] = []

    var body: some View {
        let foodRecords = Array(FoodAtlasStore.shared.records.values)
        let region = app.healthRegion
        let sections = ClinicSnapshotPDF.summaryLines(
            app: app,
            logs: j.logs,
            measures: j.measures,
            questions: customQuestions,
            foods: foodRecords,
            region: region
        )
        let appRef = app
        let logs = j.logs
        let measures = j.measures
        let questions = customQuestions
        let transfer = ClinicSnapshotPDFTransfer(
            filename: L10n.t("摸索台灯-儿保诊室摘要.pdf", "moss-otto-clinic-snapshot.pdf"),
            render: {
                ClinicSnapshotPDF.render(
                    app: appRef,
                    logs: logs,
                    measures: measures,
                    questions: questions,
                    foods: foodRecords,
                    region: region
                )
            }
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Card(
                        title: L10n.t("添加带给医生的问题", "Add Questions for Doctor"),
                        symbol: "pencil.line",
                        color: Crayon.teal
                    ) {
                        HStack(spacing: 8) {
                            TextField(
                                L10n.t("例如：最近夜醒增多需要调整吗？", "e.g. Any concerns about night waking?"),
                                text: $draftQuestion
                            )
                            .textFieldStyle(.roundedBorder)
                            Button(L10n.t("加入", "Add")) {
                                let trimmed = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                TactileEngine.shared.beadClick()
                                customQuestions.append(trimmed)
                                draftQuestion = ""
                            }
                            .buttonStyle(.vinyl(Crayon.teal))
                            .disabled(draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if !customQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(customQuestions.enumerated()), id: \.offset) { idx, q in
                                    HStack {
                                        Text("\(idx + 1). \(q)")
                                            .font(.footnote)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Button {
                                            customQuestions.remove(at: idx)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(Palette.secondaryText)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    ForEach(Array(sections.enumerated()), id: \.offset) { _, sec in
                        Card(title: sec.section, symbol: "doc.text.fill", color: Crayon.caramel) {
                            ForEach(Array(sec.lines.enumerated()), id: \.offset) { _, line in
                                Text("• \(line)")
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .pageBackground()
            .navigationTitle(L10n.t("诊室一页摘要", "Clinic Snapshot"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(
                        item: transfer,
                        preview: SharePreview(L10n.t("摸索台灯 · 儿保诊室一页摘要", "Moss & Otto · Clinic Snapshot"))
                    ) {
                        Label(L10n.t("导出 PDF", "Export PDF"), systemImage: "square.and.arrow.up")
                    }
                    Button(L10n.t("完成", "Done")) { dismiss() }
                }
            }
        }
    }
}
