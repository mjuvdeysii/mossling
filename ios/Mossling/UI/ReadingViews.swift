import SwiftUI

/// A topic page (sleep, safe sleep, feeding, teeth and screens, when to see a doctor).
struct TopicView: View {
    let topic: Topic
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !topic.sourceTitle.isEmpty { Text(topic.sourceTitle).font(.subheadline).foregroundStyle(Palette.secondaryText) }
                BlocksView(blocks: topic.blocks)
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .background(Palette.background)
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
                Section("活动") { ForEach(plays) { p in Button { path.append(Route.play(p.code, app.babyMonth.map { max(p.from, min(p.to, $0)) } ?? p.from)) } label: {
                    HStack { CodeTile(code: p.code, tint: app.companion.tint, size: 14); VStack(alignment: .leading) { Text(p.name); Text(p.age).font(.caption).foregroundStyle(Palette.secondaryText) } } } } }
            }
            if !months.isEmpty {
                Section("月份") { ForEach(months, id: \.month) { m in Button { path.append(Route.month(m.month)) } label: {
                    HStack(alignment: .firstTextBaseline) { Text("\(m.month)").font(Typeface.numerals(18)).frame(width: 30); Text(m.title) } } } }
            }
            if !topics.isEmpty {
                Section("专题") { ForEach(topics) { tp in Button(tp.title) { path.append(Route.topic(tp.id)) } } }
            }
            if !t.isEmpty && plays.isEmpty && months.isEmpty && topics.isEmpty {
                ContentUnavailableView.search(text: t)
            }
        }
        .tint(Palette.text)
        .searchable(text: $q, prompt: "活动、月份、专题")
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
                    HStack(spacing: 12) {
                        if let f = ArtIndex.shared.steps(p.code).first { ArtView(name: f, radius: 10).frame(width: 72) }
                        VStack(alignment: .leading, spacing: 2) { Text(p.name).font(.subheadline.weight(.semibold)); Text(p.code).font(Typeface.numerals(13)).foregroundStyle(Palette.secondaryText) }
                        Spacer()
                        Button { app.setShelf(codes.filter { $0 != p.code }) } label: { Image(systemName: "minus.circle.fill").foregroundStyle(Palette.danger) }.buttonStyle(.plain)
                            .accessibilityLabel("从架子上拿下")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { path.append(Route.play(p.code, m)) }
                }
                if current.stale {
                    Button("换上新的一周") { app.setShelf(Shelf.suggest(app.content, m, last: codes)) }
                }
            } header: { Text("本周的架子 · \(codes.count) / \(Shelf.max)") } footer: { Text("观察 · 准备 · 示范 · 重复 · 轮换。每周三到四件，孩子想重复就重复。") }
            Section("适合这个月") {
                ForEach(Shelf.candidates(app.content, m).filter { !codes.contains($0.code) }) { p in
                    HStack(spacing: 12) {
                        if let f = ArtIndex.shared.steps(p.code).first { ArtView(name: f, radius: 10).frame(width: 72) }
                        VStack(alignment: .leading, spacing: 2) { Text(p.name).font(.subheadline); Text(p.age).font(.caption).foregroundStyle(Palette.secondaryText) }
                        Spacer()
                        Button { app.setShelf(codes + [p.code]) } label: { Image(systemName: "plus.circle.fill").foregroundStyle(Palette.primary) }.buttonStyle(.plain)
                            .disabled(codes.count >= Shelf.max).accessibilityLabel("放上架子")
                    }
                }
            }
        }
        .navigationTitle("本周的架子")
    }
}
