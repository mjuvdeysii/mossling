import SwiftUI

/// 「时光胶囊信笺 / Time Capsule Letters」 — Offline cotton-paper letters sealed with embossed Montessori wax stamps
/// to be unsealed on a child's future birthday or quiet milestone, with 3× letterpress keepsake poster export.
struct TimeCapsuleListView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @State private var store: CapsuleStore
    @State private var composing = false
    @State private var composeSeedTitle = ""
    @State private var composeSeedSeal: CapsuleSeal = .gold
    @State private var composeSeedUnlock: CapsuleComposeSheet.UnlockChoice = .firstBirthday
    @State private var selectedCapsule: TimeCapsule? = nil

    init(store: CapsuleStore = .shared) {
        _store = State(initialValue: store)
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let readyCount = store.readyCount(on: app.today)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard(dark: dark, readyCount: readyCount)

                if store.items.isEmpty {
                    emptyPrompts(dark: dark)
                } else {
                    let ready = store.items.filter { $0.isReadyToOpen(on: app.today) }
                    let sealed = store.items.filter { $0.isLocked(on: app.today) }
                    let opened = store.items.filter { $0.openedAt != nil }

                    if !ready.isEmpty {
                        SectionTitle(
                            title: L10n.t("可以拆封的信", "Ready to Unseal"),
                            detail: L10n.t("\(ready.count) 封", "\(ready.count)")
                        )
                        ForEach(ready) { item in
                            EnvelopeCard(capsule: item, today: app.today, dark: dark) {
                                TactileEngine.shared.pageTurn()
                                selectedCapsule = item
                            }
                        }
                    }

                    if !sealed.isEmpty {
                        SectionTitle(
                            title: L10n.t("静静等待未来", "Sealed for Later"),
                            detail: L10n.t("\(sealed.count) 封", "\(sealed.count)")
                        )
                        ForEach(sealed) { item in
                            EnvelopeCard(capsule: item, today: app.today, dark: dark) {
                                TactileEngine.shared.beadClick()
                                selectedCapsule = item
                            }
                        }
                    }

                    if !opened.isEmpty {
                        SectionTitle(
                            title: L10n.t("已经读过的信", "Opened Keepsakes"),
                            detail: L10n.t("\(opened.count) 封", "\(opened.count)")
                        )
                        ForEach(opened) { item in
                            OpenedLetterCard(capsule: item, dark: dark) {
                                TactileEngine.shared.pageTurn()
                                selectedCapsule = item
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.caramel)
        .navigationTitle(L10n.t("时光胶囊信笺", "Time Capsules"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if app.mayKeep() {
                        composeSeedTitle = ""
                        composeSeedSeal = .gold
                        composeSeedUnlock = .firstBirthday
                        TactileEngine.shared.beadClick()
                        composing = true
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(L10n.t("写一封新信", "Write a new letter"))
            }
        }
        .sheet(isPresented: $composing) {
            CapsuleComposeSheet(
                store: store,
                initialTitle: composeSeedTitle,
                initialSeal: composeSeedSeal,
                initialUnlock: composeSeedUnlock
            )
            .lampPresented(sheet: true)
        }
        .sheet(item: $selectedCapsule) { cap in
            CapsuleReadSheet(capsule: cap, store: store)
                .lampPresented(sheet: true)
        }
    }

    private func heroCard(dark: Bool, readyCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                WaxSealBadge(seal: .gold, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("写给未来的宝宝", "Letters for Future Days"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(
                        readyCount > 0
                            ? L10n.t("有 \(readyCount) 封信到了拆封的日子，轻点火漆读一读吧。", "\(readyCount) \(readyCount == 1 ? "letter is" : "letters are") ready to unseal today.")
                            : L10n.t("盖上一枚火漆，把此刻只存在手机里，留到未来某天再拆开。", "Stamp a wax seal on tonight's thought. Stored only on this iPhone until the day you choose.")
                    )
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                if app.mayKeep() {
                    composeSeedTitle = ""
                    composeSeedSeal = .gold
                    composeSeedUnlock = .firstBirthday
                    TactileEngine.shared.beadClick()
                    composing = true
                }
            } label: {
                Label(L10n.t("封存一封新信", "Seal a New Letter"), systemImage: "envelope.badge.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.vinyl(Palette.accentFill, prominent: true))
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Palette.bead.opacity(dark ? 0.14 : 0.16), Crayon.caramel.opacity(dark ? 0.06 : 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card)
    }

    private func emptyPrompts(dark: Bool) -> some View {
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "little one") : app.nickname
        let prompts: [(String, String, CapsuleSeal, CapsuleComposeSheet.UnlockChoice)] = [
            (
                L10n.t("写给一岁生日的\(who)", "To \(who) on Your 1st Birthday"),
                L10n.t("记下你现在最喜欢的小动作，和我们每天最盼着的事", "Capture the tiny habits you love right now"),
                .gold,
                .firstBirthday
            ),
            (
                L10n.t("今晚灯下想记住的一件小事", "A Quiet Moment Under the Lamp"),
                L10n.t("不用写很长，两三句话就足够温暖很久", "Even two quiet sentences become treasure later"),
                .lilac,
                .anytime
            ),
            (
                L10n.t("等你三岁那年，我们一起读", "For When You Turn Three"),
                L10n.t("等走完这 37 站成长路，回头看看最初的模样", "To open when our 37-month journey wraps up"),
                .teal,
                .thirdBirthday
            ),
        ]

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: L10n.t("从哪里写起", "Gentle Prompts"), detail: L10n.t("轻点可直接起笔", "Tap to begin"))
            ForEach(Array(prompts.enumerated()), id: \.offset) { _, p in
                Button {
                    if app.mayKeep() {
                        composeSeedTitle = p.0
                        composeSeedSeal = p.2
                        composeSeedUnlock = p.3
                        TactileEngine.shared.beadClick()
                        composing = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        WaxSealBadge(seal: p.2, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.0)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text(p.1)
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(13)
                    .printCard(radius: Radius.card)
                }
                .buttonStyle(.toy)
            }
        }
    }
}

// MARK: - Tactile Wax Seal & Cotton-Paper Envelope Cards

struct WaxSealBadge: View {
    let seal: CapsuleSeal
    var size: CGFloat = 42

    var body: some View {
        let base = seal.color
        ZStack {
            // Outer organic wax lip
            Circle()
                .fill(
                    RadialGradient(
                        colors: [base.mix(with: .white, by: 0.25), base, base.mix(with: .black, by: 0.28)],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 1,
                        endRadius: size * 0.68
                    )
                )
                .shadow(color: base.opacity(0.35), radius: size * 0.10, y: size * 0.06)

            // Embossed inner ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.2, size * 0.055)
                )
                .padding(size * 0.14)

            Image(systemName: seal.symbol)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))
                .shadow(color: .black.opacity(0.22), radius: 1, y: 0.8)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct EnvelopeCard: View {
    let capsule: TimeCapsule
    let today: Day
    let dark: Bool
    let tap: () -> Void

    var body: some View {
        let locked = capsule.isLocked(on: today)
        let daysLeft = capsule.daysUntilUnlock(on: today)
        let paperTop = dark ? Color(hex: 0x20294B) : Color(hex: 0xFDF9F1)
        let paperBottom = dark ? Color(hex: 0x171F3C) : Color(hex: 0xF5ECDC)
        let foldColor = dark ? Palette.amber.opacity(0.18) : Color(hex: 0xB89B74).opacity(0.34)

        Button(action: tap) {
            ZStack {
                // Cotton-paper envelope body + delicate diagonal flap crease
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(LinearGradient(colors: [paperTop, paperBottom], startPoint: .top, endPoint: .bottom))

                Canvas { ctx, size in
                    var flap = Path()
                    flap.move(to: CGPoint(x: 10, y: 0))
                    flap.addLine(to: CGPoint(x: size.width / 2, y: 38))
                    flap.addLine(to: CGPoint(x: size.width - 10, y: 0))
                    ctx.stroke(flap, with: .color(foldColor), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
                }
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        WaxSealBadge(seal: capsule.seal, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(capsule.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Text(
                                capsule.writtenAgeLabel.isEmpty
                                    ? capsule.writtenDay.ymd
                                    : L10n.t("写于 \(capsule.writtenAgeLabel) · \(capsule.writtenDay.ymd)", "Written at \(capsule.writtenAgeLabel) · \(capsule.writtenDay.ymd)")
                            )
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        }
                        Spacer(minLength: 4)
                    }

                    HStack(spacing: 8) {
                        if locked, let target = capsule.unlockDay {
                            Label(
                                L10n.t("还有 \(daysLeft) 天拆封 · \(target.ymd)", "Opens in \(daysLeft) \(daysLeft == 1 ? "day" : "days") · \(target.ymd)"),
                                systemImage: "lock.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                            .monospacedDigit()
                        } else {
                            Label(
                                L10n.t("火漆已就绪 · 轻点拆封阅读", "Wax seal ready · Tap to unseal"),
                                systemImage: "sparkles"
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.bead))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }
                .padding(16)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(
                        locked ? foldColor : capsule.seal.color.opacity(dark ? 0.55 : 0.45),
                        lineWidth: locked ? 1 : 1.5
                    )
            )
            .shadow(color: .black.opacity(dark ? 0.25 : 0.08), radius: 8, y: 3)
        }
        .buttonStyle(.toy)
    }
}

private struct OpenedLetterCard: View {
    let capsule: TimeCapsule
    let dark: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    WaxSealBadge(seal: capsule.seal, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(capsule.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(
                            capsule.writtenAgeLabel.isEmpty
                                ? capsule.writtenDay.ymd
                                : L10n.t("写于 \(capsule.writtenAgeLabel) · \(capsule.writtenDay.ymd)", "Written at \(capsule.writtenAgeLabel) · \(capsule.writtenDay.ymd)")
                        )
                        .font(.caption2)
                        .foregroundStyle(Palette.secondaryText)
                    }
                    Spacer(minLength: 4)
                    Text(L10n.t("已拆封", "Opened"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.accent.opacity(0.14)))
                }

                Text(capsule.body)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .printCard(radius: Radius.card)
        }
        .buttonStyle(.toy)
    }
}

// MARK: - Compose Letter Sheet

struct CapsuleComposeSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp

    let store: CapsuleStore
    @State private var title: String
    @State private var letterBody: String = ""
    @State private var seal: CapsuleSeal = .gold
    @State private var unlockOption: UnlockChoice = .firstBirthday
    @State private var customDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    enum UnlockChoice: String, CaseIterable, Identifiable {
        case firstBirthday, secondBirthday, thirdBirthday, fifthBirthday, anytime, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .firstBirthday: L10n.t("1 岁生日", "1st Birthday")
            case .secondBirthday: L10n.t("2 岁生日", "2nd Birthday")
            case .thirdBirthday: L10n.t("3 岁生日", "3rd Birthday")
            case .fifthBirthday: L10n.t("5 岁生日", "5th Birthday")
            case .anytime: L10n.t("随时可拆", "Anytime")
            case .custom: L10n.t("自选日期", "Custom Date")
            }
        }
    }

    init(
        store: CapsuleStore,
        initialTitle: String = "",
        initialSeal: CapsuleSeal = .gold,
        initialUnlock: UnlockChoice = .firstBirthday
    ) {
        self.store = store
        _title = State(initialValue: initialTitle)
        _seal = State(initialValue: initialSeal)
        _unlockOption = State(initialValue: initialUnlock)
    }

    private var availableChoices: [UnlockChoice] {
        var choices: [UnlockChoice] = []
        if let b = app.birth {
            let candidates: [(UnlockChoice, Int)] = [
                (.firstBirthday, 1), (.secondBirthday, 2), (.thirdBirthday, 3), (.fifthBirthday, 5)
            ]
            for (choice, yrs) in candidates {
                if TimeCapsule.birthdayEpochDay(from: b, years: yrs) > app.today.epochDay {
                    choices.append(choice)
                }
            }
        }
        choices.append(.anytime)
        choices.append(.custom)
        return choices
    }

    private var resolvedUnlockEpochDay: Int? {
        switch unlockOption {
        case .firstBirthday: app.birth.map { TimeCapsule.birthdayEpochDay(from: $0, years: 1) }
        case .secondBirthday: app.birth.map { TimeCapsule.birthdayEpochDay(from: $0, years: 2) }
        case .thirdBirthday: app.birth.map { TimeCapsule.birthdayEpochDay(from: $0, years: 3) }
        case .fifthBirthday: app.birth.map { TimeCapsule.birthdayEpochDay(from: $0, years: 5) }
        case .anytime: nil
        case .custom: Day(customDate).epochDay
        }
    }

    private var canSave: Bool {
        !letterBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Seal color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("选一枚火漆印章", "Choose a Wax Seal"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.secondaryText)
                        HStack(spacing: 12) {
                            ForEach(CapsuleSeal.allCases) { item in
                                let picked = seal == item
                                Button {
                                    TactileEngine.shared.beadClick()
                                    seal = item
                                } label: {
                                    VStack(spacing: 5) {
                                        WaxSealBadge(seal: item, size: 38)
                                            .scaleEffect(picked ? 1.12 : 0.96)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Palette.accent, lineWidth: picked ? 2.5 : 0)
                                                    .padding(-4)
                                            )
                                        Text(item.title)
                                            .font(.caption2.weight(picked ? .bold : .medium))
                                            .foregroundStyle(picked ? .primary : Palette.secondaryText)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Unlock milestone chips
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("约定拆封时间", "When to Unseal"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.secondaryText)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 94), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(availableChoices) { choice in
                                let picked = unlockOption == choice
                                Button {
                                    TactileEngine.shared.beadClick()
                                    unlockOption = choice
                                } label: {
                                    Text(choice.label)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(picked ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(picked ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                                        .overlay(Capsule().strokeBorder(Palette.outline.opacity(picked ? 0 : 0.35), lineWidth: 0.75))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if unlockOption == .custom {
                            DatePicker(
                                L10n.t("选择拆封日期", "Unlock date"),
                                selection: $customDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .padding(.top, 4)
                        } else if let target = resolvedUnlockEpochDay {
                            Text(L10n.t("将于 \(Day(epochDay: target).ymd) 自动解锁火漆", "Ready to unseal on \(Day(epochDay: target).ymd)"))
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }

                    // Cotton-paper letter composer
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(
                            L10n.t("信件标题（例如：写给一岁的小满）", "Letter title (e.g., To Leo at Age One)"),
                            text: $title
                        )
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(dark ? Palette.lampCard : Palette.card))

                        ZStack(alignment: .topLeading) {
                            if letterBody.isEmpty {
                                Text(L10n.t("亲爱的宝贝，今晚灯下想对你说……", "Dear little one, tonight under the lamp I wanted to tell you..."))
                                    .font(.body)
                                    .foregroundStyle(Palette.secondaryText.opacity(0.65))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $letterBody)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 190)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        }
                        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(dark ? Palette.lampCard : Color(hex: 0xFDF9F1)))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                .strokeBorder(Palette.outline.opacity(0.32), lineWidth: 0.75)
                        )
                    }
                }
                .padding(16)
            }
            .pageBackground(tone: Crayon.caramel)
            .navigationTitle(L10n.t("封存时光信笺", "Seal a Letter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("盖章封存", "Seal")) {
                        saveLetter()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if !availableChoices.contains(unlockOption) {
                    unlockOption = availableChoices.first ?? .anytime
                }
            }
        }
    }

    private func saveLetter() {
        let trimmedBody = letterBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return }
        let fallbackTitle = L10n.t("写给未来的信", "A Letter for Later")
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let ageLabel = app.birth.map { Firsts.age(from: $0, to: app.today) } ?? ""
        let cap = TimeCapsule(
            title: trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle,
            body: trimmedBody,
            writtenAt: Date().timeIntervalSince1970 * 1000,
            writtenAgeLabel: ageLabel,
            unlockEpochDay: resolvedUnlockEpochDay,
            openedAt: nil,
            seal: seal
        )
        store.save(cap)
        TactileEngine.shared.goldChime()
        dismiss()
    }
}

// MARK: - Unseal & Read Letterpress Stationery Sheet

struct CapsuleReadSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce

    let capsule: TimeCapsule
    let store: CapsuleStore

    @State private var isOpened: Bool
    @State private var confirmEarlyOpen = false
    @State private var confirmDelete = false

    init(capsule: TimeCapsule, store: CapsuleStore) {
        self.capsule = capsule
        self.store = store
        _isOpened = State(initialValue: capsule.openedAt != nil)
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let locked = !isOpened && capsule.isLocked(on: app.today)
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname

        let poster = RenderedPoster {
            let card = CapsulePrintPoster(capsule: capsule, babyName: who)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3.0
            return renderer.uiImage
        }

        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if isOpened {
                        stationeryPage(dark: dark)
                    } else {
                        sealedCeremonyView(dark: dark, locked: locked)
                    }
                }
                .padding(20)
            }
            .pageBackground(tone: Crayon.caramel)
            .navigationTitle(isOpened ? L10n.t("时光信笺", "Time Capsule") : L10n.t("火漆封存中", "Sealed Envelope"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isOpened {
                        ShareLink(
                            item: poster,
                            preview: SharePreview(capsule.title)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(L10n.t("保存或分享信笺卡片", "Save or share letter card"))
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(L10n.t("删除这封信", "Delete this letter"))
                }
            }
            .alert(L10n.t("提前揭开火漆吗？", "Break the Wax Seal Early?"), isPresented: $confirmEarlyOpen) {
                Button(L10n.t("再等等", "Keep Sealed"), role: .cancel) {}
                Button(L10n.t("现在拆封", "Unseal Now")) { unsealNow() }
            } message: {
                if let target = capsule.unlockDay {
                    Text(L10n.t("原定在 \(target.ymd) 拆封，随时也可以提前读一读。", "Scheduled for \(target.ymd). You are always free to open it now."))
                }
            }
            .alert(L10n.t("删除这封信？", "Delete This Letter?"), isPresented: $confirmDelete) {
                Button(L10n.t("取消", "Cancel"), role: .cancel) {}
                Button(L10n.t("删除", "Delete"), role: .destructive) {
                    store.delete(id: capsule.id)
                    dismiss()
                }
            } message: {
                Text(L10n.t("删除后将从这台手机永久移除。", "This letter will be permanently removed from this iPhone."))
            }
        }
    }

    private func sealedCeremonyView(dark: Bool, locked: Bool) -> some View {
        let daysLeft = capsule.daysUntilUnlock(on: app.today)
        return VStack(spacing: 22) {
            Spacer(minLength: 16)

            Button {
                if locked {
                    confirmEarlyOpen = true
                } else {
                    unsealNow()
                }
            } label: {
                VStack(spacing: 18) {
                    WaxSealBadge(seal: capsule.seal, size: 88)

                    VStack(spacing: 6) {
                        Text(capsule.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text(
                            capsule.writtenAgeLabel.isEmpty
                                ? L10n.t("封存于 \(capsule.writtenDay.ymd)", "Sealed on \(capsule.writtenDay.ymd)")
                                : L10n.t("写于 \(capsule.writtenAgeLabel) · \(capsule.writtenDay.ymd)", "Written at \(capsule.writtenAgeLabel) · \(capsule.writtenDay.ymd)")
                        )
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                    }

                    if locked, let target = capsule.unlockDay {
                        VStack(spacing: 4) {
                            Text(L10n.t("还剩 \(daysLeft) 天", "\(daysLeft) \(daysLeft == 1 ? "day" : "days") to go"))
                                .font(Typeface.numerals(26, relativeTo: .title2, weight: .bold))
                                .foregroundStyle(Palette.accent)
                            Text(L10n.t("约定拆封日：\(target.ymd)", "Unseals on \(target.ymd)"))
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                        }
                        .padding(.top, 4)
                    } else {
                        Text(L10n.t("轻点火漆，拆开这封信", "Tap the wax seal to unseal"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Palette.accentFill))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(dark ? Palette.lampCard : Color(hex: 0xFDF9F1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(capsule.seal.color.opacity(0.45), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(dark ? 0.35 : 0.10), radius: 14, y: 6)
            }
            .buttonStyle(.toy)

            if locked {
                Button {
                    confirmEarlyOpen = true
                } label: {
                    Text(L10n.t("提前揭开火漆读一读", "Break Wax Seal Early"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
    }

    private func stationeryPage(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                WaxSealBadge(seal: capsule.seal, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(capsule.writtenDay.ymd)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                    if !capsule.writtenAgeLabel.isEmpty {
                        Text(L10n.t("那时的你 · \(capsule.writtenAgeLabel)", "You were \(capsule.writtenAgeLabel)"))
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                Spacer()
                Duo(primary: app.companion, size: 42, poke: false, night: dark)
            }

            Text(capsule.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Divider().opacity(0.4)

            Text(capsule.body)
                .font(.body)
                .lineSpacing(8)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().opacity(0.3)
                .padding(.top, 8)

            HStack {
                GoldBead(size: 8)
                Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯", "Moss & Otto · They explore. You hold the light."))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                Spacer()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(dark ? Palette.lampCard : Color(hex: 0xFDF9F1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(dark ? Palette.amber.opacity(0.22) : Color(hex: 0xC6A982).opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(dark ? 0.35 : 0.10), radius: 12, y: 5)
    }

    private func unsealNow() {
        store.open(id: capsule.id)
        TactileEngine.shared.goldChime()
        withAnimation(reduce ? nil : .spring(response: 0.44, dampingFraction: 0.80)) {
            isOpened = true
        }
    }
}

/// 3× high-resolution cotton-paper print keepsake for sharing or archiving an opened Time Capsule letter.
private struct CapsulePrintPoster: View {
    let capsule: TimeCapsule
    let babyName: String

    var body: some View {
        let paper = Color(hex: 0xFBF7F0)
        let ink = Color(hex: 0x241F1B)
        let teal = Color(hex: 0x0B7D74)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                WaxSealBadge(seal: capsule.seal, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("\(babyName) 的时光信笺", "\(babyName)'s Time Capsule"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                    Text(
                        capsule.writtenAgeLabel.isEmpty
                            ? capsule.writtenDay.ymd
                            : "\(capsule.writtenDay.ymd) · \(capsule.writtenAgeLabel)"
                    )
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.55))
                }
                Spacer()
            }

            Text(capsule.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(ink)

            Divider().opacity(0.35)

            Text(capsule.body)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .lineSpacing(6)
                .foregroundStyle(ink.opacity(0.88))

            Divider().opacity(0.3).padding(.top, 6)

            Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯", "Moss & Otto · They explore. You hold the light."))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(ink.opacity(0.50))
        }
        .padding(24)
        .frame(width: 360)
        .background(paper)
    }
}
