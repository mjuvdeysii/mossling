import SwiftUI
import LocalAuthentication

enum Route: Hashable {
    case play(String, Int), month(Int), plan, map, topic(String), search, about, sources, licenses, doc(String)
}

@main
struct MosslingApp: App {
    @State private var app = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(app.theme.scheme)
                .tint(Palette.primary)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var phase
    @State private var tab = 0
    @State private var todayPath = NavigationPath()
    @State private var growPath = NavigationPath()
    @State private var youPath = NavigationPath()
    @State private var locked = true

    var body: some View {
        ZStack {
            if !app.onboarded {
                OnboardingView()
            } else {
                TabView(selection: $tab) {
                    NavigationStack(path: $todayPath) { TodayView(path: $todayPath).routes(path: $todayPath) }
                        .tabItem { Label("今天", systemImage: "sun.max") }.tag(0)
                    NavigationStack(path: $growPath) { GrowView(path: $growPath).routes(path: $growPath) }
                        .tabItem { Label("成长", systemImage: "leaf") }.tag(1)
                    NavigationStack(path: $youPath) { YouView(path: $youPath).routes(path: $youPath) }
                        .tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(3)
                }
            }
            if app.lock && locked { LockView { unlock() } }
        }
        .onChange(of: phase) { _, p in
            if p == .active { app.today = .today }
            if p == .background { locked = true }
        }
        .task { if app.lock { unlock() } }
    }

    private func unlock() {
        let ctx = LAContext()
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "确认是你本人") { ok, _ in
            DispatchQueue.main.async { if ok { locked = false } }
        }
    }
}

private struct LockView: View {
    @Environment(AppModel.self) private var app
    let unlock: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Duo(primary: app.companion, size: 110, mood: .sleep, poke: false)
            Text("芽芽月历已锁定").font(Typeface.serif(22))
            Button("解锁", action: unlock).buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

extension View {
    /// Every page that can be opened from a tab.
    func routes(path: Binding<NavigationPath>) -> some View {
        navigationDestination(for: Route.self) { r in RouteView(route: r, path: path) }
    }
}

private struct RouteView: View {
    @Environment(AppModel.self) private var app
    let route: Route
    @Binding var path: NavigationPath
    var body: some View {
        switch route {
        case let .play(code, m): if let p = app.content.play(code) { PlayView(play: p, month: m) }
        case let .month(m):
            ScrollView { MonthContent(month: m, path: $path) }.background(Palette.background)
                .navigationTitle("满 \(m) 个月").navigationBarTitleDisplayMode(.inline)
        case .plan: PlanView(path: $path)
        case .map: MapView(path: $path)
        case let .topic(id): if let t = app.content.topics.first(where: { $0.id == id }) { TopicView(topic: t) }
        case .search: SearchView(path: $path)
        case .about: AboutView()
        case .sources: SourcesView()
        case .licenses: LicensesView()
        case let .doc(n): DocView(name: n)
        }
    }
}

/// First run: the two of them, the name, one question. Everything can be skipped.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var askBirth = false
    @State private var doc: String?
    @State private var rise = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            HStack(alignment: .bottom, spacing: -18) {
                Creature(kind: .moss, look: CGPoint(x: 0.9, y: -0.1), poke: true).frame(width: 170, height: 170).offset(y: rise ? 0 : 40)
                Creature(kind: .otto, look: CGPoint(x: -0.9, y: 0), poke: true).frame(width: 150, height: 150).offset(y: rise ? 0 : 60)
            }
            .opacity(rise ? 1 : 0)
            .frame(maxWidth: .infinity)
            Spacer().frame(height: 28)
            Text("芽芽月历").font(Typeface.serif(44, relativeTo: .largeTitle)).foregroundStyle(Palette.primary)
            Text("Mossling").font(Typeface.numerals(22)).foregroundStyle(Palette.secondaryText)
            Text("跟着孩子，一个月一站。").font(.body).padding(.top, 12)
            Text("0–3 岁早教活动规划").font(.subheadline).foregroundStyle(Palette.secondaryText).padding(.top, 4)
            Spacer()
            Button { askBirth = true } label: { Text("填写宝宝的出生日期").frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.borderedProminent).controlSize(.large)
            Button { app.onboarded = true } label: { Text("先看看").frame(maxWidth: .infinity).padding(.vertical, 8) }
            Text("继续使用即表示已阅读并同意以下文件。本应用提供家庭养育参考，不能替代医生的诊断和建议。")
                .font(.caption).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 8)
            HStack {
                ForEach([("使用条款", "TERMS"), ("隐私政策", "PRIVACY"), ("免责声明", "DISCLAIMER")], id: \.1) { t, f in
                    Button("《\(t)》") { doc = f }.font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Palette.background)
        .onAppear { withAnimation(.spring(duration: 0.9)) { rise = true } }
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .sheet(item: Binding(get: { doc.map { DocName(id: $0) } }, set: { doc = $0?.id })) { d in
            NavigationStack { DocView(name: d.id).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { doc = nil } } } }
        }
    }
}

private struct DocName: Identifiable { let id: String }
