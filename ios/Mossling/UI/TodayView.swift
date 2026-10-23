import SwiftUI

/// The home: the child's months as a growth map — the stage and wheel at the top, set to this month — and under it
/// the chosen month: this week's shelf (this month only), the plays, the month's parts in small tiles, and the topics.
/// Most of the page is the plays, the heart of the book.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Binding var path: NavigationPath
    @State private var askBirth = false
    @State private var arranging = false
    @State private var chosen: Int?

    var body: some View {
        let baby = app.babyMonth ?? 0
        let m = chosen ?? baby
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if app.age == nil {
                    Button { askBirth = true } label: { Label("填写出生日期，从宝宝这个月开始", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.glassProminent).controlSize(.large)
                }
                GrowthWheel(month: Binding(get: { m }, set: { chosen = $0 == baby ? nil : $0 }), baby: baby)
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

/// The month's plays as picture cards, two by two; this month's shelf is shown above, so its plays are not repeated.
private struct PlaysGrid: View {
    @Environment(AppModel.self) private var app
    let month: Int
    let hideShelf: Bool
    var body: some View {
        let shelf = hideShelf ? app.weekShelf(month).plays.map(\.code) : []
        let plays = app.content.plays(of: month).filter { !shelf.contains($0.code) }
        if !plays.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: hideShelf ? "这个月还能玩" : "这个月的教具", detail: "\(plays.count) 个")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(plays) { p in PlayTileLink(play: p, month: month) }
                }
            }
        }
    }
}

/// The topics, as tiles.
private struct Topics: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let t = app.content.topics
        let marks: [(String, Color)] = [("moon.zzz.fill", Crayon.lilac), ("bed.double.fill", Crayon.sky), ("fork.knife", Crayon.leaf), ("mouth.fill", Crayon.pink), ("cross.case.fill", Crayon.cherry)]
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "专题")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(t.enumerated()), id: \.offset) { i, x in
                    let mk = marks[i % marks.count]
                    NavigationLink(value: Route.topic(x.id)) {
                        HStack(spacing: 10) {
                            IconTile(symbol: mk.0, color: mk.1, size: 34)
                            Text(x.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(12).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .printCard(radius: 20)
                    }
                    .buttonStyle(.toy)
                }
            }
        }
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
                Plank().frame(height: 22).padding(.horizontal, 6)
            }
            .padding(.bottom, 12)
            .background(alignment: .bottom) {
                // a frosted back panel behind the shelf, like a glass cabinet
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Crayon.peach.opacity(0.18), Crayon.pink.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 22)
            }
            .printCard(radius: 26)
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
