import SwiftUI

/// The home, in the order of how often it is needed (ios/DESIGN.md §5): the month as one compact card that opens into
/// the growth wheel in place; this week's shelf, the everyday reason to open the app; the month's other plays; the
/// month's parts and the topics as small tiles. Turning the wheel changes the month and everything below follows.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Binding var path: NavigationPath
    @State private var askBirth = false
    @State private var arranging = false
    @State private var chosen: Int?
    @State private var wheel = false

    var body: some View {
        let baby = app.babyMonth ?? 0
        let m = chosen ?? baby
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if app.age == nil {
                    Button { askBirth = true } label: { Label("填写出生日期，从宝宝这个月开始", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.borderedProminent).tint(Palette.accentFill).controlSize(.large)
                }
                if wheel {
                    GrowthWheel(month: Binding(get: { m }, set: { chosen = $0 == baby ? nil : $0 }), baby: baby)
                        .overlay(alignment: .topTrailing) {
                            Button { withAnimation(.snappy) { wheel = false } } label: {
                                Image(systemName: "chevron.up").font(.footnote.weight(.bold)).frame(width: 30, height: 30)
                                    .background(.white.opacity(0.85), in: Circle())
                            }
                            .foregroundStyle(Color(hex: 0x2E2418)).padding(12).accessibilityLabel("收起成长滚轮")
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else {
                    MonthCard(month: m, baby: baby) { withAnimation(.snappy) { wheel = true } }
                        .transition(.opacity)
                }
                if m >= 36 { StoryGoesOn(primary: app.companion) }
                if m == baby && app.age != nil { ShelfView(month: m) { arranging = true } }
                PlaysGrid(month: m, hideShelf: m == baby && app.age != nil)
                MonthParts(month: m)
                Topics()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle(app.nickname.isEmpty ? "芽芽月历" : app.nickname)
        .navigationSubtitle(app.age.map { a in a.days > 0 ? "\(a.months) 个月 \(a.days) 天" : "满 \(a.months) 个月" } ?? "\(app.today.md) \(app.today.weekday)")
        .toolbar {
            if chosen != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("回到本月", systemImage: "arrow.uturn.backward") { withAnimation(.snappy) { chosen = nil } }
                }
            }
            ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: Route.search) { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索") }
        }
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .sheet(isPresented: $arranging) { ShelfEditor() }
        .onChange(of: app.babyMonth) { _, _ in chosen = nil }
    }
}

/// The month, folded: the child at this age on a small patch of sky, the month and its title. Tapping it opens the
/// growth wheel in place.
private struct MonthCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
    @Environment(\.dynamicTypeSize) private var type
    let month: Int, baby: Int
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                ZStack {
                    Sky(hour: night ? 22 : 12)
                    GrowingChild(month: month).frame(width: 58, height: 58).offset(y: 4)
                }
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(month == 0 ? "出生" : "\(month)").font(Typeface.numerals(26, relativeTo: .title2, weight: .bold))
                        if month > 0 { Text("个月").font(.subheadline.weight(.semibold)) }
                        if month != baby { Text(month < baby ? "· 走过的一站" : "· 以后的一站").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                    }
                    Text(app.content.month(month).title).font(.subheadline).foregroundStyle(.secondary).lineLimit(type.isAccessibilitySize ? nil : 2).multilineTextAlignment(.leading)
                }
                .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(10).padding(.trailing, 6)
            .printCard(radius: 24)
        }
        .buttonStyle(.toy)
        .accessibilityLabel("\(month == 0 ? "出生" : "\(month) 个月")，\(app.content.month(month).title)")
        .accessibilityHint("打开成长滚轮，选择月份")
    }
}

/// The month's plays as picture cards: the one done least (the natural next one) leads, full width.
struct PlaysLeadGrid: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let plays: [Play], month: Int
    var body: some View {
        // a stable order: not yet done first, then the fewest times
        let ordered = plays.enumerated().sorted { a, b in
            let x = app.record(a.element, j).count, y = app.record(b.element, j).count
            return x != y ? x < y : a.offset < b.offset
        }.map(\.element)
        LeadGrid(items: ordered) { PlayTileLink(play: $0, month: month, form: .lead) }
            cell: { PlayTileLink(play: $0, month: month) }
            row: { PlayTileLink(play: $0, month: month, form: .row) }
    }
}

/// The month's plays as picture cards, two by two; this month's shelf is shown above, so its plays are not repeated.
private struct PlaysGrid: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    let month: Int
    let hideShelf: Bool
    var body: some View {
        let shelf = hideShelf ? app.weekShelf(month).plays.map(\.code) : []
        let plays = app.content.plays(of: month).filter { !shelf.contains($0.code) }
        if !plays.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: hideShelf ? "这个月还能玩" : "这个月的教具", detail: "\(plays.count) 个")
                PlaysLeadGrid(plays: plays, month: month)
            }
        }
    }
}

/// The topics' marks: all five are care topics, so one colour (the care area's), told apart by their symbols.
let topicMarks: [(String, Color)] = ["moon.zzz.fill", "bed.double.fill", "fork.knife", "mouth.fill", "cross.case.fill"].map { ($0, Palette.area("F")) }

/// The topics, as tiles.
private struct Topics: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let items = app.content.topics.enumerated().map { TopicItem(i: $0.offset, t: $0.element) }
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "专题")
            LeadGrid(items: items) { x in
                link(x) {
                    HStack(spacing: 14) {
                        IconTile(symbol: topicMarks[x.i % topicMarks.count].0, color: topicMarks[x.i % topicMarks.count].1, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(x.t.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Text(x.t.sourceTitle).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.area("F").opacity(0.1)).printCard(radius: 22)
                }
            } cell: { x in
                link(x) { tile(x).frame(minHeight: 64).printCard(radius: 20) }
            } row: { x in
                link(x) { tile(x).printCard(radius: 20) }
            }
        }
    }
    private func link<L: View>(_ x: TopicItem, @ViewBuilder _ label: () -> L) -> some View {
        NavigationLink(value: Route.topic(x.t.id)) { label() }.buttonStyle(.toy)
    }
    private func tile(_ x: TopicItem) -> some View {
        HStack(spacing: 10) {
            IconTile(symbol: topicMarks[x.i % topicMarks.count].0, color: topicMarks[x.i % topicMarks.count].1, size: 34)
            Text(x.t.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct TopicItem: Identifiable { let i: Int; let t: Topic; var id: String { t.id } }

/// This week's shelf: a wooden shelf with the week's materials standing on it, and empty places to fill.
struct ShelfView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
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
            // a two-level shelf, two materials on each level: the week's plays are the largest pictures on the page
            VStack(spacing: 6) {
                ForEach(0..<(Shelf.max + 1) / 2, id: \.self) { row in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach([row * 2, row * 2 + 1], id: \.self) { k in slot(k, s) }
                        }
                        .padding(.horizontal, 12).padding(.top, 12)
                    }
                }
            }
            .padding(.bottom, 12)
            .printCard(radius: 26)
            .overlay(alignment: .top) {
                // perched on the top of the shelf, between the title and 整理
                Duo(primary: night ? .otto : app.companion, size: 58, look: CGPoint(x: -0.7, y: 0.4), night: night)
                    .offset(x: 40, y: -52)
            }
            .padding(.top, 18)
        }
    }
}

extension ShelfView {
    @ViewBuilder func slot(_ k: Int, _ s: (plays: [Play], stale: Bool)) -> some View {
        if k < s.plays.count {
            let p = s.plays[k], route = Route.play(p.code, month)
            NavigationLink(value: route) { ShelfItem(play: p, times: app.record(p, j).count) }
                .buttonStyle(.toy).zoomSource(route)
                .contextMenu { PlayActions(play: p, month: month) }
        } else {
            Button(action: arrange) {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.outline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        .overlay(Image(systemName: "plus").font(.title3).foregroundStyle(.tertiary))
                        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 16)
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .background(alignment: .bottom) { Plank().frame(height: 18).padding(.horizontal, -10).offset(y: 6) }
                    Text("放一件").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 30, alignment: .top).padding(.top, 10)
                }
            }
            .buttonStyle(.toy).accessibilityLabel("放一件教具")
        }
    }
}

/// A wooden plank seen a little from above: a lit top face, a darker front edge, a soft shadow beneath.
private struct Plank: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xF3D3A6), Color(hex: 0xE2B47E)], startPoint: .top, endPoint: .bottom))
                .frame(height: 9)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xC98F5E), Color(hex: 0xA9733F)], startPoint: .top, endPoint: .bottom))
                .frame(height: 11)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.35)).frame(height: 1) }
        }
        .shadow(color: Color(hex: 0x6B4A2B).opacity(0.25), radius: 6, y: 5)
        .accessibilityHidden(true)
    }
}

/// One material on the shelf: its picture on a small card, its name below.
private struct ShelfItem: View {
    let play: Play
    let times: Int
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Figure(name: "tray_\(play.code.lowercased()).webp").aspectRatio(4 / 3, contentMode: .fit)
                    .background(alignment: .bottom) { Plank().frame(height: 18).padding(.horizontal, -10).offset(y: 6) }
                if times > 0 {
                    Text("×\(times)").font(Typeface.numerals(11, relativeTo: .caption, weight: .bold)).foregroundStyle(Color(hex: 0x4A3300))
                        .padding(.horizontal, 6).frame(height: 18)
                        .background(Capsule().fill(Palette.bead))
                        .padding(4)
                }
            }
            HStack(spacing: 4) {
                IconTile(symbol: Palette.areaSymbol(Palette.areaKey(of: play)), color: Palette.area(Palette.areaKey(of: play)), size: 16)
                Text(play.name).font(.footnote.weight(.semibold)).foregroundStyle(.primary).lineLimit(3, reservesSpace: false).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading).padding(.top, 10)
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
