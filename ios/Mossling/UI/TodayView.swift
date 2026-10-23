import SwiftUI

/// Today, as a page of the book: the scene with the two companions and the child's age, today's play, this week's
/// shelf, and the next vaccination or check-up; from 36 months, the road that goes on.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    @State private var askBirth = false
    @State private var arranging = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SceneCard(askBirth: $askBirth)
                if let age = app.age {
                    let m = age.bookMonth
                    if age.months >= 36 { StoryGoesOn(primary: app.companion) }
                    let plays = app.todaysPlays(m)
                    if !plays.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: "今天的教具")
                            if app.skippedToday {
                                HStack {
                                    Text("今天不安排活动。").font(.body).foregroundStyle(.secondary)
                                    Spacer()
                                    Button("恢复") { withAnimation(.snappy) { app.skipDay = -1 } }.buttonStyle(.glass)
                                }
                                .padding(16).printCard()
                            } else {
                                PlayHero(play: plays[app.pickIndex % plays.count], month: m, count: plays.count)
                            }
                        }
                    }
                    ShelfView(month: m) { arranging = true }
                    NextCare(month: m)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("今天")
        .navigationSubtitle([app.nickname.isEmpty ? nil : app.nickname, "\(app.today.md) \(app.today.weekday)"].compactMap { $0 }.joined(separator: " · "))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: Route.search) { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索") }
        }
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .sheet(isPresented: $arranging) { ShelfEditor() }
    }
}

/// The scene: the companions on their hill under today's sky, and the child's age written on it.
private struct SceneCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Binding var askBirth: Bool
    private var hour: Int { Day.cal.component(.hour, from: Date()) }

    var body: some View {
        let ink = Sky.ink(hour, scheme)
        ZStack(alignment: .topLeading) {
            Sky(hour: hour)
            VStack(alignment: .leading, spacing: 2) {
                if let age = app.age {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(age.months)").font(Typeface.numerals(56, relativeTo: .largeTitle, weight: .bold))
                        Text("个月").font(.title3.weight(.semibold))
                        if age.days > 0 {
                            Text("\(age.days)").font(Typeface.numerals(30, relativeTo: .title, weight: .bold)).padding(.leading, 4)
                            Text("天").font(.title3.weight(.semibold))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(age.days > 0 ? "\(age.months) 个月 \(age.days) 天" : "满 \(age.months) 个月")
                    Text(verbatim: age.months < 36 ? "再过 \(age.toNext) 天满 \(age.months + 1) 个月" : "第 \(age.lived) 天")
                        .font(.subheadline.weight(.medium)).opacity(0.75).monospacedDigit()
                } else {
                    Text("你好").font(.largeTitle.weight(.bold))
                    Button { askBirth = true } label: { Text("填写出生日期").padding(.horizontal, 4) }
                        .buttonStyle(.glassProminent).controlSize(.large).padding(.top, 8)
                }
            }
            .foregroundStyle(ink)
            .padding(18)
            Duo(primary: app.companion, size: 112, mood: isNight ? .sleep : .open, look: CGPoint(x: -0.7, y: 0.1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 6).padding(.bottom, 4)
        }
        .frame(height: 236)
        .printCard(radius: 30)
    }
    private var isNight: Bool { let h = hour; return h >= 22 || h < 6 }
}

/// Today's play as a material card: the first step's picture, the name, the area and age, and what to do with it.
private struct PlayHero: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let play: Play, month: Int, count: Int
    @State private var cheer = 0
    var body: some View {
        let key = Palette.areaKey(of: play)
        let route = Route.play(play.code, month)
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: route) {
                VStack(alignment: .leading, spacing: 0) {
                    if let f = ArtIndex.shared.steps(play.code).first { ArtView(name: f, label: "第一步的图示", radius: 0) }
                    VStack(alignment: .leading, spacing: 6) {
                        Label(play.domains.joined(separator: "、"), systemImage: Palette.areaSymbol(key)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.area(key))
                        Text(play.name).font(.title2.weight(.bold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        DoneCount(record: app.record(play, j), cheer: cheer)
                    }
                    .padding(.horizontal, 16).padding(.top, 14)
                }
            }
            .buttonStyle(.toy)
            HStack(spacing: 10) {
                Button { withAnimation(.snappy) { app.didPlay(play, month: month, j); cheer += 1 } } label: {
                    Label("做过了", systemImage: "checkmark").fixedSize().padding(.horizontal, 4)
                }
                .buttonStyle(.glassProminent).controlSize(.large)
                .sensoryFeedback(.success, trigger: cheer)
                if count > 1 {
                    Button("换一个") { withAnimation(.snappy) { app.another() } }.buttonStyle(.glass).controlSize(.large)
                }
                Spacer(minLength: 0)
                Menu {
                    PlayActions(play: play, month: month)
                    Divider()
                    Button("今天不安排活动", systemImage: "moon.zzz") { withAnimation(.snappy) { app.skipDay = app.today.epochDay } }
                } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }
                    .buttonStyle(.glass).controlSize(.large).accessibilityLabel("更多")
            }
            .padding(16)
        }
        .printCard(radius: 26)
        .zoomSource(route)
        .contextMenu { PlayActions(play: play, month: month) }
    }
}

/// This week's shelf: a wooden shelf with the week's materials standing on it, and empty places to fill.
struct ShelfView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let month: Int
    let arrange: () -> Void
    var body: some View {
        let s = app.weekShelf(month)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("本周的架子").font(.title3.weight(.bold))
                Spacer()
                Button(s.stale ? "换上新的一周" : "整理", action: arrange).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 4).padding(.top, 2)
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<Shelf.max, id: \.self) { k in
                        if k < s.plays.count {
                            let p = s.plays[k], route = Route.play(p.code, month)
                            NavigationLink(value: route) { ShelfItem(play: p, times: app.record(p, j).count) }
                                .buttonStyle(.toy).zoomSource(route)
                                .contextMenu { PlayActions(play: p, month: month) }
                        } else {
                            Button(action: arrange) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Palette.outline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                                    .overlay(Image(systemName: "plus").font(.title3).foregroundStyle(.tertiary))
                                    .aspectRatio(0.72, contentMode: .fit)
                            }
                            .buttonStyle(.toy).accessibilityLabel("放一件教具")
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.top, 14)
                // the wooden board
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color(hex: 0xC99B63))
                    .frame(height: 12)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color(hex: 0x8F6A3E)).offset(x: 2, y: 2.5))
                    .padding(.horizontal, 4)
            }
            .padding(.bottom, 10)
            .printCard(radius: 26, fill: Color.dyn(0xF5E9D6, 0x2B241C))
        }
    }
}

/// One material on the shelf: its picture on a small card, its name below.
private struct ShelfItem: View {
    let play: Play
    let times: Int
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let f = ArtIndex.shared.steps(play.code).first { ArtFill(name: f).aspectRatio(1, contentMode: .fit) }
                if times > 0 {
                    Text("×\(times)").font(Typeface.numerals(11, relativeTo: .caption, weight: .bold)).foregroundStyle(Color(hex: 0x4A3300))
                        .padding(.horizontal, 6).frame(height: 18)
                        .background(Capsule().fill(LinearGradient(colors: [Palette.beadLight, Palette.bead], startPoint: .top, endPoint: .bottom)))
                        .padding(4)
                }
            }
            .printCard(radius: 14)
            Text(play.name).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Arranging the shelf, as a sheet.
struct ShelfEditor: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            PlanView(path: .constant(NavigationPath()))
                .routes(path: .constant(NavigationPath()))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { dismiss() } } }
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
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
            NavigationLink(value: Route.care(next)) {
                Card(title: "接种与儿保", symbol: "syringe.fill", color: Crayon.sky, detail: next == month ? "满 \(next) 个月" : birth.plus(months: next).md, opens: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(items.first ?? "").font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        if items.count > 1 { Text("另有 \(items.count - 1) 项").font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
            }
            .buttonStyle(.toy)
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
