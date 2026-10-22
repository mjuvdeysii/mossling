import SwiftUI

/// Today: how old the child is today, the one play for today, this week's shelf, and the next vaccination or check-up.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var journal
    @Binding var path: NavigationPath
    @State private var askBirth = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(askBirth: $askBirth)
                if let age = app.age {
                    let m = age.bookMonth
                    if age.months >= 36 { StoryGoesOn(primary: app.companion).padding(.horizontal, 16).padding(.top, 16) }
                    let plays = app.todaysPlays(m)
                    if !plays.isEmpty {
                        let p = plays[app.pickIndex % plays.count]
                        Group {
                            if app.skippedToday {
                                HStack {
                                    Text("今天不做活动，也很好。").font(.subheadline)
                                    Spacer()
                                    Button("还是看看") { app.skipDay = -1 }
                                }
                                .card(Palette.cardLow)
                            } else {
                                PlayPlate(play: p, month: m, count: plays.count) { path.append(Route.play(p.code, m)) }
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 20)
                    }
                    if app.journal && !journal.timers.isEmpty {
                        VStack(spacing: 8) { ForEach(journal.timers, id: \.type) { TimerCard(timer: $0) } }.padding(.horizontal, 16).padding(.top, 14)
                    }
                    ShelfCard(month: m) { path.append(Route.plan) }.padding(.horizontal, 16).padding(.top, 14)
                    NextCare(month: m) { path.append(Route.month(m)) }.padding(.horizontal, 16).padding(.top, 14)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Palette.background)
        .navigationTitle("今天")
        .navigationSubtitle([app.nickname.isEmpty ? nil : app.nickname, "\(app.today.md) \(app.today.weekday)"].compactMap { $0 }.joined(separator: " · "))
        .sheet(isPresented: $askBirth) { BirthSheet() }
    }
}

private struct Hero: View {
    @Environment(AppModel.self) private var app
    @Binding var askBirth: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                if let age = app.age {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            // the age on a sandpaper-number board
                            Text("\(age.months)").font(Typeface.numerals(60, relativeTo: .largeTitle)).foregroundStyle(.white)
                                .padding(.horizontal, 16).padding(.vertical, 4)
                                .glassEffect(.regular.tint(Palette.moss), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            VStack(alignment: .leading, spacing: 0) {
                                Text("个月").font(Typeface.serif(20))
                                if age.days > 0 {
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text("\(age.days)").font(Typeface.numerals(30)).foregroundStyle(Palette.primary)
                                        Text("天").font(.headline)
                                    }
                                }
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(age.days > 0 ? "\(age.months) 个月 \(age.days) 天" : "满 \(age.months) 个月")
                        Text(verbatim: age.months < 36 ? "再过 \(age.toNext) 天满 \(age.months + 1) 个月 · 一起走过第 \(age.lived) 天" : "一起走过第 \(age.lived) 天")
                            .font(.footnote).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                        DayBeads(done: age.days, total: age.days + age.toNext).frame(height: 10)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("你好。").font(Typeface.serif(32, relativeTo: .largeTitle))
                        Text("填写出生日期，开始第一站。").font(.body)
                        Button { askBirth = true } label: { Text("填写出生日期").padding(.horizontal, 6) }
                            .buttonStyle(.glassProminent).controlSize(.large)
                    }
                }
                Spacer(minLength: 8)
                Duo(primary: app.companion, size: 92, mood: isNight ? .sleep : .open, look: CGPoint(x: -0.85, y: 0.25))
            }
        }
        .padding(.horizontal, 20).padding(.top, 4)
    }
    private var isNight: Bool { let h = Day.cal.component(.hour, from: Date()); return h >= 22 || h < 6 }
}

/// This month as a row of beads: one per day, filled up to today.
private struct DayBeads: View {
    let done: Int, total: Int
    var body: some View {
        Canvas { ctx, size in
            let n = max(1, min(31, total)); let gap = size.width / CGFloat(n); let r = min(gap * 0.32, 4)
            for i in 0..<n {
                let c = CGPoint(x: gap * CGFloat(i) + gap / 2, y: size.height / 2)
                if i < done { ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Palette.primary)) }
                else if i == done { let R = r * 1.25; ctx.fill(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)), with: .color(Palette.bead)) }
                else { ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Palette.outline), lineWidth: 1.2) }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Today's play on a wooden work tray: what, for whom, the first step as a picture, safety, and what to do next.
private struct PlayPlate: View {
    @Environment(AppModel.self) private var app
    let play: Play, month: Int, count: Int
    let open: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今天一起玩").font(.caption.weight(.semibold)).foregroundStyle(Palette.primary)
                    Text(play.name).font(Typeface.serif(22, relativeTo: .title2)).fixedSize(horizontal: false, vertical: true)
                    Text([play.age, play.domains.joined(separator: "、")].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.footnote).foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 8)
                CodeTile(code: play.code, tint: app.companion.tint, size: 22)
            }
            if let f = ArtIndex.shared.steps(play.code).first { ArtView(name: f, label: "第一步的图示") }
            if let s = play.steps.first { Text(s).font(.body).fixedSize(horizontal: false, vertical: true) }
            if !play.safety.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("安全").font(.caption.weight(.bold)).foregroundStyle(Palette.danger)
                    Text(play.safety).font(.footnote)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
        }
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }
    @ViewBuilder private var buttons: some View {
        Button(action: open) { Text("开始").frame(minWidth: 64) }.buttonStyle(.glassProminent).controlSize(.large)
        if count > 1 { Button("换一个") { withAnimation(.snappy) { app.another() } }.buttonStyle(.glass).controlSize(.large) }
        Spacer(minLength: 0)
        Button("今天不做") { withAnimation(.snappy) { app.skipDay = app.today.epochDay } }.foregroundStyle(Palette.secondaryText)
    }
}

/// This week's shelf: the materials out this week, as small pictures.
private struct ShelfCard: View {
    @Environment(AppModel.self) private var app
    let month: Int
    let open: () -> Void
    var body: some View {
        let s = app.weekShelf(month)
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本周的架子").font(.headline)
                        Text(s.stale ? "新的一周，可以换一换" : "\(s.plays.count) 件教具").font(.footnote).foregroundStyle(s.stale ? Palette.tertiary : Palette.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                }
                HStack(alignment: .top, spacing: 10) {
                    ForEach(s.plays.prefix(4)) { p in
                        VStack(spacing: 6) {
                            if let f = ArtIndex.shared.steps(p.code).first { ArtView(name: f, radius: 12) }
                            Text(p.code).font(Typeface.numerals(15))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    ForEach(0..<max(0, 3 - s.plays.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                }
            }
            .card(Palette.cardLow, radius: 28)
        }
        .buttonStyle(.plain)
    }
}

/// The next vaccination or check-up not yet recorded; shown only when the app is opened, never as a reminder.
private struct NextCare: View {
    @Environment(AppModel.self) private var app
    let month: Int
    let open: () -> Void
    var body: some View {
        let c = app.content
        if let birth = app.birth, let next = (month...36).first(where: { k in
            let mo = c.month(k)
            return mo.vaccines.indices.contains { !app.ticked(k, TickKind.vaccine, "\($0)") } || mo.checkups.indices.contains { !app.ticked(k, TickKind.checkup, "\($0)") }
        }) {
            let mo = c.month(next); let items = mo.vaccines + mo.checkups
            Button(action: open) {
                HStack(spacing: 14) {
                    Image(systemName: "syringe.fill").foregroundStyle(Palette.onSecondaryContainer)
                        .frame(width: 44, height: 44).background(Palette.secondaryContainer, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next == month ? "这个月的接种与儿保" : "下一次 · 满 \(next) 个月 · \(birth.plus(months: next).md)").font(.subheadline.weight(.semibold))
                        Text(items[0] + (items.count > 1 ? " 等 \(items.count) 项" : "")).font(.subheadline).foregroundStyle(Palette.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .card(Palette.cardLow, radius: 22, padding: 14)
            }
            .buttonStyle(.plain)
        }
    }
}

/// The child's date of birth.
struct BirthSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("出生日期", selection: $date, in: Calendar.current.date(byAdding: .year, value: -4, to: Date())!...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle("宝宝的出生日期").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("好") { app.birth = Day(date); dismiss() } }
            }
            .onAppear { if let b = app.birth { date = b.date } }
        }
        .presentationDetents([.large])
    }
}
