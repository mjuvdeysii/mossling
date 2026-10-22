import SwiftUI

/// Today: the scene with the two companions and the child's age, then only what matters today — the one play, this
/// week's shelf, the next vaccination or check-up — and, from 36 months, the road that goes on.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    @State private var askBirth = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Hero(askBirth: $askBirth)
                VStack(alignment: .leading, spacing: 14) {
                    if let age = app.age {
                        let m = age.bookMonth
                        if age.months >= 36 { StoryGoesOn(primary: app.companion) }
                        let plays = app.todaysPlays(m)
                        if !plays.isEmpty {
                            if app.skippedToday {
                                Card(title: "今天一起玩", symbol: "sun.max.fill", color: Palette.accent) {
                                    HStack {
                                        Text("今天不安排活动。").font(.body)
                                        Spacer()
                                        Button("恢复") { withAnimation(.snappy) { app.skipDay = -1 } }.buttonStyle(.glass)
                                    }
                                }
                            } else {
                                let p = plays[app.pickIndex % plays.count]
                                PlayHero(play: p, month: m, count: plays.count)
                            }
                        }
                        NavigationLink(value: Route.plan) { ShelfCard(month: m) }.buttonStyle(.plain)
                        NextCare(month: m)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Palette.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $askBirth) { BirthSheet() }
    }
}

/// The scene: sky, hills, the companions, and the age set large.
private struct Hero: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Binding var askBirth: Bool
    private var hour: Int { Day.cal.component(.hour, from: Date()) }

    var body: some View {
        let ink = Sky.ink(hour, scheme)
        ZStack(alignment: .topLeading) {
            Sky(hour: hour)
            VStack(alignment: .leading, spacing: 4) {
                Text([app.nickname.isEmpty ? nil : app.nickname, "\(app.today.md) \(app.today.weekday)"].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(ink.opacity(0.75))
                if let age = app.age {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(age.months)").font(Typeface.numerals(64, relativeTo: .largeTitle, weight: .bold))
                        Text("个月").font(.title3.weight(.semibold))
                        if age.days > 0 {
                            Text("\(age.days)").font(Typeface.numerals(34, relativeTo: .title, weight: .bold)).padding(.leading, 6)
                            Text("天").font(.title3.weight(.semibold))
                        }
                    }
                    .foregroundStyle(ink)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(age.days > 0 ? "\(age.months) 个月 \(age.days) 天" : "满 \(age.months) 个月")
                    Text(verbatim: age.months < 36 ? "再过 \(age.toNext) 天满 \(age.months + 1) 个月 · 第 \(age.lived) 天" : "第 \(age.lived) 天")
                        .font(.footnote.weight(.medium)).foregroundStyle(ink.opacity(0.75)).monospacedDigit()
                } else {
                    Text("芽芽月历").font(.largeTitle.weight(.bold)).foregroundStyle(ink)
                    Button { askBirth = true } label: { Text("填写出生日期").padding(.horizontal, 4) }
                        .buttonStyle(.glassProminent).controlSize(.large).padding(.top, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 70)
            Duo(primary: app.companion, size: 104, mood: isNight ? .sleep : .open, look: CGPoint(x: -0.7, y: 0.1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 12).padding(.bottom, 18)
        }
        .frame(height: 360)
    }
    private var isNight: Bool { let h = hour; return h >= 22 || h < 6 }
}

/// Today's play, picture first: the first step as a picture, the name, the area and age, and the three things one can
/// do with it.
private struct PlayHero: View {
    @Environment(AppModel.self) private var app
    let play: Play, month: Int, count: Int
    var body: some View {
        let key = Palette.areaKey(of: play)
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: Route.play(play.code, month)) {
                VStack(alignment: .leading, spacing: 0) {
                    if let f = ArtIndex.shared.steps(play.code).first {
                        ArtFill(name: f, label: "第一步的图示").frame(height: 190)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label("今天一起玩", systemImage: Palette.areaSymbol(key)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.area(key))
                        Text(play.name).font(.title2.weight(.bold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        Text([play.age, play.domains.joined(separator: "、")].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.top, 14)
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                NavigationLink(value: Route.play(play.code, month)) { Text("开始").padding(.horizontal, 8) }
                    .buttonStyle(.glassProminent).controlSize(.large)
                if count > 1 {
                    Button("换一个") { withAnimation(.snappy) { app.another() } }.buttonStyle(.glass).controlSize(.large)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("今天不安排活动", systemImage: "moon.zzz") { withAnimation(.snappy) { app.skipDay = app.today.epochDay } }
                } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }
                    .buttonStyle(.glass).controlSize(.large).accessibilityLabel("更多")
            }
            .padding(16)
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// This week's shelf: the materials out this week.
private struct ShelfCard: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let s = app.weekShelf(month)
        Card(title: "本周的架子", symbol: "square.grid.2x2.fill", color: Crayon.caramel, detail: s.stale ? "可以换新" : "\(s.plays.count) 件", opens: true) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(s.plays.prefix(4)) { p in
                    let k = Palette.areaKey(of: p)
                    HStack(spacing: 12) {
                        IconTile(symbol: Palette.areaSymbol(k), color: Palette.area(k), size: 28)
                        Text(p.name).font(.body).foregroundStyle(.primary).lineLimit(2)
                    }
                }
            }
        }
    }
}

/// The next vaccination or check-up not yet recorded; shown when the app is opened, never as a reminder.
private struct NextCare: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let c = app.content
        if let birth = app.birth, let next = (month...36).first(where: { k in
            let mo = c.month(k)
            return mo.vaccines.indices.contains { !app.ticked(k, TickKind.vaccine, "\($0)") } || mo.checkups.indices.contains { !app.ticked(k, TickKind.checkup, "\($0)") }
        }) {
            let mo = c.month(next)
            let items = mo.vaccines.enumerated().filter { !app.ticked(next, TickKind.vaccine, "\($0.offset)") }.map(\.element)
                + mo.checkups.enumerated().filter { !app.ticked(next, TickKind.checkup, "\($0.offset)") }.map(\.element)
            NavigationLink(value: Route.month(next)) {
                Card(title: "接种与儿保", symbol: "syringe.fill", color: Crayon.sky, detail: next == month ? "满 \(next) 个月" : birth.plus(months: next).md, opens: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(items.first ?? "").font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        if items.count > 1 { Text("另有 \(items.count - 1) 项").font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
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
            .navigationTitle("出生日期").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { app.birth = Day(date); dismiss() } }
            }
            .onAppear { if let b = app.birth { date = b.date } }
        }
        .presentationDetents([.large])
    }
}
