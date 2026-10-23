"""The iOS picture book: every activity step drawn from its own scene description (tools/scenes.json).

Why: a step picture has to say on its own who does what with what (ios/DESIGN.md §4). Pictures made from keyword
rules came out the same for most steps; here each step is described by hand — poses, where hands go, where eyes look,
which material, which marks — and drawn by one rig, so the set stays consistent and every picture can be reviewed and
redrawn from data.

The look: a picture book with soft volume. Flat shapes lit from the upper left, a soft contact shadow, a ground disc in
the activity's area colour, no gloss and no glass. Adult on the left, child on the right, same camera for every step.

Usage:
  python3 tools/picturebook.py                 draw everything into ios/Art/art
  python3 tools/picturebook.py --only A11,A12  draw some activities (and no covers)
  python3 tools/picturebook.py --rig out.png   a test sheet of every pose and material
  python3 tools/picturebook.py --sheet out.png a contact sheet of the steps
"""
import io, json, math, os, sys
import cairosvg
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ios/Art/art")
C = json.load(open(os.path.join(ROOT, "app/src/main/assets/content.json")))
SCENES = os.path.join(ROOT, "tools", "scenes.json")
W, H = 720, 540
GROUND = 440

# ---------- colour ----------
PAPER = "#FBF7F0"
SKIN = ["#F2CDA8", "#D9A57C"]           # adult, child (two warm tones so the two read apart)
HAIR = {"adult": "#4A3428", "child": "#6B4A32"}
ADULT_TOP, ADULT_LEG = "#E2728C", "#55607E"
CHILD_TOP, CHILD_LEG = "#F2B526", "#5BA8E0"
PEER_TOP, PEER_LEG = "#4DAF4E", "#8E6FDB"
AREA = {  # the app's six areas (Theme.swift Palette.area): (ground, backdrop)
    "A": ("#CFE4F6", "#E6F1FB"), "B": ("#FBD9B6", "#FDEBD9"), "C": ("#DDD3F5", "#EEE9FB"),
    "D": ("#F8D0DE", "#FCE6EE"), "E": ("#F8E3A8", "#FCF1D2"), "F": ("#C4EAE4", "#E3F5F2"),
}
INK = "#3B3330"

def area_of(play):
    d = play["domains"][0] if play["domains"] else ""
    rules = [("F", ["安全", "照护", "调节"]), ("E", ["生活", "自理", "自主", "文化", "家庭"]),
             ("A", ["语言", "共读", "表达", "多语言"]), ("B", ["大运动", "运动"]),
             ("D", ["社会", "社交", "关系", "情绪", "合作", "轮流", "共同注意", "假装", "规则"])]
    for k, words in rules:
        if any(w in d for w in words): return k
    return "C"

def mix(hexc, t, to="#FFFFFF"):
    a = [int(hexc[i:i + 2], 16) for i in (1, 3, 5)]; b = [int(to[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(a, b))
def dark(c, t=0.18): return mix(c, t, "#3A2418")
def light(c, t=0.35): return mix(c, t, "#FFFFFF")

class SVG:
    def __init__(s, w=W, h=H): s.w, s.h, s.defs, s.body, s.n = w, h, [], [], 0
    def id(s): s.n += 1; return f"g{s.n}"
    def add(s, x): s.body.append(x)
    def lin(s, c, angle=135):
        i = s.id(); r = math.radians(angle)
        x1, y1 = 0.5 - math.cos(r) / 2, 0.5 - math.sin(r) / 2
        s.defs.append(f'<linearGradient id="{i}" x1="{x1:.2f}" y1="{y1:.2f}" x2="{1 - x1:.2f}" y2="{1 - y1:.2f}">'
                      f'<stop offset="0" stop-color="{light(c, .28)}"/><stop offset=".55" stop-color="{c}"/><stop offset="1" stop-color="{dark(c, .16)}"/></linearGradient>')
        return f"url(#{i})"
    def rad(s, c):
        i = s.id()
        s.defs.append(f'<radialGradient id="{i}" cx=".38" cy=".34" r=".75"><stop offset="0" stop-color="{light(c, .3)}"/>'
                      f'<stop offset=".6" stop-color="{c}"/><stop offset="1" stop-color="{dark(c, .14)}"/></radialGradient>')
        return f"url(#{i})"
    def shadow(s, cx, cy, rx, ry, a=0.16):
        i = s.id()
        s.defs.append(f'<radialGradient id="{i}"><stop offset="0" stop-color="#5A3A20" stop-opacity="{a}"/><stop offset="1" stop-color="#5A3A20" stop-opacity="0"/></radialGradient>')
        s.add(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="url(#{i})"/>')
    def svg(s):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{s.w}" height="{s.h}" viewBox="0 0 {s.w} {s.h}">'
                f'<defs>{"".join(s.defs)}</defs>{"".join(s.body)}</svg>')

def P(x, y): return (float(x), float(y))
def add(a, b): return (a[0] + b[0], a[1] + b[1])
def polar(deg, L, f=1):
    """A direction measured from straight up, clockwise towards where the figure faces."""
    r = math.radians(deg); return (f * math.sin(r) * L, -math.cos(r) * L)
def dist(a, b): return math.hypot(a[0] - b[0], a[1] - b[1])

def limb(s, pts, w, c, cap=True):
    """A rounded limb with soft volume: a darker base, a lighter core toward the light."""
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts)
    s.add(f'<path d="{d}" fill="none" stroke="{dark(c, .1)}" stroke-width="{w:.1f}" stroke-linecap="round" stroke-linejoin="round"/>')
    o = w * 0.14
    d2 = "M" + " L".join(f"{x - o:.1f} {y - o:.1f}" for x, y in pts)
    s.add(f'<path d="{d2}" fill="none" stroke="{light(c, .16)}" stroke-width="{w * .52:.1f}" stroke-linecap="round" stroke-linejoin="round" opacity=".8"/>')

def ik(shoulder, target, a, b, bend):
    """Two-bone reach: where the elbow goes for the hand to reach target (or as near as it can)."""
    d = max(1e-3, dist(shoulder, target)); dd = min(d, a + b - 0.5)
    ux, uy = (target[0] - shoulder[0]) / d, (target[1] - shoulder[1]) / d
    hand = (shoulder[0] + ux * dd, shoulder[1] + uy * dd)
    x = (a * a - b * b + dd * dd) / (2 * dd); h = math.sqrt(max(0, a * a - x * x))
    px, py = -uy * bend, ux * bend
    return (shoulder[0] + ux * x + px * h, shoulder[1] + uy * x + py * h), hand

# ---------- people ----------
def dims(kind, age):
    if kind == "adult":
        return dict(head=31, torso=118, tw=50, ua=58, fa=56, th=74, sh=72, aw=19, lw=26, hand=11)
    k = min(36, max(0, age)) / 36
    return dict(head=24 + 5 * k, torso=46 + 34 * k, tw=36 + 8 * k, ua=22 + 18 * k, fa=20 + 16 * k,
                th=22 + 28 * k, sh=18 + 30 * k, aw=12 + 4 * k, lw=15 + 5 * k, hand=6.5 + 2.5 * k)

# Poses: torso angle (from up, + leans toward the face), head tilt, legs as (thigh, shin) angles for near and far leg,
# arms at rest (upper, fore), and which joints touch the ground.
POSES = {
    "stand":   dict(torso=2, legs=((178, 180), (184, 182)), arms=((172, 168), (185, 175)), rest="feet"),
    "walk":    dict(torso=6, legs=((158, 178), (206, 222)), arms=((200, 170), (160, 150)), rest="feet"),
    "run":     dict(torso=14, legs=((130, 200), (220, 260)), arms=((220, 150), (140, 100)), rest="feet"),
    "kneel":   dict(torso=4, legs=((96, 262), (100, 266)), arms=((160, 140), (170, 150)), rest="knees"),
    "tallkneel": dict(torso=4, legs=((178, 268), (182, 272)), arms=((165, 150), (175, 160)), rest="knees"),
    "sit":     dict(torso=-4, legs=((76, 106), (84, 100)), arms=((160, 120), (170, 130)), rest="hip"),
    "chair":   dict(torso=-2, legs=((88, 178), (94, 182)), arms=((160, 120), (170, 130)), rest="feet"),
    "sitcross": dict(torso=0, legs=((70, 236), (78, 246)), arms=((150, 110), (160, 120)), rest="hip"),
    "squat":   dict(torso=28, legs=((52, 176), (60, 182)), arms=((150, 120), (160, 130)), rest="feet"),
    "prone":   dict(torso=76, legs=((272, 272), (268, 268)), arms=((150, 92), (160, 92)), rest="flat", head=-34),
    "crawl":   dict(torso=88, legs=((180, 272), (184, 276)), arms=((176, 180), (184, 184)), rest="knees"),
    # on the back, head toward the face direction, legs and arms up in the air
    "lieback": dict(torso=90, legs=((-28, -100), (-40, -112)), arms=((12, 40), (-8, 20)), rest="flat", head=4),
}

class Person:
    def __init__(s, kind, pose, x, face=1, age=30, top=None, leg=None, expr="smile", look=None, hands=(None, None),
                 hair=None, at=None, tilt=0):
        s.kind, s.pose, s.f, s.age, s.expr, s.look, s.tilt = kind, pose, face, age, expr, look, tilt
        s.d = dims(kind, age)
        s.top = top or (ADULT_TOP if kind == "adult" else CHILD_TOP)
        s.leg = leg or (ADULT_LEG if kind == "adult" else CHILD_LEG)
        s.skin = SKIN[0] if kind == "adult" else SKIN[1]
        s.hair = hair or ("bun" if kind == "adult" else ("tuft" if age < 12 else "bob"))
        s.targets = hands
        s.build(x, at)

    def build(s, x, at):
        if s.pose == "bundle":  # placed by `at` (its middle) and a tilt; the head at the face end
            s.bundle_c = at or (x, GROUND - 40); s.bundle_a = s.tilt
            L = s.d["torso"] * 1.9; r = math.radians(s.tilt)
            s.headc = (s.bundle_c[0] + s.f * math.cos(r) * (L / 2 + s.d["head"] * .55), s.bundle_c[1] + s.f * math.sin(r) * (L / 2 + s.d["head"] * .55))
            s.hip = s.sh = s.bundle_c; s.legs = [(s.bundle_c, s.bundle_c)] * 2; s.arms = [(s.bundle_c,) * 3] * 2
            s.shN = s.shF = s.bundle_c
            return
        d, p, f = s.d, POSES[s.pose], s.f
        hip = (0.0, 0.0)
        sh = add(hip, polar(p["torso"], d["torso"], f))
        legs = []
        for (ta, sa) in p["legs"]:
            knee = add(hip, polar(ta, d["th"], f)); foot = add(knee, polar(sa, d["sh"], f)); legs.append((knee, foot))
        # rest on the ground
        if p["rest"] == "feet": low = max(legs[0][1][1], legs[1][1][1]) + d["lw"] * 0.45
        elif p["rest"] == "knees": low = max(legs[0][0][1], legs[1][0][1], legs[0][1][1]) + d["lw"] * 0.5
        elif p["rest"] == "hip": low = max(d["lw"] * 0.55, legs[0][1][1] + d["lw"] * 0.45, legs[1][1][1] + d["lw"] * 0.45)
        else: low = d["tw"] * 0.42
        oy = (at[1] if at else GROUND) - low; ox = at[0] if at else x
        T = lambda q: (q[0] + ox, q[1] + oy)
        s.hip, s.sh = T(hip), T(sh)
        s.legs = [(T(k), T(ft)) for k, ft in legs]
        ht = p.get("head", 0) + s.tilt
        s.headc = add(s.sh, polar(p["torso"] + ht, d["head"] * 1.15, f))
        # shoulders: near one a little toward the viewer
        s.shN = add(s.sh, polar(p["torso"] + 180, d["head"] * 0.25, f))
        s.shF = add(s.shN, (-f * d["tw"] * 0.12, -2))
        s.arms = []
        for k, (ua, fa) in enumerate(p["arms"]):
            shp = s.shN if k == 0 else s.shF
            tgt = s.targets[k] if s.targets and k < len(s.targets) else None
            if tgt is not None:
                elbow, hand = ik(shp, tgt, d["ua"], d["fa"], bend=(1 if f > 0 else -1) * (1 if p["torso"] > 40 else -1))
            else:
                elbow = add(shp, polar(ua, d["ua"], f)); hand = add(elbow, polar(fa, d["fa"], f))
            s.arms.append((shp, elbow, hand))

    def hand(s, k=0): return s.arms[k][2]
    def head(s): return s.headc

    def draw_shadow(s, sv):
        xs = [s.hip[0], s.legs[0][1][0], s.legs[1][1][0], s.legs[0][0][0], s.headc[0]]
        cx = (min(xs) + max(xs)) / 2; w = max(xs) - min(xs) + s.d["tw"]
        sv.shadow(cx, GROUND + 4, w * 0.62, 14 if s.kind == "adult" else 10)

    def draw(s, sv):
        d, f = s.d, s.f
        if s.pose == "bundle":
            c = s.bundle_c; L = d["torso"] * 1.9; w = d["tw"] * 1.25; ang = s.bundle_a
            sv.add(f'<g transform="translate({c[0]:.1f} {c[1]:.1f}) rotate({ang:.1f})"><rect x="{-L / 2:.1f}" y="{-w / 2:.1f}" width="{L:.1f}" height="{w:.1f}" rx="{w / 2:.1f}" fill="{sv.lin("#BFE3F0", 120)}"/>'
                   f'<path d="M{-L * .1:.1f} {-w / 2 + 3:.1f} Q{L * .1:.1f} {0:.1f} {-L * .05:.1f} {w / 2 - 3:.1f}" stroke="#FFFFFF" stroke-width="4" fill="none" opacity=".7"/></g>')
            s.draw_head(sv, neck=False)
            return
        # far limbs, behind
        knee, foot = s.legs[1]; limb(sv, [s.hip, knee, foot], d["lw"], dark(s.leg, .12)); s.foot(sv, foot, s.legs[1][0], dark(s.leg, .12))
        shp, el, hd = s.arms[1]; limb(sv, [shp, el, hd], d["aw"], dark(s.top, .12)); s.mitt(sv, hd, dark(s.skin, .06))
        # torso
        s.torso(sv)
        knee, foot = s.legs[0]; limb(sv, [s.hip, knee, foot], d["lw"], s.leg); s.foot(sv, foot, knee, s.leg)
        # head
        s.draw_head(sv)
        shp, el, hd = s.arms[0]; limb(sv, [shp, el, hd], d["aw"], s.top); s.mitt(sv, hd, s.skin)

    def foot(s, sv, foot, knee, c):
        if s.kind == "child" and s.age < 10: return
        dx = s.f * s.d["lw"] * 0.45
        sv.add(f'<ellipse cx="{foot[0] + dx:.1f}" cy="{foot[1] + 2:.1f}" rx="{s.d["lw"] * .62:.1f}" ry="{s.d["lw"] * .36:.1f}" fill="{dark(c, .3)}"/>')

    def mitt(s, sv, p, c):
        r = s.d["hand"]
        sv.add(f'<circle cx="{p[0]:.1f}" cy="{p[1]:.1f}" r="{r:.1f}" fill="{sv.rad(c)}"/>')

    def torso(s, sv):
        d = s.d
        a, b = s.hip, s.sh
        L = dist(a, b); ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
        cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        w = d["tw"]
        if s.kind == "child" and s.age < 12: w *= 1.12
        g = sv.lin(s.top, 120)
        sv.add(f'<g transform="translate({cx:.1f} {cy:.1f}) rotate({ang:.1f})">'
               f'<rect x="{-L / 2 - w * .32:.1f}" y="{-w / 2:.1f}" width="{L + w * .5:.1f}" height="{w:.1f}" rx="{w / 2:.1f}" fill="{g}"/></g>')
        if s.kind == "child" and s.age < 12:  # a onesie: the same colour down to the hips
            sv.add(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{w * .5:.1f}" fill="{sv.rad(s.leg)}"/>')

    def draw_head(s, sv, neck=True):
        d, f = s.d, s.f
        c = s.headc; r = d["head"]
        if neck: limb(sv, [s.sh, c], r * 0.55, s.skin)
        hair = HAIR["adult" if s.kind == "adult" else "child"]
        if s.hair == "bun":
            sv.add(f'<circle cx="{c[0] - f * r * .72:.1f}" cy="{c[1] - r * .62:.1f}" r="{r * .42:.1f}" fill="{sv.rad(hair)}"/>')
        sv.add(f'<circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="{r:.1f}" fill="{sv.rad(s.skin)}"/>')
        # hair cap over the top and back
        if s.hair in ("bun", "short", "bob"):
            k = 1.08 if s.hair == "bob" else 1.03
            sv.add(f'<path d="M{c[0] - r * k:.1f} {c[1] + r * (.15 if s.hair == "bob" else -.05):.1f} '
                   f'A{r * k:.1f} {r * k:.1f} 0 0 1 {c[0] + r * k:.1f} {c[1] - r * .05:.1f} '
                   f'Q{c[0] + r * .2:.1f} {c[1] - r * .55:.1f} {c[0] - r * .35:.1f} {c[1] - r * .38:.1f} '
                   f'Q{c[0] - r * .7:.1f} {c[1] - r * .1:.1f} {c[0] - r * .9:.1f} {c[1] + r * .4:.1f} Z" '
                   f'fill="{sv.lin(hair, 120)}" transform="{"" if f > 0 else f"translate({2 * c[0]:.1f} 0) scale(-1 1)"}"/>')
        elif s.hair == "tuft":
            sv.add(f'<path d="M{c[0]:.1f} {c[1] - r:.1f} q{f * 6:.1f} -10 {f * 12:.1f} -4" fill="none" stroke="{hair}" stroke-width="3" stroke-linecap="round"/>')
        # ear
        sv.add(f'<circle cx="{c[0] - f * r * .18:.1f}" cy="{c[1] + r * .08:.1f}" r="{r * .16:.1f}" fill="{dark(s.skin, .08)}"/>')
        # the face looks toward the face direction, eyes toward what is looked at
        fx, fy = c[0] + f * r * .42, c[1] + r * .02
        lx, ly = 0.0, 0.0
        if s.look:
            dx, dy = s.look[0] - c[0], s.look[1] - c[1]; m = max(1, math.hypot(dx, dy)); lx, ly = dx / m * r * .06, dy / m * r * .08
        e = r * .1
        if s.expr in ("sleep", "calm"):
            for ex in (fx - f * r * .2, fx + f * r * .22):
                sv.add(f'<path d="M{ex - e:.1f} {fy - r * .12:.1f} q{e:.1f} {e:.1f} {2 * e:.1f} 0" fill="none" stroke="{INK}" stroke-width="{max(2, r * .07):.1f}" stroke-linecap="round"/>')
        else:
            for k, ex in enumerate((fx - f * r * .2, fx + f * r * .22)):
                sv.add(f'<ellipse cx="{ex + lx:.1f}" cy="{fy - r * .14 + ly:.1f}" rx="{e * (0.8 if k == 0 else 1):.1f}" ry="{e * 1.25:.1f}" fill="{INK}"/>')
                sv.add(f'<circle cx="{ex + lx - e * .3:.1f}" cy="{fy - r * .2 + ly:.1f}" r="{e * .35:.1f}" fill="#FFFFFF"/>')
        # cheek
        sv.add(f'<ellipse cx="{fx + f * r * .3:.1f}" cy="{fy + r * .2:.1f}" rx="{r * .16:.1f}" ry="{r * .1:.1f}" fill="#F08A8A" opacity=".45"/>')
        mx, my = fx + f * r * .06, fy + r * .32
        w = r * .22
        if s.expr in ("talk", "sing"):
            sv.add(f'<ellipse cx="{mx:.1f}" cy="{my:.1f}" rx="{w * .55:.1f}" ry="{w * .5:.1f}" fill="#9C3B3B"/>')
        elif s.expr == "wow":
            sv.add(f'<circle cx="{mx:.1f}" cy="{my:.1f}" r="{w * .38:.1f}" fill="#9C3B3B"/>')
        elif s.expr == "sad":
            sv.add(f'<path d="M{mx - w * .6:.1f} {my + w * .25:.1f} q{w * .6:.1f} {-w * .6:.1f} {w * 1.2:.1f} 0" fill="none" stroke="{INK}" stroke-width="{max(2, r * .07):.1f}" stroke-linecap="round"/>')
        elif s.expr == "flat":
            sv.add(f'<path d="M{mx - w * .45:.1f} {my:.1f} h{w * .9:.1f}" stroke="{INK}" stroke-width="{max(2, r * .07):.1f}" stroke-linecap="round"/>')
        else:
            sv.add(f'<path d="M{mx - w * .6:.1f} {my - w * .15:.1f} q{w * .6:.1f} {w * .7:.1f} {w * 1.2:.1f} 0" fill="none" stroke="{INK}" stroke-width="{max(2, r * .07):.1f}" stroke-linecap="round"/>')

# ---------- materials ----------
def obj(sv, k, x, y, s=1.0, c=None, rot=0):
    """Draws a material standing on (x, y) — y is where it touches the floor or table."""
    g = lambda col: sv.lin(col, 120)
    out = []
    A = out.append
    if k == "block":
        col = c or "#E84F4F"; z = 30 * s
        A(f'<rect x="{x - z:.1f}" y="{y - 2 * z:.1f}" width="{2 * z:.1f}" height="{2 * z:.1f}" rx="{z * .28:.1f}" fill="{g(col)}"/>')
        A(f'<circle cx="{x:.1f}" cy="{y - z:.1f}" r="{z * .42:.1f}" fill="{light(col, .45)}"/>')
    elif k == "blocks":  # a stack: list of colours, bottom first
        cols = c or ["#3E9BE0", "#F2B526", "#E84F4F"]
        yy = y
        for i, col in enumerate(cols):
            z = (30 - i * 2) * s
            A(f'<rect x="{x - z + (i % 2) * 3:.1f}" y="{yy - 2 * z:.1f}" width="{2 * z:.1f}" height="{2 * z:.1f}" rx="{z * .28:.1f}" fill="{g(col)}"/>')
            yy -= 2 * z
    elif k == "tumble":  # fallen blocks
        for i, (dx, col, r) in enumerate([(-44, "#3E9BE0", -18), (0, "#F2B526", 12), (46, "#E84F4F", 30)]):
            z = 26 * s
            A(f'<rect x="{x + dx * s - z:.1f}" y="{y - 2 * z:.1f}" width="{2 * z:.1f}" height="{2 * z:.1f}" rx="{z * .28:.1f}" fill="{g(col)}" transform="rotate({r} {x + dx * s:.1f} {y - z:.1f})"/>')
    elif k == "ball":
        col = c or "#E84F4F"; r = 34 * s
        A(f'<circle cx="{x:.1f}" cy="{y - r:.1f}" r="{r:.1f}" fill="{sv.rad(col)}"/>')
        A(f'<path d="M{x - r:.1f} {y - r:.1f} Q{x:.1f} {y - r * .4:.1f} {x + r:.1f} {y - r:.1f}" fill="none" stroke="#FFFFFF" stroke-width="{r * .18:.1f}" opacity=".85"/>')
        A(f'<path d="M{x:.1f} {y - 2 * r:.1f} Q{x - r * .5:.1f} {y - r:.1f} {x:.1f} {y:.1f}" fill="none" stroke="#FFFFFF" stroke-width="{r * .14:.1f}" opacity=".6"/>')
    elif k == "rattle":
        col = c or "#8E6FDB"; r = 20 * s
        A(f'<rect x="{x - 5 * s:.1f}" y="{y - 70 * s:.1f}" width="{10 * s:.1f}" height="{44 * s:.1f}" rx="{5 * s:.1f}" fill="{g("#F2B526")}" transform="rotate(-24 {x:.1f} {y - 40 * s:.1f})"/>')
        A(f'<circle cx="{x + 14 * s:.1f}" cy="{y - 74 * s:.1f}" r="{r:.1f}" fill="{sv.rad(col)}"/>')
        A(f'<circle cx="{x + 8 * s:.1f}" cy="{y - 80 * s:.1f}" r="{r * .3:.1f}" fill="#FFFFFF" opacity=".55"/>')
    elif k == "cloth":
        col = c or "#4DB8A8"
        A(f'<path d="M{x - 52 * s:.1f} {y:.1f} Q{x - 40 * s:.1f} {y - 50 * s:.1f} {x - 6 * s:.1f} {y - 44 * s:.1f} Q{x + 30 * s:.1f} {y - 56 * s:.1f} {x + 50 * s:.1f} {y:.1f} Z" fill="{g(col)}"/>')
        A(f'<path d="M{x - 30 * s:.1f} {y - 6 * s:.1f} Q{x - 20 * s:.1f} {y - 30 * s:.1f} {x - 4 * s:.1f} {y - 34 * s:.1f}" fill="none" stroke="{light(col, .4)}" stroke-width="{4 * s:.1f}" stroke-linecap="round"/>')
    elif k == "cloth2":  # a rough second fabric
        col = c or "#F2B526"
        A(f'<rect x="{x - 40 * s:.1f}" y="{y - 26 * s:.1f}" width="{80 * s:.1f}" height="{26 * s:.1f}" rx="{10 * s:.1f}" fill="{g(col)}"/>')
        for i in range(5): A(f'<circle cx="{x - 30 * s + i * 15 * s:.1f}" cy="{y - 13 * s:.1f}" r="{3 * s:.1f}" fill="{dark(col, .2)}"/>')
    elif k == "mirror":
        A(f'<rect x="{x - 6 * s:.1f}" y="{y - 40 * s:.1f}" width="{12 * s:.1f}" height="{40 * s:.1f}" rx="4" fill="{g("#C98A4B")}"/>')
        A(f'<ellipse cx="{x:.1f}" cy="{y - 110 * s:.1f}" rx="{56 * s:.1f}" ry="{72 * s:.1f}" fill="{g("#C98A4B")}"/>')
        A(f'<ellipse cx="{x:.1f}" cy="{y - 110 * s:.1f}" rx="{46 * s:.1f}" ry="{62 * s:.1f}" fill="#DCEFF6"/>')
        A(f'<path d="M{x - 26 * s:.1f} {y - 140 * s:.1f} l{22 * s:.1f} {-22 * s:.1f} M{x - 30 * s:.1f} {y - 112 * s:.1f} l{36 * s:.1f} {-36 * s:.1f}" stroke="#FFFFFF" stroke-width="{6 * s:.1f}" stroke-linecap="round" opacity=".8"/>')
    elif k in ("book", "bookopen"):
        col = c or "#3E9BE0"
        if k == "book":
            A(f'<rect x="{x - 30 * s:.1f}" y="{y - 40 * s:.1f}" width="{60 * s:.1f}" height="{40 * s:.1f}" rx="{6 * s:.1f}" fill="{g(col)}"/>')
            A(f'<circle cx="{x:.1f}" cy="{y - 20 * s:.1f}" r="{10 * s:.1f}" fill="#FFFFFF" opacity=".8"/>')
        else:
            A(f'<path d="M{x:.1f} {y - 8 * s:.1f} L{x - 62 * s:.1f} {y - 18 * s:.1f} L{x - 62 * s:.1f} {y - 66 * s:.1f} L{x:.1f} {y - 56 * s:.1f} Z" fill="#FFFDF7" stroke="{col}" stroke-width="{5 * s:.1f}" stroke-linejoin="round"/>')
            A(f'<path d="M{x:.1f} {y - 8 * s:.1f} L{x + 62 * s:.1f} {y - 18 * s:.1f} L{x + 62 * s:.1f} {y - 66 * s:.1f} L{x:.1f} {y - 56 * s:.1f} Z" fill="#FFFDF7" stroke="{col}" stroke-width="{5 * s:.1f}" stroke-linejoin="round"/>')
            A(f'<circle cx="{x - 32 * s:.1f}" cy="{y - 38 * s:.1f}" r="{12 * s:.1f}" fill="#F2B526"/>')
            A(f'<path d="M{x + 18 * s:.1f} {y - 26 * s:.1f} l{14 * s:.1f} {-24 * s:.1f} l{14 * s:.1f} {24 * s:.1f} z" fill="#4DAF4E"/>')
    elif k == "basket":
        col = c or "#C98A4B"
        A(f'<path d="M{x - 52 * s:.1f} {y - 44 * s:.1f} L{x + 52 * s:.1f} {y - 44 * s:.1f} L{x + 42 * s:.1f} {y:.1f} L{x - 42 * s:.1f} {y:.1f} Z" fill="{g(col)}"/>')
        for i in range(1, 4): A(f'<path d="M{x - 52 * s + i * 2.5 * s:.1f} {y - 44 * s + i * 11 * s:.1f} H{x + 52 * s - i * 2.5 * s:.1f}" stroke="{dark(col, .18)}" stroke-width="{2.5 * s:.1f}"/>')
    elif k == "cup":
        col = c or "#2DB3A6"
        A(f'<path d="M{x - 22 * s:.1f} {y - 50 * s:.1f} L{x + 22 * s:.1f} {y - 50 * s:.1f} L{x + 17 * s:.1f} {y:.1f} L{x - 17 * s:.1f} {y:.1f} Z" fill="{g(col)}"/>')
        A(f'<path d="M{x + 20 * s:.1f} {y - 40 * s:.1f} q{16 * s:.1f} {4 * s:.1f} {2 * s:.1f} {24 * s:.1f}" fill="none" stroke="{col}" stroke-width="{6 * s:.1f}"/>')
    elif k == "drum":
        col = c or "#E84F4F"
        A(f'<rect x="{x - 40 * s:.1f}" y="{y - 46 * s:.1f}" width="{80 * s:.1f}" height="{46 * s:.1f}" rx="{8 * s:.1f}" fill="{g(col)}"/>')
        A(f'<ellipse cx="{x:.1f}" cy="{y - 46 * s:.1f}" rx="{40 * s:.1f}" ry="{11 * s:.1f}" fill="#FFF3E0"/>')
        A(f'<path d="M{x - 40 * s:.1f} {y - 30 * s:.1f} l20 16 l20 -16 l20 16 l20 -16" fill="none" stroke="#FFFFFF" stroke-width="{4 * s:.1f}" opacity=".8"/>')
    elif k == "paper":
        A(f'<rect x="{x - 70 * s:.1f}" y="{y - 8 * s:.1f}" width="{140 * s:.1f}" height="{8 * s:.1f}" rx="2" fill="#FFFFFF" stroke="#E6DED0" stroke-width="2"/>')
        for i, col in enumerate(c or []): A(f'<path d="M{x - 50 * s + i * 30 * s:.1f} {y - 4 * s:.1f} q10 -6 22 0" stroke="{col}" stroke-width="{4 * s:.1f}" fill="none" stroke-linecap="round"/>')
    elif k == "crayon":
        col = c or "#3E9BE0"
        A(f'<g transform="rotate({rot or -60} {x:.1f} {y:.1f})"><rect x="{x - 6 * s:.1f}" y="{y - 46 * s:.1f}" width="{12 * s:.1f}" height="{40 * s:.1f}" rx="3" fill="{g(col)}"/>'
          f'<path d="M{x - 6 * s:.1f} {y - 6 * s:.1f} L{x:.1f} {y + 6 * s:.1f} L{x + 6 * s:.1f} {y - 6 * s:.1f} Z" fill="{dark(col, .15)}"/></g>')
    elif k == "doll":
        A(f'<rect x="{x - 18 * s:.1f}" y="{y - 52 * s:.1f}" width="{36 * s:.1f}" height="{52 * s:.1f}" rx="{16 * s:.1f}" fill="{g(c or "#8E6FDB")}"/>')
        A(f'<circle cx="{x:.1f}" cy="{y - 66 * s:.1f}" r="{18 * s:.1f}" fill="{sv.rad("#F6D2B0")}"/>')
        A(f'<circle cx="{x - 6 * s:.1f}" cy="{y - 68 * s:.1f}" r="{2.4 * s:.1f}" fill="{INK}"/><circle cx="{x + 6 * s:.1f}" cy="{y - 68 * s:.1f}" r="{2.4 * s:.1f}" fill="{INK}"/>')
    elif k == "dollbed":  # a doll lying under a blanket
        A(f'<circle cx="{x - 44 * s:.1f}" cy="{y - 20 * s:.1f}" r="{17 * s:.1f}" fill="{sv.rad("#F6D2B0")}"/>')
        A(f'<path d="M{x - 52 * s:.1f} {y - 22 * s:.1f} q3 3 6 0 M{x - 42 * s:.1f} {y - 22 * s:.1f} q3 3 6 0" stroke="{INK}" stroke-width="2" fill="none"/>')
        A(f'<rect x="{x - 30 * s:.1f}" y="{y - 34 * s:.1f}" width="{86 * s:.1f}" height="{34 * s:.1f}" rx="{14 * s:.1f}" fill="{g(c or "#5BA8E0")}"/>')
    elif k == "spoon":
        A(f'<g transform="rotate({rot or 30} {x:.1f} {y:.1f})"><rect x="{x - 3 * s:.1f}" y="{y - 40 * s:.1f}" width="{6 * s:.1f}" height="{34 * s:.1f}" rx="3" fill="#B9B2A8"/><ellipse cx="{x:.1f}" cy="{y - 46 * s:.1f}" rx="{8 * s:.1f}" ry="{11 * s:.1f}" fill="#CFC9C0"/></g>')
    elif k == "pot":
        col = c or "#E84F4F"
        A(f'<rect x="{x - 38 * s:.1f}" y="{y - 40 * s:.1f}" width="{76 * s:.1f}" height="{40 * s:.1f}" rx="{10 * s:.1f}" fill="{g(col)}"/>')
        A(f'<rect x="{x - 44 * s:.1f}" y="{y - 46 * s:.1f}" width="{88 * s:.1f}" height="{10 * s:.1f}" rx="{5 * s:.1f}" fill="{dark(col, .1)}"/>')
        A(f'<rect x="{x + 38 * s:.1f}" y="{y - 36 * s:.1f}" width="{26 * s:.1f}" height="{8 * s:.1f}" rx="4" fill="{dark(col, .25)}"/>')
    elif k == "bowl":
        col = c or "#2DB3A6"
        A(f'<path d="M{x - 34 * s:.1f} {y - 26 * s:.1f} Q{x:.1f} {y + 10 * s:.1f} {x + 34 * s:.1f} {y - 26 * s:.1f} Z" fill="{g(col)}"/>')
        A(f'<circle cx="{x - 8 * s:.1f}" cy="{y - 28 * s:.1f}" r="{9 * s:.1f}" fill="#F2B526"/><circle cx="{x + 10 * s:.1f}" cy="{y - 30 * s:.1f}" r="{8 * s:.1f}" fill="#4DAF4E"/>')
    elif k == "cushion":
        col = c or "#8E6FDB"
        A(f'<rect x="{x - 54 * s:.1f}" y="{y - 30 * s:.1f}" width="{108 * s:.1f}" height="{30 * s:.1f}" rx="{15 * s:.1f}" fill="{g(col)}"/>')
    elif k == "car":
        col = c or "#E84F4F"
        A(f'<path d="M{x - 46 * s:.1f} {y - 14 * s:.1f} V{y - 34 * s:.1f} Q{x - 46 * s:.1f} {y - 40 * s:.1f} {x - 38 * s:.1f} {y - 40 * s:.1f} H{x - 22 * s:.1f} L{x - 10 * s:.1f} {y - 58 * s:.1f} H{x + 22 * s:.1f} L{x + 34 * s:.1f} {y - 40 * s:.1f} H{x + 40 * s:.1f} Q{x + 46 * s:.1f} {y - 40 * s:.1f} {x + 46 * s:.1f} {y - 34 * s:.1f} V{y - 14 * s:.1f} Z" fill="{g(col)}"/>')
        A(f'<path d="M{x - 6 * s:.1f} {y - 52 * s:.1f} H{x + 18 * s:.1f} L{x + 26 * s:.1f} {y - 40 * s:.1f} H{x - 14 * s:.1f} Z" fill="#DCEFF6"/>')
        for dx in (-26, 26): A(f'<circle cx="{x + dx * s:.1f}" cy="{y - 12 * s:.1f}" r="{12 * s:.1f}" fill="#3B3330"/><circle cx="{x + dx * s:.1f}" cy="{y - 12 * s:.1f}" r="{5 * s:.1f}" fill="#B9B2A8"/>')
    elif k == "tree":
        A(f'<rect x="{x - 9 * s:.1f}" y="{y - 120 * s:.1f}" width="{18 * s:.1f}" height="{120 * s:.1f}" rx="{8 * s:.1f}" fill="{g("#A9733F")}"/>')
        for dx, dy, r in ((0, -170, 62), (-44, -130, 44), (44, -134, 46)):
            A(f'<circle cx="{x + dx * s:.1f}" cy="{y + dy * s:.1f}" r="{r * s:.1f}" fill="{sv.rad("#5DB35A")}"/>')
    elif k == "leaf":
        col = c or "#F58A1F"
        A(f'<g transform="rotate({rot} {x:.1f} {y:.1f})"><path d="M{x:.1f} {y:.1f} C{x - 26 * s:.1f} {y - 20 * s:.1f} {x - 20 * s:.1f} {y - 56 * s:.1f} {x:.1f} {y - 66 * s:.1f} C{x + 20 * s:.1f} {y - 56 * s:.1f} {x + 26 * s:.1f} {y - 20 * s:.1f} {x:.1f} {y:.1f} Z" fill="{g(col)}"/>'
          f'<path d="M{x:.1f} {y:.1f} V{y - 58 * s:.1f}" stroke="{dark(col, .25)}" stroke-width="{3 * s:.1f}"/></g>')
    elif k == "flower":
        A(f'<path d="M{x:.1f} {y:.1f} V{y - 40 * s:.1f}" stroke="#4DAF4E" stroke-width="{5 * s:.1f}"/>')
        for i in range(5):
            a = i * 72; A(f'<circle cx="{x + math.sin(math.radians(a)) * 11 * s:.1f}" cy="{y - 48 * s - math.cos(math.radians(a)) * 11 * s:.1f}" r="{8 * s:.1f}" fill="{c or "#EE6F9A"}"/>')
        A(f'<circle cx="{x:.1f}" cy="{y - 48 * s:.1f}" r="{6 * s:.1f}" fill="#F2B526"/>')
    elif k == "bird":
        col = c or "#3E9BE0"
        A(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{18 * s:.1f}" ry="{13 * s:.1f}" fill="{sv.rad(col)}"/><circle cx="{x + 14 * s:.1f}" cy="{y - 10 * s:.1f}" r="{9 * s:.1f}" fill="{sv.rad(col)}"/>'
          f'<path d="M{x + 22 * s:.1f} {y - 10 * s:.1f} l{8 * s:.1f} {3 * s:.1f} l{-8 * s:.1f} {3 * s:.1f}Z" fill="#F2B526"/><circle cx="{x + 16 * s:.1f}" cy="{y - 12 * s:.1f}" r="{2 * s:.1f}" fill="{INK}"/>'
          f'<path d="M{x - 6 * s:.1f} {y - 4 * s:.1f} q{-8 * s:.1f} {-16 * s:.1f} {-20 * s:.1f} {-10 * s:.1f}" fill="none" stroke="{dark(col, .2)}" stroke-width="{4 * s:.1f}" stroke-linecap="round"/>')
    elif k == "sun":
        A(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{30 * s:.1f}" fill="{sv.rad("#FFD45C")}"/>')
    elif k == "cloud":
        for dx, dy, r in ((-24, 4, 18), (0, -6, 24), (26, 4, 18)): A(f'<circle cx="{x + dx * s:.1f}" cy="{y + dy * s:.1f}" r="{r * s:.1f}" fill="#FFFFFF" opacity=".95"/>')
    elif k == "card":  # one picture card; c = the picture: apple / cup / ball / car / sun / cat
        A(f'<rect x="{x - 28 * s:.1f}" y="{y - 70 * s:.1f}" width="{56 * s:.1f}" height="{70 * s:.1f}" rx="{8 * s:.1f}" fill="#FFFFFF" stroke="#E6DED0" stroke-width="2"/>')
        A(pict(c or "apple", x, y - 35 * s, s * .8))
    elif k == "thing":  # a real object with no card: c = apple / cup / ball / car / sock
        A(pict(c or "apple", x, y - 26 * s, s * 1.2))
    elif k == "sock":
        col = c or "#EE6F9A"
        A(f'<path d="M{x - 10 * s:.1f} {y - 56 * s:.1f} H{x + 10 * s:.1f} V{y - 16 * s:.1f} Q{x + 12 * s:.1f} {y:.1f} {x + 30 * s:.1f} {y - 2 * s:.1f} Q{x + 40 * s:.1f} {y - 8 * s:.1f} {x + 30 * s:.1f} {y - 18 * s:.1f} L{x + 14 * s:.1f} {y - 22 * s:.1f}" fill="none"/>')
        A(f'<path d="M{x - 10 * s:.1f} {y - 56 * s:.1f} H{x + 10 * s:.1f} V{y - 24 * s:.1f} Q{x + 10 * s:.1f} {y - 10 * s:.1f} {x + 24 * s:.1f} {y - 12 * s:.1f} Q{x + 34 * s:.1f} {y - 8 * s:.1f} {x + 26 * s:.1f} {y:.1f} H{x - 4 * s:.1f} Q{x - 10 * s:.1f} {y - 4 * s:.1f} {x - 10 * s:.1f} {y - 14 * s:.1f} Z" fill="{g(col)}"/>')
    elif k == "shirt":
        col = c or "#3E9BE0"
        A(f'<path d="M{x - 30 * s:.1f} {y - 60 * s:.1f} L{x - 12 * s:.1f} {y - 66 * s:.1f} Q{x:.1f} {y - 58 * s:.1f} {x + 12 * s:.1f} {y - 66 * s:.1f} L{x + 30 * s:.1f} {y - 60 * s:.1f} L{x + 40 * s:.1f} {y - 42 * s:.1f} L{x + 26 * s:.1f} {y - 38 * s:.1f} V{y:.1f} H{x - 26 * s:.1f} V{y - 38 * s:.1f} L{x - 40 * s:.1f} {y - 42 * s:.1f} Z" fill="{g(col)}"/>')
    elif k == "box":  # a low storage box
        col = c or "#5BA8E0"
        A(f'<rect x="{x - 50 * s:.1f}" y="{y - 40 * s:.1f}" width="{100 * s:.1f}" height="{40 * s:.1f}" rx="{8 * s:.1f}" fill="{g(col)}"/><rect x="{x - 50 * s:.1f}" y="{y - 40 * s:.1f}" width="{100 * s:.1f}" height="{8 * s:.1f}" rx="4" fill="{light(col, .3)}"/>')
    elif k == "photo":  # a family photo: c = number of people
        n = c or 3
        A(f'<rect x="{x - 46 * s:.1f}" y="{y - 70 * s:.1f}" width="{92 * s:.1f}" height="{70 * s:.1f}" rx="{6 * s:.1f}" fill="{g("#C98A4B")}"/><rect x="{x - 38 * s:.1f}" y="{y - 62 * s:.1f}" width="{76 * s:.1f}" height="{54 * s:.1f}" rx="3" fill="#E6F1FB"/>')
        for i in range(n):
            px = x - (n - 1) * 12 * s + i * 24 * s; big = i < 2
            A(f'<circle cx="{px:.1f}" cy="{y - (44 if big else 34) * s:.1f}" r="{(8 if big else 6) * s:.1f}" fill="{SKIN[i % 2]}"/>'
              f'<rect x="{px - (9 if big else 7) * s:.1f}" y="{y - (36 if big else 28) * s:.1f}" width="{(18 if big else 14) * s:.1f}" height="{(28 if big else 20) * s:.1f}" rx="{6 * s:.1f}" fill="{["#E2728C", "#55607E", "#F2B526", "#4DAF4E"][i % 4]}"/>')
    elif k == "phone":
        A(f'<rect x="{x - 18 * s:.1f}" y="{y - 64 * s:.1f}" width="{36 * s:.1f}" height="{64 * s:.1f}" rx="{8 * s:.1f}" fill="#3B3330"/><rect x="{x - 14 * s:.1f}" y="{y - 58 * s:.1f}" width="{28 * s:.1f}" height="{50 * s:.1f}" rx="4" fill="#E6F1FB"/>'
          f'<circle cx="{x:.1f}" cy="{y - 38 * s:.1f}" r="{8 * s:.1f}" fill="{SKIN[0]}"/><rect x="{x - 9 * s:.1f}" y="{y - 29 * s:.1f}" width="{18 * s:.1f}" height="{14 * s:.1f}" rx="5" fill="#4DAF4E"/>')
    elif k == "notebook":
        A(f'<rect x="{x - 34 * s:.1f}" y="{y - 46 * s:.1f}" width="{68 * s:.1f}" height="{46 * s:.1f}" rx="{5 * s:.1f}" fill="#FFFFFF" stroke="#E6DED0" stroke-width="2"/>')
        for i in range(3): A(f'<path d="M{x - 24 * s:.1f} {y - 34 * s + i * 11 * s:.1f} h{(40 - i * 8) * s:.1f}" stroke="#B9B2A8" stroke-width="{3 * s:.1f}" stroke-linecap="round"/>')
        A(f'<rect x="{x + 22 * s:.1f}" y="{y - 64 * s:.1f}" width="{7 * s:.1f}" height="{40 * s:.1f}" rx="3" fill="#F2B526" transform="rotate(30 {x + 25 * s:.1f} {y - 44 * s:.1f})"/>')
    elif k == "mat":  # a play mat on the floor
        col = c or "#BFE3D6"
        A(f'<rect x="{x - 150 * s:.1f}" y="{y - 6:.1f}" width="{300 * s:.1f}" height="{14:.1f}" rx="7" fill="{g(col)}"/>')
    elif k == "table":  # a low child-height table; y = floor; top at y-120
        A(f'<rect x="{x - 110 * s:.1f}" y="{y - 124:.1f}" width="{220 * s:.1f}" height="{18}" rx="8" fill="{g("#D6A774")}"/>')
        for dx in (-90, 90): A(f'<rect x="{x + dx * s - 8:.1f}" y="{y - 108:.1f}" width="16" height="108" rx="6" fill="{g("#B8854F")}"/>')
    elif k == "stroller":
        A(f'<path d="M{x - 60:.1f} {y - 110:.1f} A60 60 0 0 1 {x + 40:.1f} {y - 150:.1f} L{x + 40:.1f} {y - 90:.1f} Z" fill="{g("#2DB3A6")}"/>'
          f'<rect x="{x - 64:.1f}" y="{y - 96:.1f}" width="{120}" height="40" rx="18" fill="{g("#2DB3A6")}"/><path d="M{x + 56:.1f} {y - 80:.1f} L{x + 90:.1f} {y - 150:.1f}" stroke="#55607E" stroke-width="7" stroke-linecap="round"/>')
        for dx in (-40, 36): A(f'<circle cx="{x + dx:.1f}" cy="{y - 20:.1f}" r="20" fill="#3B3330"/><circle cx="{x + dx:.1f}" cy="{y - 20:.1f}" r="7" fill="#B9B2A8"/>')
    elif k == "road":
        A(f'<rect x="0" y="{y - 4:.1f}" width="{W}" height="60" fill="#B9B2A8"/>')
        for i in range(7): A(f'<rect x="{30 + i * 100}" y="{y + 22:.1f}" width="56" height="8" rx="4" fill="#FFFFFF"/>')
    elif k == "kerb":
        A(f'<rect x="0" y="{y - 10:.1f}" width="{W}" height="12" fill="#D9D4C7"/>')
    elif k == "lantern":
        A(f'<path d="M{x:.1f} {y - 110 * s:.1f} V{y - 90 * s:.1f}" stroke="#B8854F" stroke-width="3"/><ellipse cx="{x:.1f}" cy="{y - 64 * s:.1f}" rx="{30 * s:.1f}" ry="{28 * s:.1f}" fill="{sv.rad("#E84F4F")}"/>'
          f'<rect x="{x - 12 * s:.1f}" y="{y - 96 * s:.1f}" width="{24 * s:.1f}" height="{8 * s:.1f}" rx="3" fill="#F2B526"/><rect x="{x - 12 * s:.1f}" y="{y - 40 * s:.1f}" width="{24 * s:.1f}" height="{8 * s:.1f}" rx="3" fill="#F2B526"/>'
          f'<path d="M{x:.1f} {y - 32 * s:.1f} v{18 * s:.1f}" stroke="#F2B526" stroke-width="3"/>')
    elif k == "dumpling":
        s *= 1.6
        for dx in (-22, 22):
            A(f'<path d="M{x + dx * s - 20 * s:.1f} {y:.1f} Q{x + dx * s:.1f} {y - 34 * s:.1f} {x + dx * s + 20 * s:.1f} {y:.1f} Z" fill="{g("#FFF3E0")}" stroke="#E6D3B8" stroke-width="2"/>')
    elif k == "plate":
        A(f'<ellipse cx="{x:.1f}" cy="{y - 4 * s:.1f}" rx="{44 * s:.1f}" ry="{8 * s:.1f}" fill="#FFFFFF" stroke="#E6DED0" stroke-width="2"/>')
    elif k == "stool":  # a low seat; y = floor
        A(f'<rect x="{x - 40 * s:.1f}" y="{y - 82 * s:.1f}" width="{80 * s:.1f}" height="{16 * s:.1f}" rx="{8 * s:.1f}" fill="{g("#D6A774")}"/>')
        for dx in (-28, 28): A(f'<rect x="{x + dx * s - 6:.1f}" y="{y - 70 * s:.1f}" width="12" height="{70 * s:.1f}" rx="5" fill="{g("#B8854F")}"/>')
    elif k == "mirrorfaces":  # the mirror with faces in it: c = how many (1 or 2)
        obj(sv, "mirror", x, y, s)
        for i in range(c or 1):
            fx = x + (i - ((c or 1) - 1) / 2) * 34 * s; big = (c or 1) == 2 and i == 0
            r = (20 if big else 15) * s; fy = y - (120 if big else 98) * s
            A(f'<circle cx="{fx:.1f}" cy="{fy:.1f}" r="{r:.1f}" fill="{SKIN[0 if big else 1]}" opacity=".85"/><circle cx="{fx - r * .3:.1f}" cy="{fy - r * .1:.1f}" r="{r * .1:.1f}" fill="{INK}"/><circle cx="{fx + r * .3:.1f}" cy="{fy - r * .1:.1f}" r="{r * .1:.1f}" fill="{INK}"/>'
              f'<path d="M{fx - r * .3:.1f} {fy + r * .3:.1f} q{r * .3:.1f} {r * .3:.1f} {r * .6:.1f} 0" stroke="{INK}" stroke-width="2" fill="none"/>')
    elif k == "speaker":
        A(f'<rect x="{x - 26 * s:.1f}" y="{y - 70 * s:.1f}" width="{52 * s:.1f}" height="{70 * s:.1f}" rx="{10 * s:.1f}" fill="{g("#8E6FDB")}"/><circle cx="{x:.1f}" cy="{y - 30 * s:.1f}" r="{16 * s:.1f}" fill="{dark("#8E6FDB", .3)}"/><circle cx="{x:.1f}" cy="{y - 56 * s:.1f}" r="{7 * s:.1f}" fill="{dark("#8E6FDB", .3)}"/>')
    sv.add("".join(out))

def pict(kind, x, y, s):
    """A small picture of a thing, centred on (x, y): for cards, bubbles and real objects."""
    if kind == "apple":
        return (f'<circle cx="{x:.1f}" cy="{y + 2 * s:.1f}" r="{18 * s:.1f}" fill="#E84F4F"/><path d="M{x:.1f} {y - 14 * s:.1f} q{4 * s:.1f} {-10 * s:.1f} {12 * s:.1f} {-10 * s:.1f}" stroke="#4DAF4E" stroke-width="{4 * s:.1f}" fill="none" stroke-linecap="round"/>')
    if kind == "cup":
        return f'<path d="M{x - 14 * s:.1f} {y - 16 * s:.1f} H{x + 14 * s:.1f} L{x + 10 * s:.1f} {y + 18 * s:.1f} H{x - 10 * s:.1f} Z" fill="#2DB3A6"/>'
    if kind == "ball":
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{17 * s:.1f}" fill="#F58A1F"/><path d="M{x - 17 * s:.1f} {y:.1f} Q{x:.1f} {y + 8 * s:.1f} {x + 17 * s:.1f} {y:.1f}" stroke="#FFFFFF" stroke-width="{3 * s:.1f}" fill="none"/>'
    if kind == "car":
        return (f'<rect x="{x - 20 * s:.1f}" y="{y - 6 * s:.1f}" width="{40 * s:.1f}" height="{14 * s:.1f}" rx="{5 * s:.1f}" fill="#3E9BE0"/><rect x="{x - 10 * s:.1f}" y="{y - 16 * s:.1f}" width="{20 * s:.1f}" height="{12 * s:.1f}" rx="{4 * s:.1f}" fill="#3E9BE0"/>'
                f'<circle cx="{x - 11 * s:.1f}" cy="{y + 9 * s:.1f}" r="{5 * s:.1f}" fill="#3B3330"/><circle cx="{x + 11 * s:.1f}" cy="{y + 9 * s:.1f}" r="{5 * s:.1f}" fill="#3B3330"/>')
    if kind == "sun":
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{14 * s:.1f}" fill="#F2B526"/>' + "".join(f'<path d="M{x + math.cos(a) * 19 * s:.1f} {y + math.sin(a) * 19 * s:.1f} L{x + math.cos(a) * 26 * s:.1f} {y + math.sin(a) * 26 * s:.1f}" stroke="#F2B526" stroke-width="{3 * s:.1f}" stroke-linecap="round"/>' for a in [k * math.pi / 4 for k in range(8)])
    if kind == "cat":
        return (f'<circle cx="{x:.1f}" cy="{y + 2 * s:.1f}" r="{15 * s:.1f}" fill="#F58A1F"/><path d="M{x - 13 * s:.1f} {y - 6 * s:.1f} l{2 * s:.1f} {-14 * s:.1f} l{8 * s:.1f} {8 * s:.1f}Z M{x + 13 * s:.1f} {y - 6 * s:.1f} l{-2 * s:.1f} {-14 * s:.1f} l{-8 * s:.1f} {8 * s:.1f}Z" fill="#F58A1F"/>'
                f'<circle cx="{x - 5 * s:.1f}" cy="{y:.1f}" r="{2 * s:.1f}" fill="{INK}"/><circle cx="{x + 5 * s:.1f}" cy="{y:.1f}" r="{2 * s:.1f}" fill="{INK}"/>')
    if kind == "sock":
        return f'<path d="M{x - 6 * s:.1f} {y - 18 * s:.1f} h{12 * s:.1f} v{20 * s:.1f} q0 {8 * s:.1f} {10 * s:.1f} {8 * s:.1f} v{8 * s:.1f} h{-18 * s:.1f} q{-4 * s:.1f} 0 {-4 * s:.1f} {-6 * s:.1f}Z" fill="#EE6F9A"/>'
    if kind == "heart":
        return f'<path d="M{x:.1f} {y + 12 * s:.1f} C{x - 26 * s:.1f} {y - 6 * s:.1f} {x - 10 * s:.1f} {y - 22 * s:.1f} {x:.1f} {y - 8 * s:.1f} C{x + 10 * s:.1f} {y - 22 * s:.1f} {x + 26 * s:.1f} {y - 6 * s:.1f} {x:.1f} {y + 12 * s:.1f} Z" fill="#EE6F9A"/>'
    if kind == "note":
        return f'<path d="M{x - 4 * s:.1f} {y + 10 * s:.1f} V{y - 16 * s:.1f} L{x + 12 * s:.1f} {y - 20 * s:.1f} V{y + 4 * s:.1f}" stroke="#8E6FDB" stroke-width="{4 * s:.1f}" fill="none"/><ellipse cx="{x - 9 * s:.1f}" cy="{y + 11 * s:.1f}" rx="{7 * s:.1f}" ry="{5 * s:.1f}" fill="#8E6FDB"/><ellipse cx="{x + 7 * s:.1f}" cy="{y + 5 * s:.1f}" rx="{7 * s:.1f}" ry="{5 * s:.1f}" fill="#8E6FDB"/>'
    if kind == "dots":
        return "".join(f'<circle cx="{x + dx * s:.1f}" cy="{y:.1f}" r="{4.5 * s:.1f}" fill="#8A7F76"/>' for dx in (-12, 0, 12))
    if kind == "q":
        return f'<path d="M{x - 8 * s:.1f} {y - 8 * s:.1f} q0 {-10 * s:.1f} {9 * s:.1f} {-10 * s:.1f} q{9 * s:.1f} 0 {9 * s:.1f} {9 * s:.1f} q0 {7 * s:.1f} {-9 * s:.1f} {11 * s:.1f} v{4 * s:.1f}" stroke="#3E9BE0" stroke-width="{4.5 * s:.1f}" fill="none" stroke-linecap="round"/><circle cx="{x + 1 * s:.1f}" cy="{y + 16 * s:.1f}" r="{3 * s:.1f}" fill="#3E9BE0"/>'
    if kind == "sad":
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{16 * s:.1f}" fill="#5BA8E0"/><circle cx="{x - 6 * s:.1f}" cy="{y - 4 * s:.1f}" r="{2.4 * s:.1f}" fill="#FFFFFF"/><circle cx="{x + 6 * s:.1f}" cy="{y - 4 * s:.1f}" r="{2.4 * s:.1f}" fill="#FFFFFF"/><path d="M{x - 7 * s:.1f} {y + 9 * s:.1f} q{7 * s:.1f} {-7 * s:.1f} {14 * s:.1f} 0" stroke="#FFFFFF" stroke-width="{2.6 * s:.1f}" fill="none" stroke-linecap="round"/>'
    if kind == "happy":
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{16 * s:.1f}" fill="#F2B526"/><circle cx="{x - 6 * s:.1f}" cy="{y - 4 * s:.1f}" r="{2.4 * s:.1f}" fill="{INK}"/><circle cx="{x + 6 * s:.1f}" cy="{y - 4 * s:.1f}" r="{2.4 * s:.1f}" fill="{INK}"/><path d="M{x - 7 * s:.1f} {y + 5 * s:.1f} q{7 * s:.1f} {7 * s:.1f} {14 * s:.1f} 0" stroke="{INK}" stroke-width="{2.6 * s:.1f}" fill="none" stroke-linecap="round"/>'
    if kind == "zh":  # the sound of one language
        return f'<rect x="{x - 16 * s:.1f}" y="{y - 14 * s:.1f}" width="{32 * s:.1f}" height="{28 * s:.1f}" rx="{6 * s:.1f}" fill="#E84F4F"/><circle cx="{x:.1f}" cy="{y:.1f}" r="{6 * s:.1f}" fill="#F2B526"/>'
    if kind == "en":
        return f'<rect x="{x - 16 * s:.1f}" y="{y - 14 * s:.1f}" width="{32 * s:.1f}" height="{28 * s:.1f}" rx="{6 * s:.1f}" fill="#3E9BE0"/><path d="M{x - 9 * s:.1f} {y:.1f} h{18 * s:.1f} M{x:.1f} {y - 8 * s:.1f} v{16 * s:.1f}" stroke="#FFFFFF" stroke-width="{3.6 * s:.1f}" stroke-linecap="round"/>'
    if kind == "moon":
        return f'<path d="M{x + 6 * s:.1f} {y - 16 * s:.1f} A16 16 0 1 0 {x + 8 * s:.1f} {y + 14 * s:.1f} A12 12 0 1 1 {x + 6 * s:.1f} {y - 16 * s:.1f} Z" fill="#F2B526"/>'
    if kind == "hand":
        return f'<circle cx="{x:.1f}" cy="{y + 4 * s:.1f}" r="{11 * s:.1f}" fill="{SKIN[0]}"/>' + "".join(f'<rect x="{x + dx * s - 3 * s:.1f}" y="{y - 16 * s:.1f}" width="{6 * s:.1f}" height="{16 * s:.1f}" rx="{3 * s:.1f}" fill="{SKIN[0]}"/>' for dx in (-8, -3, 2, 7))
    if kind == "scribble":
        return "".join(f'<path d="M{x - 18 * s:.1f} {y + (i * 9 - 9) * s:.1f} q{9 * s:.1f} {-12 * s:.1f} {18 * s:.1f} 0 t{18 * s:.1f} 0" stroke="{c}" stroke-width="{4 * s:.1f}" fill="none" stroke-linecap="round"/>' for i, c in enumerate(["#E84F4F", "#3E9BE0", "#4DAF4E"]))
    if kind == "tower":
        return "".join(f'<rect x="{x - 10 * s:.1f}" y="{y + 8 * s - i * 14 * s:.1f}" width="{20 * s:.1f}" height="{13 * s:.1f}" rx="{3 * s:.1f}" fill="{c}"/>' for i, c in enumerate(["#3E9BE0", "#F2B526", "#E84F4F"]))
    if kind == "leaf":
        return f'<path d="M{x:.1f} {y + 16 * s:.1f} C{x - 16 * s:.1f} {y + 4 * s:.1f} {x - 12 * s:.1f} {y - 14 * s:.1f} {x:.1f} {y - 18 * s:.1f} C{x + 12 * s:.1f} {y - 14 * s:.1f} {x + 16 * s:.1f} {y + 4 * s:.1f} {x:.1f} {y + 16 * s:.1f} Z" fill="#F58A1F"/>'
    if kind == "eye":
        return f'<path d="M{x - 18 * s:.1f} {y:.1f} Q{x:.1f} {y - 16 * s:.1f} {x + 18 * s:.1f} {y:.1f} Q{x:.1f} {y + 16 * s:.1f} {x - 18 * s:.1f} {y:.1f} Z" fill="#FFFFFF" stroke="#3E9BE0" stroke-width="{3 * s:.1f}"/><circle cx="{x:.1f}" cy="{y:.1f}" r="{6 * s:.1f}" fill="#3E9BE0"/>'
    if kind == "bird":
        return f'<ellipse cx="{x:.1f}" cy="{y + 2 * s:.1f}" rx="{14 * s:.1f}" ry="{10 * s:.1f}" fill="#3E9BE0"/><circle cx="{x + 10 * s:.1f}" cy="{y - 6 * s:.1f}" r="{7 * s:.1f}" fill="#3E9BE0"/><path d="M{x + 16 * s:.1f} {y - 6 * s:.1f} l{6 * s:.1f} {2 * s:.1f} l{-6 * s:.1f} {2 * s:.1f}Z" fill="#F2B526"/>'
    if kind == "shirt":
        return f'<path d="M{x - 14 * s:.1f} {y - 14 * s:.1f} L{x - 5 * s:.1f} {y - 17 * s:.1f} Q{x:.1f} {y - 13 * s:.1f} {x + 5 * s:.1f} {y - 17 * s:.1f} L{x + 14 * s:.1f} {y - 14 * s:.1f} L{x + 19 * s:.1f} {y - 5 * s:.1f} L{x + 12 * s:.1f} {y - 3 * s:.1f} V{y + 15 * s:.1f} H{x - 12 * s:.1f} V{y - 3 * s:.1f} L{x - 19 * s:.1f} {y - 5 * s:.1f} Z" fill="#3E9BE0"/>'
    if kind == "check":
        return f'<path d="M{x - 10 * s:.1f} {y:.1f} l{7 * s:.1f} {7 * s:.1f} l{13 * s:.1f} {-14 * s:.1f}" stroke="#4DAF4E" stroke-width="{5 * s:.1f}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    if kind == "stop":
        return f'<rect x="{x - 9 * s:.1f}" y="{y - 12 * s:.1f}" width="{6 * s:.1f}" height="{24 * s:.1f}" rx="{2 * s:.1f}" fill="#E84F4F"/><rect x="{x + 3 * s:.1f}" y="{y - 12 * s:.1f}" width="{6 * s:.1f}" height="{24 * s:.1f}" rx="{2 * s:.1f}" fill="#E84F4F"/>'
    if kind == "people":
        return f'<circle cx="{x - 9 * s:.1f}" cy="{y - 6 * s:.1f}" r="{6 * s:.1f}" fill="{SKIN[0]}"/><circle cx="{x + 9 * s:.1f}" cy="{y - 2 * s:.1f}" r="{5 * s:.1f}" fill="{SKIN[1]}"/><rect x="{x - 16 * s:.1f}" y="{y + 1 * s:.1f}" width="{14 * s:.1f}" height="{14 * s:.1f}" rx="{5 * s:.1f}" fill="#E2728C"/><rect x="{x + 3 * s:.1f}" y="{y + 4 * s:.1f}" width="{12 * s:.1f}" height="{11 * s:.1f}" rx="{4 * s:.1f}" fill="#F2B526"/>'
    if kind == "lantern":
        return f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{16 * s:.1f}" ry="{14 * s:.1f}" fill="#E84F4F"/><rect x="{x - 6 * s:.1f}" y="{y - 18 * s:.1f}" width="{12 * s:.1f}" height="{5 * s:.1f}" fill="#F2B526"/>'
    if kind == "bowl":
        return f'<path d="M{x - 16 * s:.1f} {y - 4 * s:.1f} Q{x:.1f} {y + 18 * s:.1f} {x + 16 * s:.1f} {y - 4 * s:.1f} Z" fill="#2DB3A6"/><circle cx="{x - 4 * s:.1f}" cy="{y - 6 * s:.1f}" r="{5 * s:.1f}" fill="#F2B526"/>'
    if kind == "drop":
        return f'<path d="M{x:.1f} {y - 16 * s:.1f} Q{x + 14 * s:.1f} {y + 2 * s:.1f} {x:.1f} {y + 12 * s:.1f} Q{x - 14 * s:.1f} {y + 2 * s:.1f} {x:.1f} {y - 16 * s:.1f} Z" fill="#5BA8E0"/>'
    if kind == "bed":
        return f'<rect x="{x - 18 * s:.1f}" y="{y - 2 * s:.1f}" width="{36 * s:.1f}" height="{12 * s:.1f}" rx="{4 * s:.1f}" fill="#8E6FDB"/><circle cx="{x - 10 * s:.1f}" cy="{y - 6 * s:.1f}" r="{6 * s:.1f}" fill="{SKIN[1]}"/>'
    return ""

# ---------- marks ----------
VIEW = {"z": 1.0, "cx": 380}
def inside(x, y, r):
    """Moves a mark's centre so a circle of radius r stays inside the visible frame."""
    z, cx = VIEW["z"], VIEW["cx"]
    x0, x1 = cx - cx / z + r + 6, cx + (W - cx) / z - r - 6
    y0 = GROUND - GROUND / z + r + 6
    return min(max(x, x0), x1), max(y, y0)

def mark(sv, m, ppl):
    k = m["k"]
    def pt(v):
        if isinstance(v, str):
            who, part = (v.split(".") + ["head"])[:2]
            p = ppl[who]
            if part == "head": return p.head()
            if part == "hand": return p.hand(0)
            if part == "hand2": return p.hand(1)
            if part == "mouth": return add(p.head(), (p.f * p.d["head"] * .9, p.d["head"] * .3))
        return tuple(v)
    if k == "say":  # a speech bubble from a mouth, with a small picture in it
        a = pt(m.get("from", "adult.mouth")); side = m.get("side", 1)
        r = 36 * m.get("s", 1)
        bx, by = inside(a[0] + side * m.get("dx", 64), a[1] - m.get("dy", 70), r * 1.25)
        sv.add(f'<path d="M{a[0] + side * 14:.1f} {a[1] - 14:.1f} L{bx - side * r * .5:.1f} {by + r * .5:.1f} L{bx - side * r * .05:.1f} {by + r * .75:.1f} Z" fill="#FFFFFF"/>')
        sv.add(f'<ellipse cx="{bx:.1f}" cy="{by:.1f}" rx="{r * 1.2:.1f}" ry="{r:.1f}" fill="#FFFFFF" stroke="#EDE5D8" stroke-width="2"/>')
        syms = m.get("sym", "dots")
        syms = syms if isinstance(syms, list) else [syms]
        for i, sy in enumerate(syms):
            sv.add(pict(sy, bx + (i - (len(syms) - 1) / 2) * r * .95, by, r / 30 * (0.9 if len(syms) > 1 else 1.05)))
    elif k == "sound":  # waves out from a point
        a = pt(m["at"]); d = m.get("dir", 1)
        for i in range(3):
            r = 18 + i * 14
            sv.add(f'<path d="M{a[0] + d * r * .5:.1f} {a[1] - r * .8:.1f} A{r} {r} 0 0 {1 if d > 0 else 0} {a[0] + d * r * .5:.1f} {a[1] + r * .8:.1f}" fill="none" stroke="{m.get("c", "#8E6FDB")}" stroke-width="5" stroke-linecap="round" opacity="{1 - i * .25:.2f}"/>')
    elif k == "look":  # a dotted line of sight
        a, b = pt(m["a"]), pt(m["b"])
        sv.add(f'<path d="M{a[0]:.1f} {a[1]:.1f} L{b[0]:.1f} {b[1]:.1f}" stroke="{m.get("c", "#3E9BE0")}" stroke-width="5" stroke-dasharray="1 13" stroke-linecap="round" fill="none"/>')
    elif k == "arrow":  # a motion arrow along a gentle curve
        a, b = pt(m["a"]), pt(m["b"]); bend = m.get("bend", -40); c = m.get("c", "#F58A1F")
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + bend
        sv.add(f'<path d="M{a[0]:.1f} {a[1]:.1f} Q{mx:.1f} {my:.1f} {b[0]:.1f} {b[1]:.1f}" stroke="{c}" stroke-width="6" fill="none" stroke-linecap="round" stroke-dasharray="{m.get("dash", "0")}"/>')
        ang = math.atan2(b[1] - my, b[0] - mx)
        p1 = (b[0] - 16 * math.cos(ang - .5), b[1] - 16 * math.sin(ang - .5)); p2 = (b[0] - 16 * math.cos(ang + .5), b[1] - 16 * math.sin(ang + .5))
        sv.add(f'<path d="M{p1[0]:.1f} {p1[1]:.1f} L{b[0]:.1f} {b[1]:.1f} L{p2[0]:.1f} {p2[1]:.1f}" stroke="{c}" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
        if m.get("twoway"):
            ang2 = math.atan2(a[1] - my, a[0] - mx)
            q1 = (a[0] - 16 * math.cos(ang2 - .5), a[1] - 16 * math.sin(ang2 - .5)); q2 = (a[0] - 16 * math.cos(ang2 + .5), a[1] - 16 * math.sin(ang2 + .5))
            sv.add(f'<path d="M{q1[0]:.1f} {q1[1]:.1f} L{a[0]:.1f} {a[1]:.1f} L{q2[0]:.1f} {q2[1]:.1f}" stroke="{c}" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    elif k == "badge":  # a round sign floating near something: pause, heart, check, repeat, clock, stop
        a = pt(m["at"]); r = 26 * m.get("s", 1); a = inside(a[0] + m.get("dx", 0), a[1] + m.get("dy", -60), r)
        sv.add(f'<circle cx="{a[0]:.1f}" cy="{a[1] + 3:.1f}" r="{r:.1f}" fill="#5A3A20" opacity=".08"/><circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{r:.1f}" fill="#FFFFFF"/>')
        sy = m["sym"]
        if sy == "pause":
            sv.add(f'<rect x="{a[0] - r * .36:.1f}" y="{a[1] - r * .42:.1f}" width="{r * .24:.1f}" height="{r * .84:.1f}" rx="3" fill="#8E6FDB"/><rect x="{a[0] + r * .12:.1f}" y="{a[1] - r * .42:.1f}" width="{r * .24:.1f}" height="{r * .84:.1f}" rx="3" fill="#8E6FDB"/>')
        elif sy == "repeat":
            sv.add(f'<path d="M{a[0] - r * .5:.1f} {a[1]:.1f} A{r * .5:.1f} {r * .5:.1f} 0 1 1 {a[0]:.1f} {a[1] + r * .5:.1f}" stroke="#2DB3A6" stroke-width="{r * .16:.1f}" fill="none" stroke-linecap="round"/><path d="M{a[0] - r * .74:.1f} {a[1] - r * .16:.1f} L{a[0] - r * .5:.1f} {a[1] + r * .12:.1f} L{a[0] - r * .24:.1f} {a[1] - r * .16:.1f}" stroke="#2DB3A6" stroke-width="{r * .16:.1f}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
        elif sy == "clock":
            sv.add(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{r * .55:.1f}" fill="none" stroke="#F58A1F" stroke-width="{r * .13:.1f}"/><path d="M{a[0]:.1f} {a[1] - r * .32:.1f} V{a[1]:.1f} H{a[0] + r * .24:.1f}" stroke="#F58A1F" stroke-width="{r * .13:.1f}" fill="none" stroke-linecap="round"/>')
        elif sy == "grow":  # short, longer, longest
            for i in range(3): sv.add(f'<rect x="{a[0] - r * .5 + i * r * .36:.1f}" y="{a[1] + r * .4 - (i + 1) * r * .26:.1f}" width="{r * .24:.1f}" height="{(i + 1) * r * .26:.1f}" rx="2" fill="#4DAF4E"/>')
        elif sy == "two":  # two choices
            sv.add(f'<circle cx="{a[0] - r * .3:.1f}" cy="{a[1]:.1f}" r="{r * .24:.1f}" fill="#3E9BE0"/><circle cx="{a[0] + r * .3:.1f}" cy="{a[1]:.1f}" r="{r * .24:.1f}" fill="#EE6F9A"/>')
        else:
            sv.add(pict(sy, a[0], a[1], r / 26 * .95))
    elif k == "sparkle":
        a = pt(m["at"])
        for dx, dy, r in ((0, 0, 9), (22, -16, 6), (-18, -22, 5)):
            x, y = a[0] + dx, a[1] + dy
            sv.add(f'<path d="M{x:.1f} {y - r * 1.6:.1f} Q{x:.1f} {y:.1f} {x + r * 1.6:.1f} {y:.1f} Q{x:.1f} {y:.1f} {x:.1f} {y + r * 1.6:.1f} Q{x:.1f} {y:.1f} {x - r * 1.6:.1f} {y:.1f} Q{x:.1f} {y:.1f} {x:.1f} {y - r * 1.6:.1f} Z" fill="{m.get("c", "#F2B526")}"/>')
    elif k == "zz":
        a = pt(m["at"])
        for i, s in enumerate((1, .75, .55)):
            x, y = a[0] + i * 20, a[1] - i * 22
            sv.add(f'<path d="M{x:.1f} {y:.1f} h{14 * s:.1f} l{-14 * s:.1f} {14 * s:.1f} h{14 * s:.1f}" stroke="#8E6FDB" stroke-width="{4 * s:.1f}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    elif k == "hands_cover":  # both adult hands over the face
        p = ppl[m.get("who", "adult")]; c = p.head(); r = p.d["head"]
        for dy in (-.25, .25):
            sv.add(f'<ellipse cx="{c[0] + p.f * r * .62:.1f}" cy="{c[1] + dy * r:.1f}" rx="{r * .42:.1f}" ry="{r * .3:.1f}" fill="{sv.rad(p.skin)}"/>')

# ---------- a scene ----------
def scene(spec, area, sv=None):
    sv = sv or SVG()
    ground, back = AREA[area]
    setting = spec.get("set", "floor")
    sv.add(f'<rect width="{W}" height="{H}" fill="{PAPER}"/>')
    if setting == "outdoor":
        sv.add(f'<rect width="{W}" height="{GROUND}" fill="#E6F2F8"/>')
        sv.add(f'<path d="M0 {GROUND - 40} Q{W * .3} {GROUND - 90} {W * .62} {GROUND - 50} T{W} {GROUND - 60} V{H} H0 Z" fill="#CFE6B8"/>')
        sv.add(f'<rect y="{GROUND}" width="{W}" height="{H - GROUND}" fill="#B9DA9C"/>')
    else:
        # a soft disc of the area colour behind the action, and the floor
        sv.add(f'<circle cx="{spec.get("disc", 360)}" cy="{GROUND - 150}" r="210" fill="{back}"/>')
        sv.add(f'<ellipse cx="360" cy="{GROUND + 18}" rx="330" ry="56" fill="{ground}"/>')
    z = spec.get("zoom", 1.32); cx0 = spec.get("cx", 380); VIEW.update(z=z, cx=cx0)
    sv.add(f'<g transform="translate({cx0} {GROUND}) scale({z}) translate({-cx0} {-GROUND})">')
    ppl = {}
    for who in ("adult", "child", "peer", "adult2"):
        if who in spec:
            q = dict(spec[who]); kind = "adult" if who.startswith("adult") else "child"
            ppl[who] = q
    # resolve looks and hands that name another person or thing
    things = {f"o{i}": (o.get("x", 360), o.get("y", GROUND) - o.get("h", 40)) for i, o in enumerate(spec.get("objs", []))}
    built = {}
    def resolve(v, others):
        if v is None or isinstance(v, (list, tuple)) and not isinstance(v, str): return tuple(v) if v is not None else None
        if v in things: return things[v]
        who, part = (v.split(".") + ["head"])[:2]
        p = others.get(who)
        if not p: return None
        if part == "head": return p.head()
        if part == "hand": return p.hand(0)
        if part == "hand2": return p.hand(1)
        if part == "knee": return p.legs[0][0]
        if part == "lap": return ((p.hip[0] + p.legs[0][0][0]) / 2, min(p.hip[1], p.legs[0][0][1]) - p.d["lw"] * .6)
        if part == "chest": return ((p.hip[0] + p.sh[0]) / 2 + p.f * p.d["tw"] * .3, (p.hip[1] + p.sh[1]) / 2)
        if part == "under" and p.pose == "bundle": return (p.bundle_c[0] - p.f * 10, p.bundle_c[1] + p.d["tw"] * .55)
        if part == "under2" and p.pose == "bundle": return (p.bundle_c[0] + p.f * p.d["torso"] * .5, p.bundle_c[1] + p.d["tw"] * .4)
        if part == "back": return ((p.hip[0] + p.sh[0]) / 2 - p.f * p.d["tw"] * .2, (p.hip[1] + p.sh[1]) / 2 - p.d["tw"] * .3)
        return p.hip
    # two passes: first without cross-references, then with them
    for pas in (0, 1):
        for who, q in ppl.items():
            kind = "adult" if who.startswith("adult") else "child"
            hands = [resolve(h, built) if pas else (tuple(h) if isinstance(h, list) else (things.get(h) if isinstance(h, str) and h in things else None)) for h in q.get("hands", [None, None])]
            look = resolve(q.get("look"), built) if pas else None
            top = q.get("top") or (PEER_TOP if who == "peer" else "#6FA8DC" if who == "adult2" else None)
            leg = q.get("leg") or (PEER_LEG if who == "peer" else "#4A4C43" if who == "adult2" else None)
            built[who] = Person(kind, q["pose"], q["x"], face=q.get("f", 1 if kind == "adult" else -1), age=q.get("age", 30),
                                top=top, leg=leg, expr=q.get("e", "smile"), look=look, hands=hands, hair=q.get("hair"),
                                at=tuple(q["at"]) if "at" in q else None, tilt=q.get("tilt", 0))
    # back objects (scenery), shadows, people and front objects
    for o in spec.get("objs", []):
        if o.get("back"): obj(sv, o["k"], o.get("x", 360), o.get("y", GROUND), o.get("s", 1), o.get("c"), o.get("r", 0))
    for p in built.values():
        if p.pose == "bundle": pass
        elif p.pose not in ("prone", "lieback"): p.draw_shadow(sv)
        else: sv.shadow(p.hip[0] - p.f * p.d["torso"] * .4, GROUND + 4, p.d["torso"] * 1.1, 10)
    for o in spec.get("objs", []):
        if not o.get("back") and not o.get("front") and not o.get("on"):
            if o.get("y", GROUND) >= GROUND - 2: sv.shadow(o.get("x", 360), GROUND + 3, 46 * o.get("s", 1), 8, .12)
            obj(sv, o["k"], o.get("x", 360), o.get("y", GROUND), o.get("s", 1), o.get("c"), o.get("r", 0))
    order = spec.get("order", ["adult2", "peer", "child", "adult"] if spec.get("child_front") else ["adult2", "adult", "peer", "child"])
    for who in order:
        if who in built: built[who].draw(sv)
    for o in spec.get("objs", []):
        if o.get("front"): obj(sv, o["k"], o.get("x", 360), o.get("y", GROUND), o.get("s", 1), o.get("c"), o.get("r", 0))
        if o.get("on"):  # held: the hand is at the middle of the thing
            hx, hy = resolve(o["on"], built)
            obj(sv, o["k"], hx + o.get("dx", 0), hy + o.get("h", 30) * o.get("s", 1) + o.get("dy", 0), o.get("s", 1), o.get("c"), o.get("r", 0))
    for m in spec.get("marks", []): mark(sv, m, built)
    if spec.get("companions"): companions(sv, 540, GROUND + 2, 0.8, look=(-0.9, 0.1))
    sv.add('</g>')
    return sv

def render(svg, path, width=1440):
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=width)
    im = Image.open(io.BytesIO(png)).convert("RGB")
    im.save(path, "WEBP", quality=88, method=6)
    return im.size

# ---------- the companions (the app's own shapes, tools/mint.json), with the same soft volume ----------
MINT = json.load(open(os.path.join(ROOT, "tools", "mint.json")))
MOSS_BODY = "M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z"
MOSS_TUFTS = "M24 52 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M64 44 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M70 72 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M28 72 c2 -2 5 -2 7 0 c-2 1.6 -5 1.6 -7 0Z"
OTTO_BODY = "M30 84 C25 74 24 58 26 44 C28 28 38 16 52 16 C65 17 74 28 75 44 C76 60 74 75 70 84 C60 88 40 88 30 84Z"
OTTO_DIP = "M25.2 64 C35 68 64 68 75.4 63 C75 71 73 78 70 84 C60 88 40 88 30 84 C27.6 78 26 71 25.2 64Z"

def companions(sv, x, base, k, look=(-1, 0)):
    """Otto a step behind, Moss in front, feet on `base`; both look the way of `look`."""
    lx, ly = look
    def legs(xs): return "".join(f'<rect x="{a}" y="80" width="6.5" height="10" rx="3.2" fill="#1C1D19"/>' for a in xs)
    def eye(cx, cy, rx, ry, pr, lid=0):
        px, py = cx + lx * (rx - pr - .4), cy + ly * (ry - pr - .4)
        e = f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#FBF9F3"/><circle cx="{px:.1f}" cy="{py:.1f}" r="{pr}" fill="#1C1D19"/><circle cx="{px - pr * .35:.1f}" cy="{py - pr * .35:.1f}" r="{pr * .3:.1f}" fill="#FFFFFF"/>'
        if lid: e += f'<path d="M{cx - rx - .5},{cy - ry - .5} H{cx + rx + .5} V{cy - ry + ry * 2 * lid} H{cx - rx - .5}Z" fill="#2D4A8C"/>'
        return e
    sv.shadow(x + 18 * k, base + 2, 60 * k, 9 * k)
    ox = x + 34 * k
    sv.add(f'<g transform="translate({ox - 50 * k * .82:.1f} {base - 90 * k * .82:.1f}) scale({k * .82:.3f})">'
           f'<path d="M53 17 C54 12 57 8 61 6" stroke="#1F3566" stroke-width="2.2" fill="none" stroke-linecap="round"/><circle cx="62" cy="5.8" r="3.2" fill="#D4A21C"/>'
           f'{legs((38, 56))}<path d="{OTTO_BODY}" fill="{sv.rad("#2D4A8C")}"/>'
           f'<path d="{OTTO_DIP}" fill="#1F3566" fill-opacity=".55"/>{eye(51, 44, 12.5, 11.5, 7.1, .34)}<circle cx="74" cy="70" r="6.2" fill="{sv.rad("#D4A21C")}"/></g>')
    leaves = "".join(f'<path d="{m[0]}" fill="{c}"/>' for m, c in zip([MINT[1], MINT[0], MINT[3], MINT[2]], ["#7FCBA0", "#4FAE7F", "#A9E0C0", "#A9E0C0"]))
    sv.add(f'<g transform="translate({x - 50 * k:.1f} {base - 90 * k:.1f}) scale({k:.3f})">'
           f'<path d="M49 36 C48 30 49.2 23 50 17.6" stroke="#3D5434" stroke-width="2.2" fill="none" stroke-linecap="round"/>{leaves}'
           f'{legs((33, 59))}<path d="{MOSS_BODY}" fill="{sv.rad("#55704A")}"/>'
           f'<path d="{MOSS_TUFTS}" fill="#88A06C" fill-opacity=".7"/>{eye(43, 55, 6.4, 7.4, 4.0)}{eye(58, 55, 6.4, 7.4, 4.0)}</g>')

# ---------- covers ----------
def child_pose_at(m):
    return ("lieback" if m < 3 else "prone" if m < 6 else "sit" if m < 9 else "crawl" if m < 12 else "stand" if m < 18 else "walk" if m < 30 else "run")

SCENERY = {"mat", "table", "stool", "road", "kerb", "tree", "sun", "cloud", "stroller", "box", "card", "paper"}
def cover_spec(m, mo, scenes=None):
    feature = next((a for a in C["activities"] if a["code"] == mo.get("feature")), None)
    pose = child_pose_at(m)
    # the month's feature play lends its main material, set on the floor between the two
    thing = None
    for o in ((scenes or {}).get(feature["code"], [{}])[0].get("objs", []) if feature else []):
        if o["k"] not in SCENERY: thing = dict(k=o["k"], x=360, s=min(1.0, o.get("s", 1) * 1.1), c=o.get("c")); break
    spec = {"set": "floor", "adult": {"pose": "kneel" if m < 12 else "tallkneel", "x": 230, "e": "smile", "look": "child.head",
                                      "hands": ["child.hand", None] if pose in ("stand", "walk") else [None, None]},
            "child": {"pose": pose, "x": 430 if pose not in ("lieback", "prone") else 450, "age": m, "e": "wow" if m < 6 else "smile", "look": "adult.head",
                      "hands": ["adult.hand", None] if pose in ("stand", "walk") else [None, None]}, "objs": [thing] if thing else [], "companions": True}
    if pose in ("lieback",): spec["child"]["at"] = [450, 440]
    if thing: thing["x"] = 330
    return spec, area_of(feature) if feature else "A"

# ---------- main ----------
def rig_sheet(out):
    """Every pose (adult and child at 3, 9, 24 months) and every material, for checking the rig."""
    tiles = []
    for pose in POSES:
        sv = SVG()
        sv.add(f'<rect width="{W}" height="{H}" fill="{PAPER}"/><text x="20" y="40" font-size="28" fill="#999">{pose}</text>')
        a = Person("adult", pose, 200, look=(600, 300)); a.draw_shadow(sv); a.draw(sv)
        for x, age in ((420, 3), (530, 10), (640, 26)):
            c = Person("child", pose, x, face=-1, age=age, look=(200, 300)); c.draw_shadow(sv); c.draw(sv)
        tiles.append(sv.svg())
    mats = ["block", "blocks", "tumble", "ball", "rattle", "cloth", "cloth2", "mirror", "book", "bookopen", "basket", "cup", "drum",
            "crayon", "doll", "dollbed", "pot", "bowl", "cushion", "car", "tree", "leaf", "flower", "bird", "card", "sock", "shirt",
            "box", "photo", "phone", "notebook", "lantern", "dumpling", "speaker"]
    for i in range(0, len(mats), 6):
        sv = SVG(); sv.add(f'<rect width="{W}" height="{H}" fill="{PAPER}"/>')
        for j, k in enumerate(mats[i:i + 6]):
            x = 120 + (j % 3) * 240; y = 240 + (j // 3) * 250
            obj(sv, k, x, y); sv.add(f'<text x="{x - 40}" y="{y + 30}" font-size="22" fill="#999">{k}</text>')
        tiles.append(sv.svg())
    ims = [Image.open(io.BytesIO(cairosvg.svg2png(bytestring=t.encode(), output_width=480))) for t in tiles]
    cols = 4; rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 480, rows * 360), "white")
    for k, im in enumerate(ims): sheet.paste(im, ((k % cols) * 480, (k // cols) * 360))
    sheet.save(out)

def main():
    if "--rig" in sys.argv: return rig_sheet(sys.argv[sys.argv.index("--rig") + 1])
    scenes = json.load(open(SCENES))
    only = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else None
    os.makedirs(OUT, exist_ok=True)
    ipath = os.path.join(OUT, "index.json")
    index = json.load(open(ipath)) if os.path.exists(ipath) else {"plays": {}, "covers": {}, "size": {}}
    missing = []
    for p in C["activities"]:
        if only and p["code"] not in only: continue
        area = area_of(p); names = []
        for i, t in enumerate(p["steps"]):
            spec = scenes.get(p["code"], [None] * len(p["steps"]))
            if i >= len(spec) or spec[i] is None: missing.append(f'{p["code"]}.{i + 1}'); continue
            n = f"play_{p['code'].lower()}_{i + 1}.webp"
            index["size"][n] = list(render(scene(spec[i], area).svg(), os.path.join(OUT, n))); names.append(n)
        index["plays"][p["code"]] = names
    if not only:
        for mo in C["months"]:
            spec, area = cover_spec(mo["month"], mo, scenes)
            n = "cover_%02d.webp" % mo["month"]
            sv = scene(spec, area); sv.w, sv.h = W, H
            index["size"][n] = list(render(sv.svg(), os.path.join(OUT, n)))
            index["covers"][str(mo["month"])] = n
    json.dump(index, open(ipath, "w"), separators=(",", ":"))
    if missing: print("no scene for", ", ".join(missing))
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        codes = [c for c in index["plays"] if not only or c in only]
        rows = [[n for n in index["plays"][c]] for c in codes]
        cols = max(len(r) for r in rows)
        sheet = Image.new("RGB", (cols * 360, len(rows) * 270), "white")
        for r, row in enumerate(rows):
            for k, n in enumerate(row): sheet.paste(Image.open(os.path.join(OUT, n)).resize((360, 270)), (k * 360, r * 270))
        sheet.save(out)

if __name__ == "__main__":
    main()
