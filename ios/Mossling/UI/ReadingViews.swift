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
                Section("专题") { ForEach(topics) { tp in NavigationLink(value: Route.topic(tp.id)) { Label { Text(tp.title) } icon: { IconTile(symbol: "book.pages.fill", color: Crayon.caramel) } } } }
            }
            // before typing: what is on the shelf this week and the topics, so the page opens on something to read
            if t.isEmpty {
                let m = app.babyMonth ?? 0
                Section("本周的架子") { ForEach(app.weekShelf(m).plays) { p in NavigationLink(value: Route.play(p.code, m)) { PlayRowLabel(play: p) } } }
                Section("专题") { ForEach(c.topics) { tp in NavigationLink(value: Route.topic(tp.id)) { Label { Text(tp.title) } icon: { IconTile(symbol: "book.pages.fill", color: Crayon.caramel) } } } }
            }
            if !t.isEmpty && plays.isEmpty && months.isEmpty && topics.isEmpty {
                ContentUnavailableView.search(text: t)
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: "活动、月份、专题")
        .navigationTitle("搜索")
    }
}

/// This week's shelf: three or four plays for the whole week, chosen for this month, rotated when the week turns.
struct PlanView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    var body: some View {
        let m = app.babyMonth ?? 0
        let current = app.weekShelf(m)
        let codes = current.plays.map(\.code)
        List {
            Section {
                ForEach(current.plays) { p in
                    NavigationLink(value: Route.play(p.code, m)) { playLabel(p) }
                        .swipeActions { Button("拿下", systemImage: "minus.circle", role: .destructive) { app.setShelf(codes.filter { $0 != p.code }) } }
                }
                if current.stale {
                    Button("换上新的一周", systemImage: "arrow.triangle.2.circlepath") { app.setShelf(Shelf.suggest(app.content, m, last: codes)) }
                }
            } header: { Text("本周 · \(codes.count) / \(Shelf.max) 件") } footer: { Text("观察、准备、示范、重复、轮换。每周三到四件，孩子想重复就重复。") }
            Section("适合这个月") {
                ForEach(Shelf.candidates(app.content, m).filter { !codes.contains($0.code) }) { p in
                    HStack {
                        playLabel(p)
                        Spacer()
                        Button { app.setShelf(codes + [p.code]) } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Palette.accent) }.buttonStyle(.plain)
                            .disabled(codes.count >= Shelf.max).opacity(codes.count >= Shelf.max ? 0.3 : 1).accessibilityLabel("放上架子")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("本周的架子")
    }
    private func playLabel(_ p: Play) -> some View { PlayRowLabel(play: p) }
}

/// A play in a list: its own tray on its area's tile (as on the home shelf), the name and the age range.
struct PlayRowLabel: View {
    let play: Play
    @ScaledMetric(relativeTo: .body) private var w: CGFloat = 52
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
