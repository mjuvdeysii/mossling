import SwiftUI

/// A topic page (sleep, safe sleep, feeding, teeth and screens, when to see a doctor).
struct TopicView: View {
    let topic: Topic
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BlocksView(blocks: topic.blocks)
                if !topic.sourceTitle.isEmpty {
                    Label(topic.sourceTitle, systemImage: "books.vertical").font(.footnote).foregroundStyle(Palette.secondaryText).padding(.top, 8)
                }
                Text(HealthNote.text).font(.footnote).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 40)
        }
        .pageBackground()
        .navigationTitle(topic.title).navigationBarTitleDisplayMode(.large)
    }
}

/// Search across plays, months and topics.
struct SearchView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    @State private var q = ""
    var body: some View {
        let c = app.content
        let t = q.trimmingCharacters(in: .whitespaces)
        let plays = t.isEmpty ? [] : c.activities.filter { $0.name.contains(t) || $0.code.localizedCaseInsensitiveContains(t) || $0.steps.contains { $0.contains(t) } || $0.domains.contains { $0.contains(t) } }
        let months = t.isEmpty ? [] : c.months.filter { m in m.title.contains(t) || m.domains.contains { $0.text.contains(t) } || m.observe.contains { $0.items.contains { $0.contains(t) } } || m.notes.contains { $0.text.contains(t) } }
        let topics = t.isEmpty ? [] : c.topics.filter { $0.title.contains(t) || $0.blocks.contains { ($0.text ?? "").contains(t) || ($0.items ?? []).contains { $0.contains(t) } } }
        List {
            if !plays.isEmpty {
                Section("活动") { ForEach(plays) { p in NavigationLink(value: Route.play(p.code, app.babyMonth.map { max(p.from, min(p.to, $0)) } ?? p.from)) {
                    PlayRowLabel(play: p) } } }
            }
            if !months.isEmpty {
                Section("月份") { ForEach(months, id: \.month) { m in NavigationLink(value: Route.month(m.month)) {
                    Label { VStack(alignment: .leading, spacing: 2) { Text(m.month == 0 ? "出生" : "满 \(m.month) 个月"); Text(m.title).font(.subheadline).foregroundStyle(Palette.secondaryText) } } icon: { Bead(month: m.month, here: false, past: true).scaleEffect(0.9) } } } }
            }
            if !topics.isEmpty {
                Section("专题") { ForEach(topics) { tp in NavigationLink(value: Route.topic(tp.id)) { topicLabel(tp) } } }
            }
            // before typing: what is on the shelf this week and the topics, so the page opens on something to read
            if t.isEmpty {
                let m = app.babyMonth ?? 0
                Section("这周一起玩") { ForEach(app.weekShelf(m).plays) { p in NavigationLink(value: Route.play(p.code, m)) { PlayRowLabel(play: p) } } }
                Section("专题") { ForEach(c.topics) { tp in NavigationLink(value: Route.topic(tp.id)) { topicLabel(tp) } } }
            }
            if !t.isEmpty && plays.isEmpty && months.isEmpty && topics.isEmpty {
                // nothing found: the companion looks this way and that for it
                VStack(spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 1.3)) { tl in
                        let side: Double = Int(tl.date.timeIntervalSinceReferenceDate / 1.3) % 2 == 0 ? -0.9 : 0.9
                        Creature(kind: app.companion, look: CGPoint(x: side, y: 0.1), alive: true, lookSeconds: 0.5)
                            .frame(width: 64 * app.companion.scale, height: 64 * app.companion.scale)
                    }
                    .frame(height: 72).accessibilityHidden(true)
                    Text("没有找到「\(t)」").font(.headline)
                    Text("试试活动的名字、月份或专题").font(.subheadline).foregroundStyle(Palette.secondaryText)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "活动、月份、专题")
        .navigationTitle("搜索")
    }
    /// A topic with its own mark, as on the month's page.
    private func topicLabel(_ tp: Topic) -> some View {
        let i = app.content.topics.firstIndex { $0.id == tp.id } ?? 0
        return Label { Text(tp.title) } icon: { IconTile(symbol: topicMarks[i % topicMarks.count].0, color: topicMarks[i % topicMarks.count].1) }
    }
}

/// 这周一起玩: the three or four plays of the week, chosen for this month, turned by themselves when the week turns.
/// Here the parent changes them: takes one off, adds one this month suits, puts back one played last week, or asks
/// for a new week.
struct PlanView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Binding var path: NavigationPath
    var body: some View {
        let m = app.babyMonth ?? 0
        let current = app.weekShelf(m)
        let codes = current.plays.map(\.code)
        let full = codes.count >= Shelf.max
        // played last week (from the records) and not in this week: one tap puts it back
        let monday = app.today.monday.date, before = app.today.monday.plus(days: -7).date
        let lastWeek = app.content.activities.filter { p in !codes.contains(p.code) && j.plays(p.code).contains { $0.startDate >= before && $0.startDate < monday } }
        let more = Shelf.candidates(app.content, m).filter { p in !codes.contains(p.code) && !lastWeek.contains(p) }
        List {
            Section {
                // changing the week is taking off and adding: each row says which, with its own button (no swipe to
                // find, no page pushed inside the sheet)
                ForEach(current.plays) { p in
                    HStack {
                        playLabel(p)
                        Spacer()
                        Button { withAnimation(.snappy) { app.setShelf(codes.filter { $0 != p.code }) } } label: {
                            Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(Palette.danger.opacity(0.85))
                        }
                        .buttonStyle(.plain).accessibilityLabel("从这周拿掉")
                    }
                }
                Button("重新推荐", systemImage: "arrow.triangle.2.circlepath") {
                    withAnimation(.snappy) { app.setShelf(Shelf.suggest(app.content, m, last: codes, played: { c in app.content.play(c).map { app.record($0, j).count } ?? 0 })) }
                }
            } header: { Text("这周 · \(codes.count) / \(Shelf.max) 个") } footer: { Text("观察、准备、示范、重复、轮换。每周三四个，孩子想重复就重复。") }
            if !lastWeek.isEmpty {
                Section("上周玩过") { ForEach(lastWeek) { p in addRow(p, codes: codes, full: full) } }
            }
            Section("这个月还可以玩 · \(more.count) 个") { ForEach(more) { p in addRow(p, codes: codes, full: full) } }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("这周一起玩")
    }
    private func addRow(_ p: Play, codes: [String], full: Bool) -> some View {
        HStack {
            playLabel(p)
            Spacer()
            Button { withAnimation(.snappy) { app.setShelf(codes + [p.code]) } } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Palette.accent) }.buttonStyle(.plain)
                .disabled(full).opacity(full ? 0.3 : 1).accessibilityLabel("加到这周")
        }
    }
    private func playLabel(_ p: Play) -> some View { PlayRowLabel(play: p) }
}

/// A play in a list: its own tray on its area's tile (as on the home page), the name and the age range.
struct PlayRowLabel: View {
    let play: Play
    @ScaledMetric(relativeTo: .body) private var w: CGFloat = 60
    var body: some View {
        HStack(spacing: 12) {
            TrayTile(code: play.code, color: Palette.area(Palette.areaKey(of: play)), flat: ArtStyle.current == .flat)
                .frame(width: min(w, 84), height: min(w, 84) * 0.75)
            VStack(alignment: .leading, spacing: 2) {
                Text(play.name)
                Text(play.age).font(.subheadline).foregroundStyle(Palette.secondaryText)
            }
        }
    }
}

/// Under health guidance (还要知道, 专题): what it is and what it is not.
enum HealthNote {
    static let text = "以上为公开指南的摘要，不针对具体的孩子。药品和补充剂的品种、剂量请遵医嘱或药品说明书；孩子身体不适时，以医生的判断为准。"
}
