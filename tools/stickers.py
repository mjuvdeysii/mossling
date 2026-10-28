"""The app's icons, drawn: every category mark is a small picture on a die-cut sticker — a blob of its colour with a
white edge, the object drawn in the picture book's style (tools/picturebook.py) — instead of a symbol (ios/DESIGN.md §3).

Each sticker is named after the SF Symbol it replaces (ic_<symbol with dots as underscores>.webp), so the app swaps
the drawing in wherever one exists (IconTile). Output: ios/Art/art/ic_*.webp with transparency, and their sizes in
index.json.

Usage: python3 tools/stickers.py [--sheet out.png]
"""
import io, json, math, os, sys
import cairosvg
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import picturebook as pb

OUT = pb.OUT
S = 240
TEAL, PINK, YELLOW, RED, BLUE, ORANGE = "#1FB5A6", "#FF6F91", "#FFC23D", "#F2554B", "#4C9BE8", "#FF8A3D"
LILAC, MINT, GREEN, CARAMEL, GREY, PEACH = "#9B7BEA", "#3CC9A0", "#4DB86A", "#D9964F", "#9A9289", "#FF9E7A"
INK = pb.INK

def tint(c, t): return pb._tint(c, t)

def sticker(colour, draw, wobble=0):
    """The die-cut sticker: a soft shadow, a white edge, a blob of `colour`, then the drawing."""
    sv = pb.SVG(S, S)
    blob = "M120 22 C178 20 220 56 219 118 C218 180 180 219 120 218 C58 219 21 182 22 120 C23 58 62 24 120 22Z"
    sv.add(f'<g transform="rotate({wobble} 120 120)">')
    sv.add(f'<path d="{blob}" fill="#5A3A20" opacity=".18" transform="translate(0 7)"/>')
    # a fine warm contour just outside the white edge, so the sticker holds on a white card
    sv.add(f'<path d="{blob}" fill="none" stroke="#7A5230" stroke-opacity=".28" stroke-width="20" stroke-linejoin="round"/>')
    sv.add(f'<path d="{blob}" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="16" stroke-linejoin="round"/>')
    sv.add(f'<path d="{blob}" fill="{tint(colour, .72)}"/>')
    sv.add('</g>')
    draw(sv)
    if pb.FLAT and pb.JELLY > 0:
        # strong jelly: the whole sticker glazed like a candy — a broad gloss across the upper left, a bright
        # crescent along the top edge, light glowing back up from the lower edge
        k = min(1.0, pb.JELLY / 1.8)
        g = sv.id(); sv.defs.append(f'<radialGradient id="{g}" cx=".32" cy=".24" r=".55"><stop offset="0" stop-color="#FFFFFF" stop-opacity="{.55 * k:.2f}"/>'
                                   f'<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>')
        cl = sv.id(); sv.defs.append(f'<clipPath id="{cl}"><path d="{blob}" transform="rotate({wobble} 120 120)"/></clipPath>')
        sv.add(f'<g clip-path="url(#{cl})"><rect width="{S}" height="{S}" fill="url(#{g})"/>'
               f'<path d="M50 62 C80 34 160 30 192 64" fill="none" stroke="#FFFFFF" stroke-opacity="{.6 * k:.2f}" stroke-width="9" stroke-linecap="round"/>'
               f'<path d="M58 196 C95 214 150 214 186 194" fill="none" stroke="#FFFFFF" stroke-opacity="{.32 * k:.2f}" stroke-width="7" stroke-linecap="round"/></g>')
    return sv

def G(sv, c): return sv.lin(c, 120)
def R(sv, c): return sv.rad(c)
def eyes(x, y, d=10, r=4):
    return f'<circle cx="{x - d}" cy="{y}" r="{r}" fill="{INK}"/><circle cx="{x + d}" cy="{y}" r="{r}" fill="{INK}"/>' \
           f'<circle cx="{x - d - 1.2}" cy="{y - 1.4}" r="{r * .35}" fill="#FFF"/><circle cx="{x + d - 1.2}" cy="{y - 1.4}" r="{r * .35}" fill="#FFF"/>'
def smile(x, y, w=10): return f'<path d="M{x - w} {y} q{w} {w * .8} {w * 2} 0" stroke="{INK}" stroke-width="4" fill="none" stroke-linecap="round"/>'
def cheek(x, y): return f'<ellipse cx="{x}" cy="{y}" rx="7" ry="4.5" fill="{PINK}" opacity=".55"/>'

D = {}
def icon(key, colour, wobble=0):
    def deco(fn): D[key] = (colour, fn, wobble); return fn
    return deco

# ---------- the six areas (Montessori materials) ----------
@icon("bubble_left_and_bubble_right_fill", TEAL)          # 语言: an open picture book and a word coming out of it
def _(sv):
    pb.obj(sv, "bookopen", 120, 176, 1.25, "#0B7D74")
    sv.add(f'<path d="M150 58 h46 a14 14 0 0 1 14 14 v20 a14 14 0 0 1 -14 14 h-24 l-12 12 v-12 h-10 a14 14 0 0 1 -14 -14 v-20 a14 14 0 0 1 14 -14z" fill="#FFF"/>')
    sv.add("".join(f'<circle cx="{160 + i * 13}" cy="82" r="4.5" fill="{TEAL}"/>' for i in range(3)))
@icon("figure_walk", ORANGE)                              # 大运动: a soft ball rolling, with motion
def _(sv):
    pb.obj(sv, "ball", 128, 182, 1.7, ORANGE)
    for i, y in enumerate((112, 136, 160)): sv.add(f'<path d="M{44 + i * 6} {y} h{30 - i * 6}" stroke="#FFF" stroke-width="7" stroke-linecap="round"/>')
@icon("hand_raised_fingers_spread_fill", YELLOW)          # 精细与认知: the pink tower, stacked
def _(sv):
    y = 190
    for i, (w, c) in enumerate([(120, PINK), (96, "#FF8FAA"), (74, PINK), (52, "#FF8FAA"), (32, PINK)]):
        h = 24 - i * 2
        sv.add(f'<rect x="{120 - w / 2}" y="{y - h}" width="{w}" height="{h}" rx="5" fill="{G(sv, c)}"/>'); y -= h + 2
@icon("face_smiling_inverse", PINK)                       # 社会情绪: two faces close, a heart between
def _(sv):
    sv.add(f'<circle cx="92" cy="132" r="42" fill="{R(sv, pb.SKIN[0])}"/><circle cx="156" cy="146" r="32" fill="{R(sv, pb.SKIN[1])}"/>')
    sv.add(f'<path d="M52 122 a40 40 0 0 1 78 -12 q-30 -16 -78 12z" fill="#4A3428"/>')
    sv.add(eyes(100, 128, 12, 4.5) + smile(100, 146, 9) + cheek(78, 146))
    sv.add(eyes(150, 144, 9, 3.6) + smile(150, 158, 7) + cheek(170, 158))
    sv.add(pb.pict("heart", 128, 72, 1.5))
@icon("house_fill", BLUE)                                 # 生活与文化: a small jug pouring into a cup (practical life)
def _(sv):
    sv.add(f'<g transform="rotate(-28 100 110)"><path d="M70 84 h56 l-6 70 a10 10 0 0 1 -10 9 h-24 a10 10 0 0 1 -10 -9z" fill="{G(sv, BLUE)}"/>'
           f'<path d="M126 96 q24 4 14 34" stroke="{BLUE}" stroke-width="9" fill="none" stroke-linecap="round"/><path d="M70 84 l-12 -8 l14 -2z" fill="{BLUE}"/></g>')
    sv.add(f'<path d="M140 148 q4 14 -2 22" stroke="#7DB8F2" stroke-width="7" fill="none" stroke-linecap="round"/>')
    pb.obj(sv, "cup", 150, 196, 1.15, TEAL)
@icon("cross_case_fill", RED)                             # 照护与安全 / 什么时候要找医生: a doctor's bag with a heart
def _(sv):
    sv.add(f'<path d="M96 76 v-12 a10 10 0 0 1 10 -10 h28 a10 10 0 0 1 10 10 v12" stroke="#B8302A" stroke-width="9" fill="none"/>')
    sv.add(f'<rect x="52" y="74" width="136" height="104" rx="22" fill="{G(sv, RED)}"/>')
    sv.add(f'<rect x="108" y="98" width="24" height="58" rx="6" fill="#FFF"/><rect x="91" y="115" width="58" height="24" rx="6" fill="#FFF"/>')

# ---------- the month's parts ----------
@icon("circle_hexagongrid_fill", TEAL)                    # 六个方面: six beads round a seventh
def _(sv):
    cols = [TEAL, ORANGE, YELLOW, PINK, BLUE, RED]
    for i, c in enumerate(cols):
        a = math.radians(i * 60 - 90); x, y = 120 + math.cos(a) * 52, 122 + math.sin(a) * 52
        sv.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="24" fill="{R(sv, c)}"/>')
    sv.add(f'<circle cx="120" cy="122" r="22" fill="{R(sv, "#D4A21C")}"/>')
@icon("eye_fill", BLUE)                                   # 可以留意: a magnifying glass over a sprout
def _(sv):
    sv.add(f'<path d="M110 186 v-40" stroke="{GREEN}" stroke-width="8" stroke-linecap="round"/><path d="M110 156 q-30 -2 -34 -28 q28 -2 34 28z" fill="{GREEN}"/><path d="M110 146 q26 -6 34 -32 q-30 0 -34 32z" fill="#7FD49A"/>')
    sv.add(f'<path d="M150 150 l34 36" stroke="#8A5A2B" stroke-width="16" stroke-linecap="round"/>')
    sv.add(f'<circle cx="124" cy="120" r="42" fill="#DCEFF6" fill-opacity=".55" stroke="{G(sv, YELLOW)}" stroke-width="12"/><path d="M98 106 a30 30 0 0 1 20 -16" stroke="#FFF" stroke-width="7" fill="none" stroke-linecap="round"/>')
@icon("syringe_fill", PINK)                               # 接种与儿保: the health booklet with a star sticker
def _(sv):
    sv.add(f'<rect x="62" y="52" width="116" height="140" rx="14" fill="{G(sv, PINK)}"/><rect x="62" y="52" width="22" height="140" rx="10" fill="#C7365C"/>')
    sv.add(f'<rect x="98" y="78" width="62" height="40" rx="8" fill="#FFF"/><circle cx="118" cy="98" r="10" fill="{pb.SKIN[1]}"/><path d="M134 92 h18 M134 104 h12" stroke="#E6D3B8" stroke-width="5" stroke-linecap="round"/>')
    star = " ".join(f"{150 + math.cos(math.radians(-90 + i * 36)) * (18 if i % 2 == 0 else 8):.1f},{158 + math.sin(math.radians(-90 + i * 36)) * (18 if i % 2 == 0 else 8):.1f}" for i in range(10))
    sv.add(f'<polygon points="{star}" fill="{YELLOW}" stroke="#FFF" stroke-width="4" stroke-linejoin="round"/>')
@icon("lightbulb_fill", YELLOW)                           # 还要知道: a warm light bulb, glowing
def _(sv):
    for i in range(7):
        a = math.radians(-180 + i * 30); sv.add(f'<path d="M{120 + math.cos(a) * 66:.1f} {104 + math.sin(a) * 66:.1f} L{120 + math.cos(a) * 82:.1f} {104 + math.sin(a) * 82:.1f}" stroke="#FFF" stroke-width="7" stroke-linecap="round"/>')
    sv.add(f'<circle cx="120" cy="104" r="46" fill="{R(sv, YELLOW)}"/><rect x="98" y="146" width="44" height="34" rx="8" fill="{G(sv, "#9A9289")}"/><path d="M98 158 h44 M98 168 h44" stroke="#7A736B" stroke-width="3"/>')
    sv.add(eyes(120, 100, 12, 4.5) + smile(120, 116, 8))
@icon("sun_and_horizon_fill", ORANGE)                     # 一天的节奏: half sun, half moon
def _(sv):
    sv.add(f'<path d="M120 52 a68 68 0 0 0 0 136z" fill="{R(sv, YELLOW)}"/><path d="M120 52 a68 68 0 0 1 0 136z" fill="{R(sv, "#3E5A86")}"/>')
    sv.add(f'<path d="M150 92 a26 26 0 1 0 16 46 a20 20 0 1 1 -16 -46z" fill="#FFE9A8"/><circle cx="176" cy="84" r="4" fill="#FFF"/><circle cx="160" cy="160" r="3" fill="#FFF"/>')
    sv.add(eyes(96, 116, 10, 4) + smile(96, 132, 8))
@icon("chart_line_uptrend_xyaxis", ORANGE)                # 生长曲线: a growth ruler with a sprout climbing it
def _(sv):
    sv.add(f'<rect x="78" y="44" width="40" height="152" rx="8" fill="{G(sv, YELLOW)}"/>' + "".join(f'<path d="M78 {60 + i * 16} h{14 if i % 2 else 22}" stroke="#8A5A00" stroke-width="4" stroke-linecap="round"/>' for i in range(9)))
    sv.add(f'<path d="M150 196 v-104" stroke="{GREEN}" stroke-width="9" stroke-linecap="round"/><path d="M150 124 q-30 -4 -32 -30 q28 2 32 30z" fill="{GREEN}"/><path d="M150 98 q26 -6 32 -34 q-28 2 -32 34z" fill="#7FD49A"/>')
    sv.add(f'<path d="M150 92 l-6 -10 h12z" fill="{RED}"/>')

# ---------- topics ----------
@icon("moon_zzz_fill", LILAC)                             # 睡眠: a sleepy crescent moon and stars
def _(sv):
    sv.add(f'<path d="M134 46 a72 72 0 1 0 58 112 a58 58 0 1 1 -58 -112z" fill="{R(sv, YELLOW)}"/>')
    sv.add(f'<path d="M86 124 q8 6 16 0 M118 126 q8 6 16 0" stroke="{INK}" stroke-width="4" fill="none" stroke-linecap="round"/>' + cheek(84, 140))
    for x, y, r in ((176, 70, 9), (196, 104, 6), (160, 44, 5)):
        sv.add(f'<path d="M{x} {y - r * 1.8} Q{x} {y} {x + r * 1.8} {y} Q{x} {y} {x} {y + r * 1.8} Q{x} {y} {x - r * 1.8} {y} Q{x} {y} {x} {y - r * 1.8}Z" fill="#FFF"/>')
@icon("bed_double_fill", BLUE)                            # 安全睡眠: a crib, empty but for the baby, on its back
def _(sv):
    sv.add(f'<rect x="46" y="80" width="148" height="100" rx="14" fill="none" stroke="{G(sv, "#D9964F")}" stroke-width="12"/>')
    sv.add("".join(f'<rect x="{68 + i * 22}" y="86" width="8" height="88" rx="4" fill="#E8AD6E"/>' for i in range(6)))
    sv.add(f'<rect x="60" y="150" width="120" height="22" rx="10" fill="{G(sv, "#BFE3F0")}"/><circle cx="92" cy="146" r="16" fill="{R(sv, pb.SKIN[1])}"/>'
           f'<rect x="104" y="136" width="64" height="22" rx="11" fill="{G(sv, TEAL)}"/><path d="M85 144 q4 4 8 0 M97 144 q4 4 8 0" stroke="{INK}" stroke-width="3" fill="none"/>')
@icon("fork_knife", GREEN)                                # 辅食 / 喂养: a bowl of food and a spoon
def _(sv):
    pb.obj(sv, "bowl", 116, 184, 2.3, TEAL)
    sv.add(f'<g transform="rotate(30 170 100)"><rect x="166" y="66" width="10" height="74" rx="5" fill="#B9B2A8"/><ellipse cx="171" cy="58" rx="16" ry="22" fill="#D7D1C8"/></g>')
@icon("mouth_fill", TEAL)                                 # 口腔 · 屏幕 · 多种语言: a toothbrush and a smiling tooth
def _(sv):
    sv.add(f'<path d="M84 64 c-20 0 -30 20 -26 44 c4 26 8 60 22 60 c12 0 12 -30 24 -30 c12 0 12 30 24 30 c14 0 18 -34 22 -60 c4 -24 -6 -44 -26 -44 c-12 0 -14 8 -20 8 c-6 0 -8 -8 -20 -8z" fill="#FFF"/>')
    sv.add(eyes(104, 104, 12, 4.5) + smile(104, 122, 8) + cheek(80, 122))
    sv.add(f'<g transform="rotate(-40 172 150)"><rect x="166" y="100" width="12" height="96" rx="6" fill="{G(sv, PINK)}"/><rect x="164" y="92" width="16" height="22" rx="4" fill="#BFE3F0"/></g>')
@icon("book_pages_fill", TEAL)                            # 专题: a closed book with a bookmark
def _(sv):
    sv.add(f'<rect x="60" y="54" width="120" height="136" rx="14" fill="{G(sv, TEAL)}"/><rect x="68" y="176" width="108" height="10" rx="4" fill="#FFF"/>')
    sv.add(f'<path d="M150 54 v44 l-10 -8 l-10 8 v-44z" fill="{RED}"/><circle cx="110" cy="112" r="18" fill="#FFF" opacity=".85"/>')

# ---------- kinds of record ----------
@icon("heart_fill", PINK)                                 # 亲喂: a rose heart with a drop of milk (never a red drop)
def _(sv):
    sv.add(pb.pict("heart", 120, 120, 4.2))
    sv.add(f'<path d="M150 70 q14 18 0 28 q-14 -10 0 -28z" fill="#FFF"/>')
@icon("waterbottle_fill", PEACH)                          # 瓶喂: a baby bottle
def _(sv):
    sv.add(f'<path d="M104 54 q16 -22 32 0 v10 h-32z" fill="#FFC9A8"/><rect x="96" y="62" width="48" height="18" rx="6" fill="{TEAL}"/>')
    sv.add(f'<rect x="88" y="78" width="64" height="116" rx="22" fill="#FFFFFF" stroke="#F1E6D8" stroke-width="3"/><rect x="92" y="122" width="56" height="68" rx="18" fill="#FFF3E0"/>')
    sv.add("".join(f'<path d="M136 {100 + i * 20} h-12" stroke="{ORANGE}" stroke-width="4" stroke-linecap="round"/>' for i in range(4)))
@icon("circle_bottomhalf_filled", BLUE)                   # 尿布: a nappy
def _(sv):
    sv.add(f'<path d="M50 80 h140 v20 c-10 0 -24 10 -30 40 c-6 34 -20 50 -40 50 c-20 0 -34 -16 -40 -50 c-6 -30 -20 -40 -30 -40z" fill="#FFF" stroke="#E2EEF8" stroke-width="3"/>')
    sv.add(f'<rect x="50" y="80" width="140" height="18" rx="6" fill="{G(sv, BLUE)}"/><circle cx="70" cy="89" r="5" fill="#FFF"/><circle cx="170" cy="89" r="5" fill="#FFF"/>')
    sv.add(eyes(120, 132, 10, 3.6) + smile(120, 146, 7))
@icon("bathtub_fill", TEAL)                               # 洗澡: a tub with bubbles and a duck
def _(sv):
    for x, y, r in ((80, 92, 14), (104, 80, 18), (132, 88, 12), (156, 76, 16)): sv.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFF" opacity=".9"/>')
    sv.add(f'<path d="M50 112 h140 v18 c0 28 -20 50 -48 50 h-44 c-28 0 -48 -22 -48 -50z" fill="{G(sv, TEAL)}"/><rect x="44" y="104" width="152" height="14" rx="7" fill="#FFF"/>')
    sv.add(f'<path d="M64 196 v-14 M176 196 v-14" stroke="#0B7D74" stroke-width="8" stroke-linecap="round"/>')
    sv.add(f'<ellipse cx="160" cy="104" rx="22" ry="14" fill="{YELLOW}"/><circle cx="172" cy="88" r="12" fill="{YELLOW}"/><path d="M182 88 l12 3 l-12 4z" fill="{ORANGE}"/><circle cx="175" cy="85" r="2.5" fill="{INK}"/>')
@icon("thermometer_medium", RED)                          # 体温: a thermometer
def _(sv):
    sv.add(f'<rect x="104" y="44" width="32" height="120" rx="16" fill="#FFF" stroke="#F1E6D8" stroke-width="3"/><circle cx="120" cy="170" r="28" fill="{R(sv, RED)}"/>')
    sv.add(f'<rect x="113" y="92" width="14" height="80" rx="7" fill="{RED}"/>' + "".join(f'<path d="M136 {64 + i * 14} h-10" stroke="#C9C1B6" stroke-width="3" stroke-linecap="round"/>' for i in range(5)))
@icon("pills_fill", YELLOW)                               # 用药: a medicine dropper and its bottle
def _(sv):
    sv.add(f'<rect x="58" y="96" width="70" height="92" rx="16" fill="{G(sv, ORANGE)}"/><rect x="66" y="128" width="54" height="34" rx="6" fill="#FFF"/><rect x="72" y="80" width="42" height="20" rx="6" fill="#FFF"/>')
    sv.add(f'<g transform="rotate(24 160 120)"><rect x="152" y="60" width="18" height="82" rx="8" fill="#FFF" stroke="#F1E6D8" stroke-width="3"/><path d="M152 142 l9 26 l9 -26z" fill="#DCEFF6"/><rect x="148" y="40" width="26" height="28" rx="10" fill="{PINK}"/></g>')
@icon("ruler_fill", ORANGE)                               # 生长: a tape measure
def _(sv):
    sv.add(f'<circle cx="96" cy="120" r="50" fill="{R(sv, ORANGE)}"/><circle cx="96" cy="120" r="16" fill="#FFF"/>')
    sv.add(f'<rect x="96" y="158" width="104" height="22" rx="4" fill="{YELLOW}"/>' + "".join(f'<path d="M{110 + i * 14} 158 v{10 if i % 2 else 14}" stroke="#8A5A00" stroke-width="3"/>' for i in range(6)))
@icon("pencil", GREY)                                     # 备注: a pencil writing on a note
def _(sv):
    sv.add(f'<rect x="54" y="62" width="108" height="124" rx="12" fill="#FFF" stroke="#EDE5D8" stroke-width="3"/>' + "".join(f'<path d="M72 {94 + i * 22} h{70 - i * 12}" stroke="#C9C1B6" stroke-width="6" stroke-linecap="round"/>' for i in range(4)))
    sv.add(f'<g transform="rotate(38 160 130)"><rect x="150" y="56" width="22" height="104" rx="5" fill="{G(sv, YELLOW)}"/><path d="M150 160 l11 24 l11 -24z" fill="#F6D2B0"/><path d="M157 176 l4 8 l4 -8z" fill="{INK}"/><rect x="150" y="50" width="22" height="14" rx="4" fill="{PINK}"/></g>')
@icon("puzzlepiece_fill", TEAL)                           # 玩过: a puzzle piece
def _(sv):
    sv.add(f'<path d="M62 78 H100 C96 56 144 56 140 78 H178 V114 C200 110 200 150 178 146 V188 H62 V146 C84 150 84 110 62 114 Z" fill="{G(sv, TEAL)}"/>')

# ---------- me ----------
@icon("list_bullet_clipboard_fill", ORANGE)               # 记录: a clipboard with stickers
def _(sv):
    sv.add(f'<rect x="58" y="54" width="124" height="148" rx="16" fill="{G(sv, "#D9964F")}"/><rect x="70" y="70" width="100" height="120" rx="8" fill="#FFF"/><rect x="96" y="44" width="48" height="22" rx="8" fill="#9A9289"/>')
    for i, c in enumerate((PINK, LILAC, BLUE)):
        sv.add(f'<circle cx="90" cy="{96 + i * 30}" r="10" fill="{c}"/><path d="M108 {96 + i * 30} h46" stroke="#C9C1B6" stroke-width="6" stroke-linecap="round"/>')
@icon("faceid", GREEN)                                    # 面容 ID: a padlock with a happy face
def _(sv):
    sv.add(f'<path d="M86 104 v-20 a34 34 0 0 1 68 0 v20" stroke="#9A9289" stroke-width="14" fill="none"/><rect x="62" y="100" width="116" height="90" rx="22" fill="{G(sv, GREEN)}"/>')
    sv.add(eyes(120, 136, 14, 5) + smile(120, 156, 10))
@icon("circle_lefthalf_filled", LILAC)                    # 外观: a palette
def _(sv):
    sv.add(f'<path d="M120 50 c44 0 78 30 78 66 c0 22 -18 28 -32 24 c-14 -4 -22 8 -16 22 c8 18 -6 30 -30 30 c-42 0 -76 -30 -76 -70 c0 -40 34 -72 76 -72z" fill="{G(sv, "#F6E3C8")}"/>')
    for x, y, c in ((88, 92, RED), (124, 76, YELLOW), (160, 96, TEAL), (78, 132, BLUE), (104, 160, PINK)): sv.add(f'<circle cx="{x}" cy="{y}" r="13" fill="{R(sv, c)}"/>')
@icon("info", TEAL)                                       # 关于: Moss, the leaf on its head
def _(sv):
    sv.add(f'<g transform="translate(20 22) scale(2)">'
           f'<path d="M49 36 C48 30 49.2 23 50 17.6" stroke="#3D5434" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
           + "".join(f'<path d="{m[0]}" fill="{c}"/>' for m, c in zip([pb.MINT[1], pb.MINT[0], pb.MINT[3], pb.MINT[2]], ["#7FCBA0", "#4FAE7F", "#A9E0C0", "#A9E0C0"]))
           + f'<path d="{pb.MOSS_BODY}" fill="#55704A"/>'
           f'<ellipse cx="43" cy="55" rx="6.4" ry="7.4" fill="#FBF9F3"/><ellipse cx="58" cy="55" rx="6.4" ry="7.4" fill="#FBF9F3"/><circle cx="44.6" cy="53" r="4" fill="{INK}"/><circle cx="59.6" cy="53" r="4" fill="{INK}"/></g>')
@icon("square_and_arrow_up", BLUE)                        # 导出: a parcel going out
def _(sv):
    sv.add(f'<rect x="60" y="104" width="120" height="86" rx="12" fill="{G(sv, "#D9964F")}"/><rect x="60" y="104" width="120" height="20" rx="8" fill="#E8AD6E"/>')
    sv.add(f'<path d="M120 140 v-86 M94 78 l26 -26 l26 26" stroke="{BLUE}" stroke-width="14" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
@icon("square_and_arrow_down", LILAC)                     # 导入: a parcel coming in
def _(sv):
    sv.add(f'<rect x="60" y="104" width="120" height="86" rx="12" fill="{G(sv, "#D9964F")}"/><rect x="60" y="104" width="120" height="20" rx="8" fill="#E8AD6E"/>')
    sv.add(f'<path d="M120 44 v96 M94 114 l26 26 l26 -26" stroke="{LILAC}" stroke-width="14" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
@icon("doc_text_fill", GREY)                              # 使用条款: a page
def _(sv):
    sv.add(f'<path d="M66 46 h80 l30 30 v116 h-110z" fill="#FFF" stroke="#EDE5D8" stroke-width="3"/><path d="M146 46 v30 h30" fill="#EDE5D8"/>' + "".join(f'<path d="M84 {100 + i * 20} h{72 - (i % 2) * 20}" stroke="#C9C1B6" stroke-width="7" stroke-linecap="round"/>' for i in range(4)))
@icon("hand_raised_fill", BLUE)                           # 隐私 / 停下来: an open hand
def _(sv):
    skin = pb.SKIN[0]
    for x, h in ((84, 70), (106, 84), (128, 86), (150, 74)):
        sv.add(f'<rect x="{x}" y="{170 - h - 40}" width="20" height="{h}" rx="10" fill="{G(sv, skin)}"/>')
    sv.add(f'<rect x="80" y="110" width="94" height="84" rx="34" fill="{G(sv, skin)}"/>')
    sv.add(f'<g transform="rotate(-38 80 150)"><rect x="70" y="112" width="22" height="58" rx="11" fill="{G(sv, skin)}"/></g>')
    sv.add(f'<path d="M110 156 q14 10 28 0" stroke="#D9A57C" stroke-width="4" fill="none" stroke-linecap="round"/>')
@icon("exclamationmark_bubble_fill", ORANGE)              # 免责声明: a speech bubble with a note
def _(sv):
    sv.add(f'<path d="M60 60 h120 a20 20 0 0 1 20 20 v60 a20 20 0 0 1 -20 20 h-60 l-26 24 v-24 h-34 a20 20 0 0 1 -20 -20 v-60 a20 20 0 0 1 20 -20z" fill="#FFF"/>')
    sv.add(f'<rect x="113" y="78" width="14" height="44" rx="7" fill="{ORANGE}"/><circle cx="120" cy="140" r="8" fill="{ORANGE}"/>')
@icon("books_vertical_fill", CARAMEL)                     # 内容来源: books on a shelf
def _(sv):
    for x, w, h, c in ((56, 30, 120, TEAL), (88, 26, 104, PINK), (116, 34, 128, YELLOW), (152, 28, 112, BLUE)):
        sv.add(f'<rect x="{x}" y="{188 - h}" width="{w}" height="{h}" rx="6" fill="{G(sv, c)}"/><rect x="{x + 6}" y="{200 - h}" width="{w - 12}" height="8" rx="3" fill="#FFF" opacity=".8"/>')
    sv.add(f'<rect x="46" y="186" width="148" height="10" rx="5" fill="#B8854F"/>')
@icon("checkmark_seal_fill", TEAL)                        # 许可与致谢: a rosette
def _(sv):
    sv.add(f'<path d="M98 140 l-16 56 l22 -10 l14 18 l8 -60z M142 140 l16 56 l-22 -10 l-14 18 l-8 -60z" fill="{RED}"/>')
    pts = " ".join(f"{120 + math.cos(math.radians(i * 15)) * (56 if i % 2 == 0 else 48):.1f},{108 + math.sin(math.radians(i * 15)) * (56 if i % 2 == 0 else 48):.1f}" for i in range(24))
    sv.add(f'<polygon points="{pts}" fill="{YELLOW}"/><circle cx="120" cy="108" r="36" fill="{TEAL}"/>' + pb.pict("check", 120, 108, 2.2).replace("#4DB86A", "#FFF"))
@icon("clock_arrow_circlepath", LILAC)                    # 更新日志: a calendar page
def _(sv):
    sv.add(f'<rect x="58" y="58" width="124" height="128" rx="16" fill="#FFF"/><rect x="58" y="58" width="124" height="34" rx="12" fill="{G(sv, RED)}"/>')
    sv.add(f'<path d="M86 50 v18 M154 50 v18" stroke="#9A9289" stroke-width="9" stroke-linecap="round"/>' + "".join(f'<circle cx="{86 + (i % 4) * 22}" cy="{114 + (i // 4) * 24}" r="6" fill="{[TEAL, PINK, YELLOW, BLUE][i % 4]}"/>' for i in range(11)))
@icon("envelope_fill", PINK)                              # 反馈问题: an envelope with a heart
def _(sv):
    sv.add(f'<rect x="50" y="74" width="140" height="96" rx="14" fill="#FFF" stroke="#EDE5D8" stroke-width="3"/><path d="M54 80 l66 50 l66 -50" stroke="#EDE5D8" stroke-width="6" fill="none" stroke-linejoin="round"/>')
    sv.add(pb.pict("heart", 120, 140, 1.6))
@icon("exclamationmark_triangle_fill", ORANGE)            # 安全 / 需要留意: a shield that keeps a heart safe
def _(sv):
    sv.add(f'<path d="M120 46 L182 70 C182 132 160 172 120 196 C80 172 58 132 58 70 Z" fill="{G(sv, ORANGE)}"/>')
    sv.add(f'<path d="M120 62 L168 80 C168 128 152 158 120 178 C88 158 72 128 72 80 Z" fill="#FFF" opacity=".9"/>')
    sv.add(pb.pict("heart", 120, 118, 2.2))

@icon("tray_full_fill", CARAMEL)                          # 准备: a wooden tray with things on it
def _(sv):
    pb.obj(sv, "block", 86, 150, .8, RED); pb.obj(sv, "ball", 136, 150, .75, TEAL); pb.obj(sv, "cup", 176, 150, .7, YELLOW)
    sv.add(f'<path d="M44 150 h152 l-12 30 h-128z" fill="{G(sv, "#D9964F")}"/>')
@icon("person_2_fill", PINK)                              # 一起: two little people
def _(sv):
    sv.add(f'<circle cx="92" cy="92" r="26" fill="{R(sv, pb.SKIN[0])}"/><rect x="62" y="122" width="60" height="70" rx="26" fill="{G(sv, PINK)}"/>')
    sv.add(f'<circle cx="154" cy="112" r="20" fill="{R(sv, pb.SKIN[1])}"/><rect x="132" y="136" width="46" height="56" rx="20" fill="{G(sv, YELLOW)}"/>')
    sv.add(eyes(92, 90, 9, 3.4) + eyes(154, 110, 7, 3) + smile(92, 102, 6) + smile(154, 120, 5))

# ---------- added with the 3D world: the same marks in the 2D world, so no icon is ever missing there ----------
@icon("chart_bar_fill", LILAC)                            # 最近七天: three soft bars
def _(sv):
    for i, (h, c) in enumerate(((60, "#B39CF4"), (96, LILAC), (126, "#7E5FD6"))):
        sv.add(f'<rect x="{62 + i * 44}" y="{184 - h}" width="34" height="{h}" rx="10" fill="{G(sv, c)}"/>')
    sv.add('<path d="M52 186 h138" stroke="#FFF" stroke-width="6" stroke-linecap="round"/>')
@icon("circle_dashed", TEAL)                              # 头围: a soft tape measure round a ball
def _(sv):
    sv.add(f'<circle cx="120" cy="124" r="62" fill="{R(sv, "#FFE3A3")}"/>')
    sv.add('<ellipse cx="120" cy="130" rx="70" ry="22" fill="none" stroke="#FFF" stroke-width="14"/>')
    sv.add(''.join(f'<path d="M{70 + i * 20} {140 - (6 if i % 2 else 0)} v8" stroke="{TEAL}" stroke-width="4" stroke-linecap="round"/>' for i in range(6)))
@icon("clock_fill", LILAC)                                # 时间: a round alarm clock
def _(sv):
    for x in (78, 162): sv.add(f'<circle cx="{x}" cy="66" r="16" fill="{R(sv, YELLOW)}"/>')
    sv.add(f'<circle cx="120" cy="128" r="64" fill="{R(sv, LILAC)}"/><circle cx="120" cy="128" r="48" fill="#FFF"/>')
    sv.add(f'<path d="M120 128 V96 M120 128 H146" stroke="{INK}" stroke-width="7" stroke-linecap="round"/><circle cx="120" cy="128" r="6" fill="{INK}"/>')
@icon("drop_halffull", BLUE)                              # 尿布 · 湿: a drop of water
def _(sv):
    sv.add(f'<path d="M120 40 C150 84 172 112 172 144 a52 52 0 0 1 -104 0 C68 112 90 84 120 40Z" fill="{G(sv, "#7FC4F4")}"/>')
    sv.add('<ellipse cx="100" cy="128" rx="9" ry="16" fill="#FFF" opacity=".7"/>')
@icon("diaper_dirty", CARAMEL)                            # 尿布 · 便: a soft little swirl
def _(sv):
    for y, w in ((176, 128), (146, 96), (118, 62)):
        sv.add(f'<ellipse cx="120" cy="{y}" rx="{w / 2}" ry="22" fill="{G(sv, "#A86F3E")}"/>')
    sv.add(f'<path d="M112 98 q8 -22 14 -6 z" fill="#A86F3E"/><ellipse cx="98" cy="150" rx="7" ry="5" fill="#E7C7A6" opacity=".8"/>')
@icon("diaper_both", LILAC)                               # 尿布 · 都有: the drop and the swirl together
def _(sv):
    sv.add(f'<path d="M84 64 C104 96 118 112 118 136 a34 34 0 0 1 -68 0 C50 112 64 96 84 64Z" fill="{G(sv, "#7FC4F4")}"/>')
    for y, w in ((182, 84), (160, 62), (140, 40)):
        sv.add(f'<ellipse cx="160" cy="{y}" rx="{w / 2}" ry="15" fill="{G(sv, "#A86F3E")}"/>')
@icon("exclamationmark_shield_fill", RED)                 # 安全提醒: a shield with a mark
def _(sv):
    sv.add(f'<path d="M120 42 L180 64 V118 C180 160 152 186 120 200 C88 186 60 160 60 118 V64 Z" fill="{G(sv, RED)}"/>')
    sv.add('<rect x="111" y="80" width="18" height="62" rx="9" fill="#FFF"/><circle cx="120" cy="164" r="11" fill="#FFF"/>')
@icon("externaldrive_fill", GREY)                         # 备份: a little box that keeps things
def _(sv):
    sv.add(f'<rect x="48" y="92" width="144" height="76" rx="18" fill="{G(sv, "#B9B2A8")}"/><rect x="48" y="92" width="144" height="18" rx="9" fill="#D9D4C7"/>')
    sv.add(f'<circle cx="166" cy="142" r="8" fill="{GREEN}"/><path d="M70 142 h60" stroke="#8A8279" stroke-width="6" stroke-linecap="round"/>')
@icon("lamp_desk_fill", YELLOW)                           # 台灯: Otto's lamp, a rod and its golden bead
def _(sv):
    sv.add('<path d="M138 196 V110 q0 -50 -46 -54" stroke="#1F3366" stroke-width="12" fill="none" stroke-linecap="round"/>')
    sv.add(f'<ellipse cx="138" cy="198" rx="40" ry="10" fill="#1F3366"/><circle cx="88" cy="70" r="20" fill="{R(sv, "#D4A21C")}"/>')
@icon("leaf_fill", GREEN)                                 # 看他长大: a sprout with two round leaves
def _(sv):
    sv.add('<path d="M120 196 V104" stroke="#3E9B5A" stroke-width="9" stroke-linecap="round"/>')
    sv.add(f'<ellipse cx="88" cy="102" rx="40" ry="22" fill="{G(sv, GREEN)}" transform="rotate(-24 88 102)"/>')
    sv.add(f'<ellipse cx="152" cy="94" rx="40" ry="22" fill="{G(sv, "#6FCB86")}" transform="rotate(24 152 94)"/>')
    sv.add('<ellipse cx="120" cy="196" rx="52" ry="10" fill="#8B6A4A" opacity=".5"/>')
@icon("scalemass_fill", ORANGE)                           # 体重: a little scale
def _(sv):
    sv.add(f'<rect x="54" y="118" width="132" height="70" rx="20" fill="{G(sv, "#FFFFFF")}" stroke="#E6DED0" stroke-width="4"/>')
    sv.add(f'<ellipse cx="120" cy="104" rx="70" ry="16" fill="{G(sv, "#A8E0B8")}"/><circle cx="120" cy="154" r="20" fill="#FFF" stroke="{ORANGE}" stroke-width="5"/>')
    sv.add(f'<path d="M120 154 l10 -10" stroke="{RED}" stroke-width="4" stroke-linecap="round"/>')
@icon("square_and_arrow_down_on_square_fill", BLUE)       # 导入: a parcel coming in
def _(sv):
    sv.add(f'<rect x="62" y="108" width="116" height="84" rx="14" fill="{G(sv, "#D9964F")}"/><rect x="62" y="108" width="116" height="20" rx="8" fill="#E8B583"/>')
    sv.add(f'<path d="M120 40 V112 M96 90 L120 114 L144 90" stroke="{BLUE}" stroke-width="12" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
@icon("square_grid_2x2_fill", YELLOW)                     # 一起玩: four soft blocks
def _(sv):
    for (x, y, c) in ((66, 70, YELLOW), (124, 70, GREEN), (66, 128, RED), (124, 128, BLUE)):
        sv.add(f'<rect x="{x}" y="{y}" width="52" height="52" rx="12" fill="{G(sv, c)}"/>')
@icon("stethoscope", RED)                                 # 看医生: a stethoscope
def _(sv):
    sv.add('<path d="M78 52 V110 a42 42 0 0 0 84 0 V52" stroke="#1F3366" stroke-width="10" fill="none" stroke-linecap="round"/>')
    sv.add('<path d="M120 152 V176 a20 20 0 0 0 40 0" stroke="#1F3366" stroke-width="10" fill="none" stroke-linecap="round"/>')
    sv.add(f'<circle cx="160" cy="176" r="18" fill="{R(sv, "#C9C1B6")}"/><circle cx="78" cy="50" r="8" fill="{RED}"/><circle cx="162" cy="50" r="8" fill="{RED}"/>')
@icon("tablecells_fill", TEAL)                            # 表格: a sheet with cells
def _(sv):
    sv.add('<rect x="56" y="62" width="128" height="116" rx="14" fill="#FFF" stroke="#E6DED0" stroke-width="4"/>')
    sv.add(f'<rect x="56" y="62" width="128" height="28" rx="14" fill="{TEAL}"/>')
    sv.add('<path d="M56 120 H184 M56 150 H184 M98 90 V178 M140 90 V178" stroke="#C9C1B6" stroke-width="4"/>')
@icon("tree_fill", GREEN)                                 # 户外: a round little tree
def _(sv):
    sv.add('<rect x="111" y="132" width="18" height="64" rx="8" fill="#B8854F"/>')
    for (x, y, r) in ((90, 116, 38), (150, 116, 38), (120, 80, 46)):
        sv.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{R(sv, GREEN)}"/>')

def render(key):
    colour, fn, wob = D[key]
    sv = sticker(colour, fn, wob)
    png = cairosvg.svg2png(bytestring=sv.svg().encode(), output_width=360)
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    n = f"{pb.PREFIX}ic_{key}.webp"
    im.save(os.path.join(OUT, n), "WEBP", quality=92, method=6)
    return n

def main():
    ipath = os.path.join(OUT, "index.json")
    index = json.load(open(ipath))
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else None
    names = [] if "--only-trays" in sys.argv else [render(k) for k in D if not only or k in only]
    for n in names: index["size"][n] = [360, 360]
    tnames = trays(index) if not only else []
    print(len(tnames), "trays")
    json.dump(index, open(ipath, "w"), separators=(",", ":"))
    print(len(names), "stickers")
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        cols = 8; rows = (len(names) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * 150, rows * 150), (251, 247, 240, 255))
        for k, n in enumerate(names): sheet.alpha_composite(Image.open(os.path.join(OUT, n)).resize((150, 150)), ((k % cols) * 150, (k // cols) * 150))
        sheet.save(out)


# ---------- the Montessori trays: each activity's materials laid out on its own wooden tray ----------
# (kind, x offset from the tray's middle, scale, colour or picture, rotation)
TRAYS = {
    "N01": [("card", -50, .9, "note", 0), ("card", 30, .9, "heart", 0)],
    "N02": [("card", -40, 1, "happy", 0), ("mirror", 50, .45, None, 0)],
    "N03": [("cloth", -20, .9, "#BFE3F0", 0), ("card", 70, .8, "heart", 0)],
    "N04": [("cushion", -40, .7, "#FFC23D", 0), ("card", 70, .85, "sun", 0)],
    "N05": [("bookopen", -10, .9, "#1FB5A6", 0), ("card", 90, .7, "note", 0)],
    "N06": [("notebook", 0, 1.1, None, 0)],
    "A01": [("card", -50, .9, "dots", 0), ("card", 30, .9, "note", 0)],
    "A02": [("sock", -40, .9, "#FF6F91", 0), ("sock", 20, .9, "#4C9BE8", 0), ("card", 90, .7, "q", 0)],
    "A03": [("cushion", -50, .6, "#FF8A3D", 0), ("rattle", 50, 1, "#9B7BEA", 0)],
    "A04": [("rattle", -30, 1.1, "#9B7BEA", 0), ("rattle", 50, .9, "#FF6F91", 0)],
    "A05": [("rattle", -20, 1.1, "#1FB5A6", 0), ("card", 70, .8, "note", 0)],
    "A06": [("bookopen", 0, 1, "#4C9BE8", 0)],
    "A07": [("card", -60, .85, "note", 0), ("drum", 40, .7, "#F2554B", 0)],
    "A08": [("cloth", -40, .8, "#1FB5A6", 0), ("cloth2", 50, .8, "#FFC23D", 0)],
    "A09": [("mirror", 0, .6, None, 0)],
    "A10": [("bird", -30, 1.4, "#4C9BE8", 0), ("leaf", 60, .9, "#4DB86A", 20)],
    "A11": [("block", -40, .8, "#F2554B", 0), ("ball", 40, .75, "#4C9BE8", 0)],
    "A12": [("cloth", 0, 1, "#FF6F91", 0)],
    "A13": [("drum", -20, .9, "#F2554B", 0), ("block", 70, .6, "#FFC23D", 0)],
    "A14": [("basket", -30, .8, None, 0), ("ball", 60, .6, "#FF8A3D", 0), ("block", 100, .5, "#4C9BE8", 0)],
    "A15": [("ball", -40, .8, "#FF8A3D", 0), ("cup", 40, .8, "#1FB5A6", 0)],
    "A16": [("thing", -40, 1, "apple", 0), ("cup", 40, .8, "#4C9BE8", 0)],
    "A17": [("card", -40, .9, "hand", 0), ("ball", 50, .7, "#FF8A3D", 0)],
    "A18": [("ball", -30, 1, "#F2554B", 0), ("ball", 60, .6, "#FFC23D", 0)],
    "A19": [("blocks", -20, .55, ["#4C9BE8", "#FFC23D", "#F2554B"], 0), ("block", 70, .5, "#4DB86A", 0)],
    "A20": [("cloth2", -40, .8, "#1FB5A6", 0), ("basket", 60, .55, None, 0)],
    "A21": [("shirt", -40, .9, "#4C9BE8", 0), ("shirt", 50, .9, "#FF6F91", 0)],
    "A22": [("thing", -50, 1, "apple", 0), ("card", 20, .9, "apple", 0), ("card", 90, .9, "cup", 0)],
    "A23": [("book", -40, 1, "#F2554B", 0), ("book", 40, 1, "#4C9BE8", 0)],
    "A24": [("paper", -20, 1.0, ["#F2554B", "#4C9BE8", "#4DB86A"], 0), ("crayon", 40, 1.1, "#FFC23D", -70), ("crayon", 80, 1.1, "#F2554B", -60)],
    "A25": [("doll", -40, .9, "#9B7BEA", 0), ("bowl", 40, .9, "#1FB5A6", 0), ("spoon", 90, .8, None, 30)],
    "A26": [("card", -40, .9, "happy", 0), ("card", 40, .9, "sad", 0)],
    "A27": [("basket", -50, .6, None, 0), ("ball", 30, .5, "#F2554B", 0), ("block", 80, .5, "#4C9BE8", 0)],
    "A28": [("pot", -40, .8, "#F2554B", 0), ("bowl", 50, .8, "#1FB5A6", 0)],
    "A29": [("cushion", -40, .55, "#9B7BEA", 0), ("cushion", 60, .5, "#1FB5A6", 0)],
    "A30": [("drum", -40, .75, "#FFC23D", 0), ("card", 60, .85, "note", 0)],
    "A31": [("card", -40, .9, "sun", 0), ("card", 40, .9, "car", 0)],
    "A32": [("blocks", -40, .6, ["#4C9BE8", "#F2554B"], 0), ("car", 50, .7, "#FFC23D", 0)],
    "A33": [("blocks", -30, .45, ["#4C9BE8", "#4DB86A", "#F2554B", "#FFC23D"], 0), ("block", 60, .5, "#FF6F91", 0)],
    "A34": [("leaf", -50, 1, "#FF8A3D", -20), ("leaf", 0, .9, "#FFC23D", 15), ("flower", 60, 1, "#FF6F91", 0)],
    "A35": [("sock", -40, .9, "#FF6F91", 0), ("box", 50, .55, "#4C9BE8", 0)],
    "A36": [("card", -60, .8, "sun", 0), ("card", 0, .8, "car", 0), ("card", 60, .8, "cat", 0)],
    "A37": [("card", -40, .9, "zh", 0), ("card", 40, .9, "en", 0)],
    "A38": [("photo", 0, .9, 3, 0)],
    "A39": [("car", -20, .9, "#F2554B", 0), ("card", 80, .7, "stop", 0)],
    "A40": [("lantern", -50, .7, None, 0), ("bowl", 50, .8, "#F2554B", 0)],
}

def tray(code, area):
    sv = pb.SVG(400, 300)
    wood, edge = "#E8C08A", "#C99258"
    top = 214
    # the tray: a raised rim seen a little from above, handles at the ends, the area's colour as a felt mat inside
    sv.shadow(200, 262, 170, 16, .16)
    sv.add(f'<path d="M40 {top} L360 {top} L346 254 L54 254 Z" fill="{G(sv, edge)}"/>')
    sv.add(f'<path d="M58 {top - 34} L342 {top - 34} L360 {top} L40 {top} Z" fill="{wood}"/>')
    sv.add(f'<path d="M74 {top - 26} L326 {top - 26} L338 {top - 6} L62 {top - 6} Z" fill="{pb.AREA[area][0]}"/>')
    sv.add(f'<rect x="56" y="{top + 12}" width="26" height="9" rx="4.5" fill="#B07A44"/><rect x="318" y="{top + 12}" width="26" height="9" rx="4.5" fill="#B07A44"/>')
    for (k, dx, s, c, r) in TRAYS.get(code, []):
        pb.obj(sv, k, 200 + dx * 1.25, top - 14, s * 1.7, c, r)
    png = cairosvg.svg2png(bytestring=sv.svg().encode(), output_width=800)
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    n = f"{pb.PREFIX}tray_{code.lower()}.webp"
    im.save(os.path.join(OUT, n), "WEBP", quality=90, method=4)
    return n

def trays(index):
    out = []
    for p in pb.C["activities"]:
        n = tray(p["code"], pb.area_of(p)); index["size"][n] = [800, 600]; out.append(n)
    return out

if __name__ == "__main__":
    main()
    if "--trays" in sys.argv:
        out = sys.argv[sys.argv.index("--trays") + 1]
        ns = [f"tray_{p['code'].lower()}.webp" for p in pb.C["activities"]]
        sheet = Image.new("RGBA", (8 * 200, ((len(ns) + 7) // 8) * 150), (251, 247, 240, 255))
        for k, n in enumerate(ns): sheet.alpha_composite(Image.open(os.path.join(OUT, n)).resize((200, 150)), ((k % 8) * 200, (k // 8) * 150))
        sheet.save(out)
