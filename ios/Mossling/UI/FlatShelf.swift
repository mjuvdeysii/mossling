import SwiftUI

// MARK: 平面 — the week's shelf as it was in build 196 (the hidden 2D world; ShelfView hands over to it)

struct FlatShelfView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
    @Environment(\.dynamicTypeSize) private var size
    @Environment(JournalStore.self) private var j
    let month: Int
    let arrange: () -> Void
    var body: some View {
        let s = app.weekShelf(month)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("本周的架子").font(.title3.weight(.bold))
                Spacer()
                Button(action: arrange) {
                    // the words stay small; the place to tap is a full 44 points (HIG: hit targets)
                    Text(s.stale ? "换上新的一周" : "整理").padding(.horizontal, 8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .font(.subheadline.weight(.semibold)).padding(.vertical, -12).padding(.trailing, -8)
            }
            .padding(.horizontal, 4).padding(.top, 2)
            // a two-level shelf, two materials on each level: the week's plays are the largest pictures on the page
            VStack(spacing: 6) {
                // two on each level; at the largest text sizes one per level, so names wrap whole
                let per = size.isAccessibilitySize ? 1 : 2
                ForEach(0..<(Shelf.max + per - 1) / per, id: \.self) { row in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach((row * per)..<(row * per + per), id: \.self) { k in slot(k, s) }
                    }
                    .padding(.horizontal, 12).padding(.top, 12)
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

extension FlatShelfView {
    @ViewBuilder func slot(_ k: Int, _ s: (plays: [Play], stale: Bool)) -> some View {
        if k < s.plays.count {
            let p = s.plays[k], route = Route.play(p.code, month)
            NavigationLink(value: route) { FlatShelfItem(play: p, times: app.record(p, j).count) }
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
                        .background(alignment: .bottom) { FlatPlank().frame(height: 18).padding(.horizontal, -10).offset(y: 6) }
                    Text("放一件").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 30, alignment: .top).padding(.top, 10)
                }
            }
            .buttonStyle(.toy).accessibilityLabel("放一件教具")
        }
    }
}

/// A wooden plank seen a little from above: a lit top face, a darker front edge, a soft shadow beneath.
private struct FlatPlank: View {
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
private struct FlatShelfItem: View {
    let play: Play
    let times: Int
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Figure(name: "tray_\(play.code.lowercased()).webp").aspectRatio(4 / 3, contentMode: .fit)
                    .background(alignment: .bottom) { FlatPlank().frame(height: 18).padding(.horizontal, -10).offset(y: 6) }
                if times > 0 {
                    Ticking(text: "×\(times)").font(Typeface.numerals(11, relativeTo: .caption, weight: .bold)).foregroundStyle(Color(hex: 0x4A3300))
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

