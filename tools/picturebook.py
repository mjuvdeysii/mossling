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
# the paper, the disc and the floor drawn in 2D; off when the 3D stage (tools/stage3d.py) is laid behind instead
BACKDROP = True
SKIN = ["#F2CDA8", "#D9A57C"]           # adult, child (two warm tones so the two read apart)
HAIR = {"adult": "#4A3428", "child": "#6B4A32"}
ADULT_TOP, ADULT_LEG = "#FF6F91", "#3E5A86"
CHILD_TOP, CHILD_LEG = "#FFC23D", "#1FB5A6"
# the girl (--girl): the same child, drawn as a girl — a lilac top, a red bow, and pigtails once there is hair for them
GIRL = "--girl" in sys.argv
GIRL_TOP, BOW = "#B39CF4", "#F2554B"
SUFFIX = "_g" if GIRL else ""
# the 2D style (the app's 平面 setting): the same drawings under "2d_" names, finished for print (finish2d), with the
# companions left out of the pictures as in the 3D style
FLAT = "--2d" in sys.argv
PREFIX = "2d_" if FLAT else ""
# the 2D style chosen: strong jelly candy — light 3D on a 2D drawing, a strong gloss, rich colour (JELLY 0 gives the
# plain flat drawing with contour and grain; 1 a lighter gloss)
JELLY = float(sys.argv[sys.argv.index("--jelly") + 1]) if "--jelly" in sys.argv else 1.8
SATURATE = 1.4 if JELLY > 0 else 1.0
PEER_TOP, PEER_LEG = "#4C9BE8", "#F2554B"
# the app's six areas (Theme.swift Palette.area): teal, orange, yellow, pink, blue, red — as (ground, backdrop) tints
AREA_FILL = {"A": "#1FB5A6", "B": "#FF8A3D", "C": "#FFC23D", "D": "#FF6F91", "E": "#4C9BE8", "F": "#F2554B"}
def _tint(c, t):
    a = [int(c[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (255 - x) * t):02X}" for x in a)
AREA = {k: (_tint(v, .5), _tint(v, .76)) for k, v in AREA_FILL.items()}   # floor and backdrop: tints deep enough to hold the figures
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
def vivid(c, k=None):
    """The same colour, more saturated (the 2D style's rich colour), lightness kept."""
    import colorsys
    if not (isinstance(c, str) and c.startswith("#") and len(c) == 7): return c
    r, g, b = (int(c[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s_ = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(h, l, min(1.0, s_ * (SATURATE if k is None else k)))
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))

class SVG:
    def __init__(s, w=W, h=H): s.w, s.h, s.defs, s.body, s.n = w, h, [], [], 0
    def id(s): s.n += 1; return f"g{s.n}"
    def add(s, x): s.body.append(x)
    def lin(s, c, angle=135):
        i = s.id(); r = math.radians(angle)
        x1, y1 = 0.5 - math.cos(r) / 2, 0.5 - math.sin(r) / 2
        if FLAT and JELLY > 0:
            # jelly: a bright lit side, the colour at full strength, a deeper core, and light glowing back out at the
            # far edge, as through a soft translucent sweet
            c = vivid(c)
            s.defs.append(f'<linearGradient id="{i}" x1="{x1:.2f}" y1="{y1:.2f}" x2="{1 - x1:.2f}" y2="{1 - y1:.2f}">'
                          f'<stop offset="0" stop-color="{light(c, .42)}"/><stop offset=".3" stop-color="{c}"/><stop offset=".78" stop-color="{dark(c, .13)}"/>'
                          f'<stop offset="1" stop-color="{light(c, .18)}"/></linearGradient>')
            return f"url(#{i})"
        s.defs.append(f'<linearGradient id="{i}" x1="{x1:.2f}" y1="{y1:.2f}" x2="{1 - x1:.2f}" y2="{1 - y1:.2f}">'
                      f'<stop offset="0" stop-color="{light(c, .28)}"/><stop offset=".55" stop-color="{c}"/><stop offset="1" stop-color="{dark(c, .16)}"/></linearGradient>')
        return f"url(#{i})"
    def rad(s, c):
        i = s.id()
        if FLAT and JELLY > 0:
            c = vivid(c)
            s.defs.append(f'<radialGradient id="{i}" cx=".36" cy=".3" r=".78"><stop offset="0" stop-color="{light(c, .5)}"/>'
                          f'<stop offset=".35" stop-color="{c}"/><stop offset=".85" stop-color="{dark(c, .12)}"/><stop offset="1" stop-color="{light(c, .16)}"/></radialGradient>')
            return f"url(#{i})"
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
    if FLAT and JELLY > 0:
        # jelly: a glossy streak along the lit side of the tube, and light glowing through the shaded edge
        o2 = w * 0.24
        d3 = "M" + " L".join(f"{x - o2:.1f} {y - o2:.1f}" for x, y in pts)
        s.add(f'<path d="{d3}" fill="none" stroke="#FFFFFF" stroke-width="{w * .16:.1f}" stroke-linecap="round" stroke-linejoin="round" opacity="{min(1, .5 * JELLY):.2f}"/>')
        o3 = w * 0.3
        d4 = "M" + " L".join(f"{x + o3:.1f} {y + o3:.1f}" for x, y in pts)
        s.add(f'<path d="{d4}" fill="none" stroke="{light(vivid(c), .3)}" stroke-width="{w * .1:.1f}" stroke-linecap="round" stroke-linejoin="round" opacity="{min(1, .45 * JELLY):.2f}"/>')

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
    # a toddler, not a small adult: a big head (about a third of the height at 3, as picture books draw it), a round
    # tummy, short chubby arms and legs — the legs shorter than head and body together at every age
    k = min(36, max(0, age)) / 36
    return dict(head=25 + 4 * k, torso=40 + 16 * k, tw=40 + 8 * k, ua=18 + 8 * k, fa=16 + 8 * k,
                th=18 + 12 * k, sh=16 + 14 * k, aw=13 + 3 * k, lw=17 + 5 * k, hand=7 + 2 * k)

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
                 hair=None, at=None, tilt=0, girl=False, lean=0):
        s.kind, s.pose, s.f, s.age, s.expr, s.look, s.tilt = kind, pose, face, age, expr, look, tilt
        s.lean = lean   # body language: + leans in toward the face direction (engaging), - sits back (waiting)
        s.girl = girl
        if girl and top is None: top = GIRL_TOP
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
        d, p, f = s.d, dict(POSES[s.pose]), s.f
        p["torso"] = p["torso"] + s.lean
        hip = (0.0, 0.0)
        sh = add(hip, polar(p["torso"], d["torso"], f))
        legs = []
        spread = 6 if s.kind == "child" and s.pose in ("stand", "walk", "run", "squat") else 0
        for n, (ta, sa) in enumerate(p["legs"]):
            ta, sa = ta + (-spread if n == 0 else spread), sa + (-spread if n == 0 else spread)
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
        s.headc = add(s.sh, polar(p["torso"] + ht, d["head"] * (1.15 if s.kind == "adult" else 0.92), f))
        # shoulders: near one a little toward the viewer
        s.shN = add(s.sh, polar(p["torso"] + 180, d["head"] * 0.25, f))
        s.shF = add(s.shN, (-f * d["tw"] * 0.12, -2))
        s.arms = []
        for k, (ua, fa) in enumerate(p["arms"]):
            shp = s.shN if k == 0 else s.shF
            tgt = s.targets[k] if s.targets and k < len(s.targets) else None
            if tgt is not None:
                elbow, hand = ik(shp, tgt, d["ua"], d["fa"], bend=(1 if f > 0 else -1) * (1 if p["torso"] > 40 else -1))
                if dist(tgt, s.headc) < d["head"] * 1.6:
                    # a hand at one's own face (chin, ear, mouth): the elbow hangs low in front of the chest
                    e2, h2 = ik(shp, tgt, d["ua"], d["fa"], bend=-(1 if f > 0 else -1) * (1 if p["torso"] > 40 else -1))
                    if e2[1] > elbow[1]: elbow, hand = e2, h2
            else:
                elbow = add(shp, polar(ua, d["ua"], f)); hand = add(elbow, polar(fa, d["fa"], f))
            s.arms.append((shp, elbow, hand))

    def hand(s, k=0): return s.arms[k][2]
    def head(s): return cast_head(s) if CAST else s.headc

    def draw_shadow(s, sv):
        xs = [s.hip[0], s.legs[0][1][0], s.legs[1][1][0], s.legs[0][0][0], s.headc[0]]
        cx = (min(xs) + max(xs)) / 2; w = max(xs) - min(xs) + s.d["tw"]
        # a wide soft shade and a tight dark core where the body meets the floor: grounded, never floating
        sv.shadow(cx, GROUND + 4, w * 0.66, 15 if s.kind == "adult" else 11, .24)
        sv.shadow(cx, GROUND + 2, w * 0.42, 5 if s.kind == "adult" else 4, .34)

    def draw(s, sv):
        if CAST: return draw_cast(s, sv)
        d, f = s.d, s.f
        if s.pose == "bundle":
            c = s.bundle_c; L = d["torso"] * 1.9; w = d["tw"] * 1.25; ang = s.bundle_a
            sv.add(f'<g transform="translate({c[0]:.1f} {c[1]:.1f}) rotate({ang:.1f})"><rect x="{-L / 2:.1f}" y="{-w / 2:.1f}" width="{L:.1f}" height="{w:.1f}" rx="{w / 2:.1f}" fill="{sv.lin("#BFE3F0", 120)}"/>'
                   f'<path d="M{-L * .1:.1f} {-w / 2 + 3:.1f} Q{L * .1:.1f} {0:.1f} {-L * .05:.1f} {w / 2 - 3:.1f}" stroke="#FFFFFF" stroke-width="4" fill="none" opacity=".7"/></g>')
            s.draw_head(sv, neck=False)
            return
        # far limbs, behind
        knee, foot = s.legs[1]; limb(sv, [s.hip, knee, foot], d["lw"], dark(s.leg, .12)); s.foot(sv, foot, s.legs[1][0], dark(s.leg, .12))
        shp, el, hd = s.arms[1]; limb(sv, [shp, el, hd], d["aw"], dark(s.top, .12)); s.cuff(sv, el, hd, dark(s.top, .12)); s.mitt(sv, hd, dark(s.skin, .06), el)
        # torso
        s.torso(sv)
        knee, foot = s.legs[0]; limb(sv, [s.hip, knee, foot], d["lw"], s.leg); s.foot(sv, foot, knee, s.leg)
        # head
        s.draw_head(sv)
        shp, el, hd = s.arms[0]; limb(sv, [shp, el, hd], d["aw"], s.top); s.cuff(sv, el, hd, s.top); s.mitt(sv, hd, s.skin, el)

    def cuff(s, sv, el, hd, c):
        """A sleeve cuff: a slightly darker band just before the hand."""
        L = dist(el, hd)
        if L < 4: return
        ux, uy = (hd[0] - el[0]) / L, (hd[1] - el[1]) / L
        a = (hd[0] - ux * s.d["hand"] * 1.15, hd[1] - uy * s.d["hand"] * 1.15); b = (hd[0] - ux * s.d["hand"] * .55, hd[1] - uy * s.d["hand"] * .55)
        sv.add(f'<path d="M{a[0]:.1f} {a[1]:.1f} L{b[0]:.1f} {b[1]:.1f}" stroke="{dark(c, .14)}" stroke-width="{s.d["aw"] * 1.04:.1f}" stroke-linecap="round"/>')

    def foot(s, sv, foot, knee, c):
        if s.kind == "child" and s.age < 10: return
        dx = s.f * s.d["lw"] * 0.45
        sv.add(f'<ellipse cx="{foot[0] + dx:.1f}" cy="{foot[1] + 2:.1f}" rx="{s.d["lw"] * .62:.1f}" ry="{s.d["lw"] * .36:.1f}" fill="{dark(c, .3)}"/>')

    def mitt(s, sv, p, c, el=None):
        """A hand: a rounded palm along the forearm with a thumb on the upper side, so the hand reads as a hand."""
        r = s.d["hand"]
        if el is None or dist(el, p) < 1:
            sv.add(f'<circle cx="{p[0]:.1f}" cy="{p[1]:.1f}" r="{r:.1f}" fill="{sv.rad(c)}"/>'); return
        ang = math.degrees(math.atan2(p[1] - el[1], p[0] - el[0]))
        side = -1 if math.cos(math.radians(ang)) >= 0 else 1   # the thumb on the upper side
        g = sv.rad(c)
        sv.add(f'<g transform="translate({p[0]:.1f} {p[1]:.1f}) rotate({ang:.1f})">'
               f'<ellipse cx="{r * .5:.1f}" cy="{side * r * .55:.1f}" rx="{r * .42:.1f}" ry="{r * .32:.1f}" fill="{dark(c, .05)}" transform="rotate({side * -30} {r * .5:.1f} {side * r * .55:.1f})"/>'
               f'<ellipse cx="{r * .2:.1f}" cy="0" rx="{r * 1.12:.1f}" ry="{r * .86:.1f}" fill="{g}"/>'
               f'<path d="M{r * .7:.1f} {-r * .3:.1f} q{r * .25:.1f} {r * .3:.1f} 0 {r * .6:.1f}" fill="none" stroke="{dark(c, .2)}" stroke-width="{max(1, r * .1):.1f}" stroke-linecap="round" opacity=".55"/></g>')

    def torso(s, sv):
        d = s.d
        a, b = s.hip, s.sh
        L = dist(a, b); ang = math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
        cx, cy = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        w = d["tw"] * (1.0 if s.kind == "adult" else 1.18)   # a round toddler tummy
        g = sv.lin(s.top, 120)
        if s.kind == "child":
            # an egg: wider at the tummy than at the shoulders
            egg = (f'M{-L / 2 - w * .3:.1f} 0 C{-L / 2 - w * .3:.1f} {-w * .62:.1f} {L / 2 + w * .1:.1f} {-w * .46:.1f} {L / 2 + w * .18:.1f} 0 '
                   f'C{L / 2 + w * .1:.1f} {w * .46:.1f} {-L / 2 - w * .3:.1f} {w * .62:.1f} {-L / 2 - w * .3:.1f} 0 Z')
            cid = sv.id()
            # a striped top: two soft bands across the body, and a round collar at the neck
            stripes = "".join(f'<rect x="{-L / 2 + L * t:.1f}" y="{-w:.1f}" width="{max(2.5, L * .1):.1f}" height="{2 * w:.1f}" fill="{light(s.top, .42)}" opacity=".75"/>' for t in (.18, .5))
            sv.add(f'<g transform="translate({cx:.1f} {cy:.1f}) rotate({ang:.1f})"><clipPath id="{cid}"><path d="{egg}"/></clipPath>'
                   f'<path d="{egg}" fill="{g}"/><g clip-path="url(#{cid})">{stripes}</g>'
                   f'<ellipse cx="{L / 2 + w * .08:.1f}" cy="0" rx="{w * .12:.1f}" ry="{w * .3:.1f}" fill="{light(s.top, .55)}"/></g>')
            if s.age < 12: sv.add(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{w * .48:.1f}" fill="{sv.rad(s.leg)}"/>')
            return
        # an adult's top: a soft fold at the waist and a curved neckline
        sv.add(f'<g transform="translate({cx:.1f} {cy:.1f}) rotate({ang:.1f})">'
               f'<rect x="{-L / 2 - w * .32:.1f}" y="{-w / 2:.1f}" width="{L + w * .5:.1f}" height="{w:.1f}" rx="{w / 2:.1f}" fill="{g}"/>'
               f'<path d="M{-L / 2 + w * .15:.1f} {-w * .38:.1f} q{w * .12:.1f} {w * .38:.1f} 0 {w * .76:.1f}" fill="none" stroke="{dark(s.top, .14)}" stroke-width="{w * .06:.1f}" stroke-linecap="round" opacity=".6"/>'
               f'<path d="M{L / 2 + w * .1:.1f} {-w * .28:.1f} q{-w * .22:.1f} {w * .28:.1f} 0 {w * .56:.1f}" fill="{s.skin}" stroke="{dark(s.top, .1)}" stroke-width="{w * .05:.1f}"/></g>')
        if s.kind == "child" and s.age < 12:  # a onesie: the same colour down to the hips
            sv.add(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{w * .5:.1f}" fill="{sv.rad(s.leg)}"/>')

    def bow(s, sv, x, y, k):
        sv.add(f'<path d="M{x:.1f} {y:.1f} L{x - k * 1.2:.1f} {y - k * .75:.1f} Q{x - k * 1.4:.1f} {y:.1f} {x - k * 1.2:.1f} {y + k * .75:.1f} Z '
               f'M{x:.1f} {y:.1f} L{x + k * 1.2:.1f} {y - k * .75:.1f} Q{x + k * 1.4:.1f} {y:.1f} {x + k * 1.2:.1f} {y + k * .75:.1f} Z" fill="{BOW}" stroke="{dark(BOW, .25)}" stroke-width="1" stroke-linejoin="round"/>')
        sv.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{k * .38:.1f}" fill="{dark(BOW, .15)}"/>')

    def draw_head(s, sv, neck=True):
        d, f = s.d, s.f
        c = s.headc; r = d["head"]
        if neck: limb(sv, [s.sh, c], r * 0.55, s.skin)
        hair = HAIR["adult" if s.kind == "adult" else "child"]
        if s.hair == "bun":
            sv.add(f'<circle cx="{c[0] - f * r * .72:.1f}" cy="{c[1] - r * .62:.1f}" r="{r * .42:.1f}" fill="{sv.rad(hair)}"/>')
        sv.add(f'<circle cx="{c[0]:.1f}" cy="{c[1]:.1f}" r="{r:.1f}" fill="{sv.rad(s.skin)}"/>')
        if FLAT and JELLY > 0:   # jelly: a soft gloss on the forehead's lit side
            sv.add(f'<ellipse cx="{c[0] + f * r * .28:.1f}" cy="{c[1] - r * .5:.1f}" rx="{r * .26:.1f}" ry="{r * .14:.1f}" fill="#FFFFFF" opacity="{min(1, .42 * JELLY):.2f}" transform="rotate({-25 * f:.0f} {c[0] + f * r * .28:.1f} {c[1] - r * .5:.1f})"/>')
        # hair cap over the top and back
        if s.hair == "bob":
            # a toddler's soft hair: a small cap at the back and top, a curl standing up
            sv.add(f'<path d="M{c[0] - f * r * 1.02:.1f} {c[1] + r * .2:.1f} A{r:.1f} {r:.1f} 0 0 {1 if f > 0 else 0} {c[0] + f * r * .55:.1f} {c[1] - r * .84:.1f} '
                   f'Q{c[0] + f * r * .05:.1f} {c[1] - r * .45:.1f} {c[0] - f * r * .45:.1f} {c[1] - r * .4:.1f} Q{c[0] - f * r * .8:.1f} {c[1] - r * .1:.1f} {c[0] - f * r * 1.02:.1f} {c[1] + r * .2:.1f} Z" fill="{sv.lin(hair, 120)}"/>')
            sv.add(f'<path d="M{c[0] + f * r * .05:.1f} {c[1] - r * .95:.1f} q{f * r * .1:.1f} {-r * .45:.1f} {f * r * .45:.1f} {-r * .3:.1f}" fill="none" stroke="{hair}" stroke-width="{max(3, r * .14):.1f}" stroke-linecap="round"/>')
        if s.hair in ("bun", "short"):
            k = 1.03
            sv.add(f'<path d="M{c[0] - r * k:.1f} {c[1] + r * (.15 if s.hair == "bob" else -.05):.1f} '
                   f'A{r * k:.1f} {r * k:.1f} 0 0 1 {c[0] + r * k:.1f} {c[1] - r * .05:.1f} '
                   f'Q{c[0] + r * .2:.1f} {c[1] - r * .55:.1f} {c[0] - r * .35:.1f} {c[1] - r * .38:.1f} '
                   f'Q{c[0] - r * .7:.1f} {c[1] - r * .1:.1f} {c[0] - r * .9:.1f} {c[1] + r * .4:.1f} Z" '
                   f'fill="{sv.lin(hair, 120)}" transform="{"" if f > 0 else f"translate({2 * c[0]:.1f} 0) scale(-1 1)"}"/>')
        elif s.hair == "tuft":
            sv.add(f'<path d="M{c[0]:.1f} {c[1] - r:.1f} q{f * 6:.1f} -10 {f * 12:.1f} -4" fill="none" stroke="{hair}" stroke-width="3" stroke-linecap="round"/>')
        if s.girl and s.hair == "bob":
            # two small pigtails at the back, each tied with a bow
            for k, (dx, dy) in enumerate(((-1.0, -.3), (-.55, -.86))):
                px, py = c[0] + f * r * dx, c[1] + r * dy
                sv.add(f'<ellipse cx="{px - f * r * .14:.1f}" cy="{py + r * .06:.1f}" rx="{r * .2:.1f}" ry="{r * .28:.1f}" fill="{sv.lin(hair, 120)}" transform="rotate({-f * (30 + 30 * k):.0f} {px:.1f} {py:.1f})"/>')
                s.bow(sv, px, py, r * (.2 if k == 0 else .18))
        elif s.girl:
            s.bow(sv, c[0] - f * r * .3, c[1] - r * .9, r * .22)
        # ear
        sv.add(f'<circle cx="{c[0] - f * r * .18:.1f}" cy="{c[1] + r * .08:.1f}" r="{r * .16:.1f}" fill="{dark(s.skin, .08)}"/>')
        # the face looks toward the face direction, eyes toward what is looked at
        fx, fy = c[0] + f * r * .42, c[1] + r * .02
        lx, ly = 0.0, 0.0
        if s.look:
            dx, dy = s.look[0] - c[0], s.look[1] - c[1]; m = max(1, math.hypot(dx, dy)); lx, ly = dx / m * r * .06, dy / m * r * .08
        e = r * .115; sw = max(2, r * .07)
        eyes = (fx - f * r * .2, fx + f * r * .22)
        if s.expr in ("sleep", "calm"):
            for ex in eyes:
                sv.add(f'<path d="M{ex - e:.1f} {fy - r * .12:.1f} q{e:.1f} {e:.1f} {2 * e:.1f} 0" fill="none" stroke="{INK}" stroke-width="{sw:.1f}" stroke-linecap="round"/>')
        else:
            for k, ex in enumerate(eyes):
                big = 1.12 if s.expr == "wow" else 1.0
                sv.add(f'<ellipse cx="{ex + lx:.1f}" cy="{fy - r * .14 + ly:.1f}" rx="{e * (0.8 if k == 0 else 1) * big:.1f}" ry="{e * 1.25 * big:.1f}" fill="{INK}"/>')
                sv.add(f'<circle cx="{ex + lx - e * .3:.1f}" cy="{fy - r * .2 + ly:.1f}" r="{e * .36:.1f}" fill="#FFFFFF"/>')
                sv.add(f'<circle cx="{ex + lx + e * .3:.1f}" cy="{fy - r * .06 + ly:.1f}" r="{e * .16:.1f}" fill="#FFFFFF" opacity=".8"/>')
        # brows: they carry most of the feeling — raised for surprise and talk, tilted up in the middle for sad
        bw = r * .14; by = fy - r * (.36 if s.kind == "adult" else .4)
        lift = {"wow": .1, "talk": .05, "sing": .06, "sad": 0, "flat": -.02, "sleep": -.04, "calm": -.03}.get(s.expr, .02)
        hair_b = HAIR["adult" if s.kind == "adult" else "child"]
        for k, ex in enumerate(eyes):
            x0, x1 = ex - bw * (0.8 if k == 0 else 1), ex + bw * (0.8 if k == 0 else 1)
            inner = x1 if (f > 0) == (k == 0) else x0   # the end nearer the middle of the face
            y_in = by - r * lift - (r * .08 if s.expr == "sad" else 0)
            y_out = by - r * lift + (r * .03 if s.expr == "sad" else 0)
            ya, yb = (y_out, y_in) if inner == x1 else (y_in, y_out)
            sv.add(f'<path d="M{x0:.1f} {ya:.1f} Q{(x0 + x1) / 2:.1f} {min(ya, yb) - r * .07:.1f} {x1:.1f} {yb:.1f}" fill="none" stroke="{dark(hair_b, .1)}" stroke-width="{max(1.6, r * .06):.1f}" stroke-linecap="round" opacity=".85"/>')
        # nose: a small soft bump at the front of the face
        nx = c[0] + f * r * .98
        if s.kind == "adult":
            sv.add(f'<path d="M{nx - f * r * .04:.1f} {fy - r * .06:.1f} q{f * r * .12:.1f} {r * .12:.1f} {-f * r * .02:.1f} {r * .18:.1f}" fill="none" stroke="{dark(s.skin, .25)}" stroke-width="{max(1.6, r * .055):.1f}" stroke-linecap="round"/>')
        else:
            sv.add(f'<ellipse cx="{nx - f * r * .06:.1f}" cy="{fy + r * .06:.1f}" rx="{r * .07:.1f}" ry="{r * .05:.1f}" fill="{dark(s.skin, .18)}" opacity=".7"/>')
        # cheek
        sv.add(f'<ellipse cx="{fx + f * r * .3:.1f}" cy="{fy + r * .2:.1f}" rx="{r * .17:.1f}" ry="{r * .11:.1f}" fill="#F08A8A" opacity="{.55 if s.kind == "child" else .4}"/>')
        mx, my = fx + f * r * .06, fy + r * .32
        w = r * .22
        MOUTH, TONGUE = "#8E3434", "#F28C8C"
        if s.expr in ("talk", "sing"):
            ry = w * (.62 if s.expr == "sing" else .5)
            sv.add(f'<ellipse cx="{mx:.1f}" cy="{my:.1f}" rx="{w * .55:.1f}" ry="{ry:.1f}" fill="{MOUTH}"/>')
            sv.add(f'<ellipse cx="{mx:.1f}" cy="{my + ry * .45:.1f}" rx="{w * .32:.1f}" ry="{ry * .4:.1f}" fill="{TONGUE}"/>')
        elif s.expr == "wow":
            sv.add(f'<ellipse cx="{mx:.1f}" cy="{my + w * .05:.1f}" rx="{w * .34:.1f}" ry="{w * .44:.1f}" fill="{MOUTH}"/>')
        elif s.expr == "sad":
            sv.add(f'<path d="M{mx - w * .6:.1f} {my + w * .25:.1f} q{w * .6:.1f} {-w * .6:.1f} {w * 1.2:.1f} 0" fill="none" stroke="{INK}" stroke-width="{sw:.1f}" stroke-linecap="round"/>')
        elif s.expr == "flat":
            sv.add(f'<path d="M{mx - w * .45:.1f} {my:.1f} h{w * .9:.1f}" stroke="{INK}" stroke-width="{sw:.1f}" stroke-linecap="round"/>')
        elif s.expr == "smile" and s.kind == "child":
            # a child's smile is open: a little D with the tongue showing
            sv.add(f'<path d="M{mx - w * .62:.1f} {my - w * .2:.1f} Q{mx:.1f} {my - w * .05:.1f} {mx + w * .62:.1f} {my - w * .2:.1f} Q{mx + w * .5:.1f} {my + w * .75:.1f} {mx:.1f} {my + w * .72:.1f} Q{mx - w * .5:.1f} {my + w * .75:.1f} {mx - w * .62:.1f} {my - w * .2:.1f} Z" fill="{MOUTH}"/>')
            sv.add(f'<ellipse cx="{mx:.1f}" cy="{my + w * .48:.1f}" rx="{w * .3:.1f}" ry="{w * .18:.1f}" fill="{TONGUE}"/>')
        else:
            sv.add(f'<path d="M{mx - w * .65:.1f} {my - w * .2:.1f} q{w * .65:.1f} {w * .75:.1f} {w * 1.3:.1f} 0" fill="none" stroke="{INK}" stroke-width="{sw:.1f}" stroke-linecap="round"/>')
            for sx in (-1, 1):  # small dimples at the corners
                sv.add(f'<path d="M{mx + sx * w * .65:.1f} {my - w * .2:.1f} l{sx * w * .14:.1f} {-w * .1:.1f}" stroke="{INK}" stroke-width="{sw * .8:.1f}" stroke-linecap="round"/>')

# ---------- materials ----------
CARVE = ["circle", "tri", "star", "heart"]
def cube(sv, x, y, z, col, i=0):
    """A wooden block standing on (x, y), half-size z: a painted front, a lighter top bevel, a carved shape."""
    out = (f'<rect x="{x - z:.1f}" y="{y - 2 * z:.1f}" width="{2 * z:.1f}" height="{2 * z:.1f}" rx="{z * .24:.1f}" fill="{sv.lin(col, 120)}"/>'
           f'<rect x="{x - z * .86:.1f}" y="{y - 2 * z + z * .1:.1f}" width="{z * 1.72:.1f}" height="{z * .2:.1f}" rx="{z * .1:.1f}" fill="#FFFFFF" opacity=".35"/>'
           f'<rect x="{x - z * .78:.1f}" y="{y - 2 * z + z * .22:.1f}" width="{z * 1.56:.1f}" height="{z * 1.56:.1f}" rx="{z * .16:.1f}" fill="none" stroke="{dark(col, .12)}" stroke-width="{max(1, z * .05):.1f}" opacity=".5"/>')
    sh, cx, cy, k, fill = CARVE[i % len(CARVE)], x, y - z, z * .42, light(col, .5)
    if sh == "circle": out += f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{k:.1f}" fill="{fill}"/>'
    elif sh == "tri": out += f'<path d="M{cx:.1f} {cy - k:.1f} L{cx + k:.1f} {cy + k * .8:.1f} L{cx - k:.1f} {cy + k * .8:.1f} Z" fill="{fill}" stroke="{fill}" stroke-width="{k * .2:.1f}" stroke-linejoin="round"/>'
    elif sh == "star": out += f'<path d="' + "".join(f'{"M" if j == 0 else "L"}{cx + math.sin(j * math.pi / 5) * (k * 1.1 if j % 2 == 0 else k * .5):.1f} {cy - math.cos(j * math.pi / 5) * (k * 1.1 if j % 2 == 0 else k * .5):.1f} ' for j in range(10)) + f'Z" fill="{fill}" stroke="{fill}" stroke-width="{k * .12:.1f}" stroke-linejoin="round"/>'
    else: out += pict("heart", cx, cy, k / 14).replace("#FF6F91", fill)
    return out

def obj(sv, k, x, y, s=1.0, c=None, rot=0):
    """Draws a material standing on (x, y) — y is where it touches the floor or table."""
    g = lambda col: sv.lin(col, 120)
    out = []
    A = out.append
    if k == "block":
        col = c or "#F2554B"; z = 30 * s
        A(cube(sv, x, y, z, col, 0))
    elif k == "blocks":  # a stack: list of colours, bottom first
        cols = c or ["#4C9BE8", "#FFC23D", "#F2554B"]
        yy = y
        for i, col in enumerate(cols):
            z = (30 - i * 2) * s
            A(cube(sv, x + (i % 2) * 3, yy, z, col, i)); yy -= 2 * z
    elif k == "tumble":  # fallen blocks
        for i, (dx, col, r) in enumerate([(-44, "#4C9BE8", -18), (0, "#FFC23D", 12), (46, "#F2554B", 30)]):
            z = 26 * s
            A(f'<g transform="rotate({r} {x + dx * s:.1f} {y - z:.1f})">{cube(sv, x + dx * s, y, z, col, i)}</g>')
    elif k == "ball":
        # a soft cloth ball: segments in two colours meeting at the top, a stitched seam between them
        col = c or "#F2554B"; r = 34 * s; cy = y - r; alt = "#FFF3E0"
        cid = sv.id()
        A(f'<clipPath id="{cid}"><circle cx="{x:.1f}" cy="{cy:.1f}" r="{r:.1f}"/></clipPath><circle cx="{x:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{sv.rad(col)}"/>')
        A(f'<g clip-path="url(#{cid})">' + "".join(
            f'<path d="M{x:.1f} {cy - r:.1f} Q{x + dx * r:.1f} {cy:.1f} {x:.1f} {cy + r:.1f} Q{x + (dx + .55) * r:.1f} {cy:.1f} {x:.1f} {cy - r:.1f} Z" fill="{alt}" opacity=".9"/>'
            for dx in (-1.1, .25)) + '</g>')
        A(f'<circle cx="{x:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{sv.rad("#000000")}" opacity=".08"/>')
        A(f'<circle cx="{x - r * .35:.1f}" cy="{cy - r * .4:.1f}" r="{r * .16:.1f}" fill="#FFFFFF" opacity=".35"/>')
    elif k == "rattle":
        # a wooden rattle: a turned handle with rings and a round head with a bead inside
        col = c or "#9B7BEA"; r = 20 * s
        A(f'<g transform="rotate(24 {x:.1f} {y - 40 * s:.1f})"><rect x="{x - 5 * s:.1f}" y="{y - 70 * s:.1f}" width="{10 * s:.1f}" height="{44 * s:.1f}" rx="{5 * s:.1f}" fill="{g("#E2B57A")}"/>'
          + "".join(f'<rect x="{x - 7 * s:.1f}" y="{y - (56 - i * 14) * s:.1f}" width="{14 * s:.1f}" height="{5 * s:.1f}" rx="{2.5 * s:.1f}" fill="{["#FFC23D", "#1FB5A6", "#FF6F91"][i]}"/>' for i in range(3)) + '</g>')
        A(f'<circle cx="{x + 14 * s:.1f}" cy="{y - 74 * s:.1f}" r="{r:.1f}" fill="{sv.rad(col)}"/>')
        A(f'<circle cx="{x + 14 * s:.1f}" cy="{y - 74 * s:.1f}" r="{r * .55:.1f}" fill="{light(col, .5)}" opacity=".7"/><circle cx="{x + 16 * s:.1f}" cy="{y - 71 * s:.1f}" r="{r * .25:.1f}" fill="#FFC23D"/>')
        A(f'<circle cx="{x + 8 * s:.1f}" cy="{y - 82 * s:.1f}" r="{r * .22:.1f}" fill="#FFFFFF" opacity=".55"/>')
    elif k == "cloth":
        col = c or "#1FB5A6"
        A(f'<path d="M{x - 52 * s:.1f} {y:.1f} Q{x - 40 * s:.1f} {y - 50 * s:.1f} {x - 6 * s:.1f} {y - 44 * s:.1f} Q{x + 30 * s:.1f} {y - 56 * s:.1f} {x + 50 * s:.1f} {y:.1f} Z" fill="{g(col)}"/>')
        # folds, and a stitched hem along the bottom
        A(f'<path d="M{x - 30 * s:.1f} {y - 6 * s:.1f} Q{x - 20 * s:.1f} {y - 30 * s:.1f} {x - 4 * s:.1f} {y - 34 * s:.1f}" fill="none" stroke="{light(col, .4)}" stroke-width="{4 * s:.1f}" stroke-linecap="round"/>')
        A(f'<path d="M{x + 18 * s:.1f} {y - 4 * s:.1f} Q{x + 22 * s:.1f} {y - 26 * s:.1f} {x + 12 * s:.1f} {y - 40 * s:.1f}" fill="none" stroke="{dark(col, .18)}" stroke-width="{3 * s:.1f}" stroke-linecap="round" opacity=".7"/>')
        A(f'<path d="M{x - 46 * s:.1f} {y - 5 * s:.1f} H{x + 44 * s:.1f}" stroke="#FFFFFF" stroke-width="{2 * s:.1f}" stroke-dasharray="{5 * s:.1f} {4 * s:.1f}" opacity=".7"/>')
    elif k == "cloth2":  # a rough second fabric
        col = c or "#FFC23D"
        A(f'<rect x="{x - 40 * s:.1f}" y="{y - 26 * s:.1f}" width="{80 * s:.1f}" height="{26 * s:.1f}" rx="{10 * s:.1f}" fill="{g(col)}"/>')
        for i in range(5): A(f'<circle cx="{x - 30 * s + i * 15 * s:.1f}" cy="{y - 13 * s:.1f}" r="{3 * s:.1f}" fill="{dark(col, .2)}"/>')
    elif k == "mirror":
        wood = "#C98A4B"
        A(f'<ellipse cx="{x:.1f}" cy="{y - 3 * s:.1f}" rx="{30 * s:.1f}" ry="{7 * s:.1f}" fill="{g(dark(wood, .1))}"/>')
        A(f'<rect x="{x - 6 * s:.1f}" y="{y - 40 * s:.1f}" width="{12 * s:.1f}" height="{40 * s:.1f}" rx="4" fill="{g(wood)}"/>')
        A(f'<ellipse cx="{x:.1f}" cy="{y - 110 * s:.1f}" rx="{56 * s:.1f}" ry="{72 * s:.1f}" fill="{g(wood)}"/>')
        A(f'<ellipse cx="{x:.1f}" cy="{y - 110 * s:.1f}" rx="{50 * s:.1f}" ry="{66 * s:.1f}" fill="none" stroke="{light(wood, .3)}" stroke-width="{2 * s:.1f}" opacity=".8"/>')
        A(f'<ellipse cx="{x:.1f}" cy="{y - 110 * s:.1f}" rx="{45 * s:.1f}" ry="{61 * s:.1f}" fill="{sv.lin("#DCEFF6", 150)}"/>')
        A(f'<path d="M{x - 26 * s:.1f} {y - 140 * s:.1f} l{22 * s:.1f} {-22 * s:.1f} M{x - 30 * s:.1f} {y - 112 * s:.1f} l{36 * s:.1f} {-36 * s:.1f}" stroke="#FFFFFF" stroke-width="{6 * s:.1f}" stroke-linecap="round" opacity=".8"/>')
    elif k in ("book", "bookopen"):
        col = c or "#4C9BE8"
        if k == "book":
            # a board book lying down: thick cream page edges, a spine, a picture on the cover
            A(f'<rect x="{x - 30 * s:.1f}" y="{y - 40 * s:.1f}" width="{60 * s:.1f}" height="{40 * s:.1f}" rx="{6 * s:.1f}" fill="{g(col)}"/>')
            A(f'<rect x="{x - 26 * s:.1f}" y="{y - 10 * s:.1f}" width="{54 * s:.1f}" height="{7 * s:.1f}" rx="{2 * s:.1f}" fill="#FFF8EA"/>')
            for i in range(2): A(f'<path d="M{x - 24 * s:.1f} {y - (8.5 - i * 3) * s:.1f} H{x + 26 * s:.1f}" stroke="#E6DED0" stroke-width="{1 * s:.1f}"/>')
            A(f'<rect x="{x - 30 * s:.1f}" y="{y - 40 * s:.1f}" width="{8 * s:.1f}" height="{40 * s:.1f}" rx="{4 * s:.1f}" fill="{dark(col, .15)}"/>')
            A(f'<circle cx="{x + 4 * s:.1f}" cy="{y - 24 * s:.1f}" r="{9 * s:.1f}" fill="#FFC23D"/><path d="M{x + 12 * s:.1f} {y - 14 * s:.1f} l{7 * s:.1f} {-12 * s:.1f} l{7 * s:.1f} {12 * s:.1f} z" fill="#FFFFFF" opacity=".85"/>')
        else:
            # an open book: thick pages fanned from the spine, a picture on each side
            for side in (-1, 1):
                A(f'<path d="M{x:.1f} {y - 4 * s:.1f} L{x + side * 64 * s:.1f} {y - 14 * s:.1f} L{x + side * 64 * s:.1f} {y - 20 * s:.1f} L{x:.1f} {y - 10 * s:.1f} Z" fill="{dark(col, .1)}"/>')
                A(f'<path d="M{x:.1f} {y - 10 * s:.1f} L{x + side * 62 * s:.1f} {y - 20 * s:.1f} L{x + side * 62 * s:.1f} {y - 66 * s:.1f} Q{x + side * 30 * s:.1f} {y - 64 * s:.1f} {x:.1f} {y - 56 * s:.1f} Z" fill="#FFFDF7" stroke="{col}" stroke-width="{4 * s:.1f}" stroke-linejoin="round"/>')
            A(f'<path d="M{x:.1f} {y - 56 * s:.1f} V{y - 10 * s:.1f}" stroke="{dark("#FFFDF7", .12)}" stroke-width="{3 * s:.1f}"/>')
            A(f'<circle cx="{x - 32 * s:.1f}" cy="{y - 38 * s:.1f}" r="{12 * s:.1f}" fill="#FFC23D"/>')
            A(f'<path d="M{x + 18 * s:.1f} {y - 26 * s:.1f} l{14 * s:.1f} {-24 * s:.1f} l{14 * s:.1f} {24 * s:.1f} z" fill="#4DB86A"/>')
    elif k == "basket":
        # a woven basket: a rim, rows and upright stakes, and a little shadow inside the mouth
        col = c or "#C98A4B"; cid = sv.id()
        body = f'M{x - 52 * s:.1f} {y - 44 * s:.1f} L{x + 52 * s:.1f} {y - 44 * s:.1f} L{x + 42 * s:.1f} {y:.1f} Q{x:.1f} {y + 3 * s:.1f} {x - 42 * s:.1f} {y:.1f} Z'
        A(f'<clipPath id="{cid}"><path d="{body}"/></clipPath><path d="{body}" fill="{g(col)}"/><g clip-path="url(#{cid})">')
        for i in range(-5, 6): A(f'<path d="M{x + i * 10 * s:.1f} {y - 44 * s:.1f} L{x + i * 8.2 * s:.1f} {y:.1f}" stroke="{dark(col, .14)}" stroke-width="{1.6 * s:.1f}" opacity=".6"/>')
        for i in range(1, 4): A(f'<path d="M{x - 52 * s:.1f} {y - 44 * s + i * 11 * s:.1f} H{x + 52 * s:.1f}" stroke="{dark(col, .2)}" stroke-width="{2.4 * s:.1f}"/><path d="M{x - 52 * s:.1f} {y - 42 * s + i * 11 * s:.1f} H{x + 52 * s:.1f}" stroke="{light(col, .3)}" stroke-width="{1.4 * s:.1f}" opacity=".7"/>')
        A('</g>')
        A(f'<rect x="{x - 55 * s:.1f}" y="{y - 49 * s:.1f}" width="{110 * s:.1f}" height="{9 * s:.1f}" rx="{4.5 * s:.1f}" fill="{g(dark(col, .06))}"/>')
    elif k == "cup":
        col = c or "#1FB5A6"
        A(f'<path d="M{x + 20 * s:.1f} {y - 40 * s:.1f} q{16 * s:.1f} {4 * s:.1f} {2 * s:.1f} {24 * s:.1f}" fill="none" stroke="{dark(col, .1)}" stroke-width="{6 * s:.1f}" stroke-linecap="round"/>')
        A(f'<path d="M{x - 22 * s:.1f} {y - 50 * s:.1f} L{x + 22 * s:.1f} {y - 50 * s:.1f} L{x + 17 * s:.1f} {y:.1f} L{x - 17 * s:.1f} {y:.1f} Z" fill="{g(col)}"/>')
        A(f'<ellipse cx="{x:.1f}" cy="{y - 50 * s:.1f}" rx="{22 * s:.1f}" ry="{5 * s:.1f}" fill="{dark(col, .25)}"/><ellipse cx="{x:.1f}" cy="{y - 50 * s:.1f}" rx="{22 * s:.1f}" ry="{5 * s:.1f}" fill="none" stroke="{light(col, .4)}" stroke-width="{2 * s:.1f}"/>')
    elif k == "drum":
        # a hand drum: rims top and bottom, laced sides, a skin on top
        col = c or "#F2554B"
        A(f'<rect x="{x - 40 * s:.1f}" y="{y - 46 * s:.1f}" width="{80 * s:.1f}" height="{46 * s:.1f}" rx="{8 * s:.1f}" fill="{g(col)}"/>')
        A(f'<path d="M{x - 38 * s:.1f} {y - 38 * s:.1f} ' + " ".join(f'L{x + (-38 + i * 19) * s:.1f} {y - (38 if i % 2 == 0 else 10) * s:.1f}' for i in range(1, 5)) + f'" fill="none" stroke="#FFF3E0" stroke-width="{3 * s:.1f}" stroke-linejoin="round"/>')
        for yy in (-42, -4): A(f'<rect x="{x - 42 * s:.1f}" y="{y + (yy - 4) * s:.1f}" width="{84 * s:.1f}" height="{8 * s:.1f}" rx="{4 * s:.1f}" fill="{g("#FFC23D")}"/>')
        A(f'<ellipse cx="{x:.1f}" cy="{y - 48 * s:.1f}" rx="{40 * s:.1f}" ry="{11 * s:.1f}" fill="{sv.lin("#FFF3E0", 90)}" stroke="#E6D3B8" stroke-width="{1.5 * s:.1f}"/>')
    elif k == "paper":
        A(f'<rect x="{x - 70 * s:.1f}" y="{y - 8 * s:.1f}" width="{140 * s:.1f}" height="{8 * s:.1f}" rx="2" fill="#FFFFFF" stroke="#E6DED0" stroke-width="2"/>')
        for i, col in enumerate(c or []): A(f'<path d="M{x - 50 * s + i * 30 * s:.1f} {y - 4 * s:.1f} q10 -6 22 0" stroke="{col}" stroke-width="{4 * s:.1f}" fill="none" stroke-linecap="round"/>')
    elif k == "crayon":
        col = c or "#4C9BE8"
        A(f'<g transform="rotate({rot or -60} {x:.1f} {y:.1f})"><rect x="{x - 6 * s:.1f}" y="{y - 46 * s:.1f}" width="{12 * s:.1f}" height="{40 * s:.1f}" rx="3" fill="{g(col)}"/>'
          f'<rect x="{x - 6.5 * s:.1f}" y="{y - 36 * s:.1f}" width="{13 * s:.1f}" height="{20 * s:.1f}" fill="#FFFDF7" opacity=".85"/><path d="M{x - 6 * s:.1f} {y - 31 * s:.1f} h{12 * s:.1f} M{x - 6 * s:.1f} {y - 21 * s:.1f} h{12 * s:.1f}" stroke="{col}" stroke-width="{2 * s:.1f}"/>'
          f'<path d="M{x - 6 * s:.1f} {y - 6 * s:.1f} L{x:.1f} {y + 6 * s:.1f} L{x + 6 * s:.1f} {y - 6 * s:.1f} Z" fill="{dark(col, .15)}"/></g>')
    elif k == "doll":
        # a soft doll: a dress, small arms, hair and a face
        col = c or "#9B7BEA"
        for sx in (-1, 1): A(f'<ellipse cx="{x + sx * 20 * s:.1f}" cy="{y - 34 * s:.1f}" rx="{6 * s:.1f}" ry="{12 * s:.1f}" fill="{dark(col, .1)}" transform="rotate({sx * -20} {x + sx * 20 * s:.1f} {y - 34 * s:.1f})"/>')
        A(f'<path d="M{x - 14 * s:.1f} {y - 50 * s:.1f} H{x + 14 * s:.1f} L{x + 22 * s:.1f} {y:.1f} H{x - 22 * s:.1f} Z" fill="{g(col)}"/>')
        A(f'<path d="M{x - 21 * s:.1f} {y - 6 * s:.1f} H{x + 21 * s:.1f}" stroke="#FFFFFF" stroke-width="{2.5 * s:.1f}" stroke-dasharray="{3 * s:.1f} {3 * s:.1f}" opacity=".7"/>')
        A(f'<circle cx="{x:.1f}" cy="{y - 66 * s:.1f}" r="{18 * s:.1f}" fill="{sv.rad("#F6D2B0")}"/>')
        A(f'<path d="M{x - 18 * s:.1f} {y - 64 * s:.1f} A{18 * s:.1f} {18 * s:.1f} 0 0 1 {x + 18 * s:.1f} {y - 64 * s:.1f} Q{x + 4 * s:.1f} {y - 76 * s:.1f} {x - 18 * s:.1f} {y - 64 * s:.1f} Z" fill="#8B5A3C"/>')
        A(f'<circle cx="{x - 6 * s:.1f}" cy="{y - 64 * s:.1f}" r="{2.4 * s:.1f}" fill="{INK}"/><circle cx="{x + 6 * s:.1f}" cy="{y - 64 * s:.1f}" r="{2.4 * s:.1f}" fill="{INK}"/>'
          f'<path d="M{x - 4 * s:.1f} {y - 57 * s:.1f} q{4 * s:.1f} {3 * s:.1f} {8 * s:.1f} 0" stroke="{INK}" stroke-width="{1.6 * s:.1f}" fill="none" stroke-linecap="round"/>'
          f'<circle cx="{x - 11 * s:.1f}" cy="{y - 59 * s:.1f}" r="{3 * s:.1f}" fill="#F08A8A" opacity=".5"/><circle cx="{x + 11 * s:.1f}" cy="{y - 59 * s:.1f}" r="{3 * s:.1f}" fill="#F08A8A" opacity=".5"/>')
    elif k == "dollbed":  # a doll lying under a blanket
        A(f'<circle cx="{x - 44 * s:.1f}" cy="{y - 20 * s:.1f}" r="{17 * s:.1f}" fill="{sv.rad("#F6D2B0")}"/>')
        A(f'<path d="M{x - 52 * s:.1f} {y - 22 * s:.1f} q3 3 6 0 M{x - 42 * s:.1f} {y - 22 * s:.1f} q3 3 6 0" stroke="{INK}" stroke-width="2" fill="none"/>')
        A(f'<rect x="{x - 30 * s:.1f}" y="{y - 34 * s:.1f}" width="{86 * s:.1f}" height="{34 * s:.1f}" rx="{14 * s:.1f}" fill="{g(c or "#4C9BE8")}"/>')
    elif k == "spoon":
        A(f'<g transform="rotate({rot or 30} {x:.1f} {y:.1f})"><rect x="{x - 3 * s:.1f}" y="{y - 40 * s:.1f}" width="{6 * s:.1f}" height="{34 * s:.1f}" rx="3" fill="#B9B2A8"/><ellipse cx="{x:.1f}" cy="{y - 46 * s:.1f}" rx="{8 * s:.1f}" ry="{11 * s:.1f}" fill="#CFC9C0"/></g>')
    elif k == "pot":
        col = c or "#F2554B"
        A(f'<rect x="{x - 38 * s:.1f}" y="{y - 40 * s:.1f}" width="{76 * s:.1f}" height="{40 * s:.1f}" rx="{10 * s:.1f}" fill="{g(col)}"/>')
        A(f'<rect x="{x - 44 * s:.1f}" y="{y - 46 * s:.1f}" width="{88 * s:.1f}" height="{10 * s:.1f}" rx="{5 * s:.1f}" fill="{dark(col, .1)}"/>')
        A(f'<rect x="{x + 38 * s:.1f}" y="{y - 36 * s:.1f}" width="{26 * s:.1f}" height="{8 * s:.1f}" rx="4" fill="{dark(col, .25)}"/>')
    elif k == "bowl":
        col = c or "#1FB5A6"
        A(f'<path d="M{x - 34 * s:.1f} {y - 26 * s:.1f} Q{x:.1f} {y + 10 * s:.1f} {x + 34 * s:.1f} {y - 26 * s:.1f} Z" fill="{g(col)}"/>')
        A(f'<circle cx="{x - 8 * s:.1f}" cy="{y - 28 * s:.1f}" r="{9 * s:.1f}" fill="#FFC23D"/><circle cx="{x + 10 * s:.1f}" cy="{y - 30 * s:.1f}" r="{8 * s:.1f}" fill="#4DB86A"/>')
    elif k == "cushion":
        col = c or "#9B7BEA"
        A(f'<rect x="{x - 54 * s:.1f}" y="{y - 30 * s:.1f}" width="{108 * s:.1f}" height="{30 * s:.1f}" rx="{15 * s:.1f}" fill="{g(col)}"/>')
        A(f'<rect x="{x - 48 * s:.1f}" y="{y - 25 * s:.1f}" width="{96 * s:.1f}" height="{20 * s:.1f}" rx="{10 * s:.1f}" fill="none" stroke="{light(col, .35)}" stroke-width="{1.6 * s:.1f}" stroke-dasharray="{4 * s:.1f} {3 * s:.1f}"/>')
        A(f'<circle cx="{x:.1f}" cy="{y - 15 * s:.1f}" r="{3.5 * s:.1f}" fill="{dark(col, .2)}"/>')
    elif k == "car":
        col = c or "#F2554B"
        A(f'<path d="M{x - 46 * s:.1f} {y - 14 * s:.1f} V{y - 34 * s:.1f} Q{x - 46 * s:.1f} {y - 40 * s:.1f} {x - 38 * s:.1f} {y - 40 * s:.1f} H{x - 22 * s:.1f} L{x - 10 * s:.1f} {y - 58 * s:.1f} H{x + 22 * s:.1f} L{x + 34 * s:.1f} {y - 40 * s:.1f} H{x + 40 * s:.1f} Q{x + 46 * s:.1f} {y - 40 * s:.1f} {x + 46 * s:.1f} {y - 34 * s:.1f} V{y - 14 * s:.1f} Z" fill="{g(col)}"/>')
        A(f'<path d="M{x - 6 * s:.1f} {y - 52 * s:.1f} H{x + 18 * s:.1f} L{x + 26 * s:.1f} {y - 40 * s:.1f} H{x - 14 * s:.1f} Z" fill="#DCEFF6"/>')
        for dx in (-26, 26): A(f'<circle cx="{x + dx * s:.1f}" cy="{y - 12 * s:.1f}" r="{12 * s:.1f}" fill="#3B3330"/><circle cx="{x + dx * s:.1f}" cy="{y - 12 * s:.1f}" r="{5 * s:.1f}" fill="#B9B2A8"/>')
    elif k == "tree":
        A(f'<rect x="{x - 9 * s:.1f}" y="{y - 120 * s:.1f}" width="{18 * s:.1f}" height="{120 * s:.1f}" rx="{8 * s:.1f}" fill="{g("#A9733F")}"/>')
        for dx, dy, r in ((0, -170, 62), (-44, -130, 44), (44, -134, 46)):
            A(f'<circle cx="{x + dx * s:.1f}" cy="{y + dy * s:.1f}" r="{r * s:.1f}" fill="{sv.rad("#5DB35A")}"/>')
    elif k == "leaf":
        col = c or "#FF8A3D"
        A(f'<g transform="rotate({rot} {x:.1f} {y:.1f})"><path d="M{x:.1f} {y:.1f} C{x - 26 * s:.1f} {y - 20 * s:.1f} {x - 20 * s:.1f} {y - 56 * s:.1f} {x:.1f} {y - 66 * s:.1f} C{x + 20 * s:.1f} {y - 56 * s:.1f} {x + 26 * s:.1f} {y - 20 * s:.1f} {x:.1f} {y:.1f} Z" fill="{g(col)}"/>'
          f'<path d="M{x:.1f} {y:.1f} V{y - 58 * s:.1f}" stroke="{dark(col, .25)}" stroke-width="{3 * s:.1f}"/></g>')
    elif k == "flower":
        A(f'<path d="M{x:.1f} {y:.1f} V{y - 40 * s:.1f}" stroke="#4DB86A" stroke-width="{5 * s:.1f}"/>')
        for i in range(5):
            a = i * 72; A(f'<circle cx="{x + math.sin(math.radians(a)) * 11 * s:.1f}" cy="{y - 48 * s - math.cos(math.radians(a)) * 11 * s:.1f}" r="{8 * s:.1f}" fill="{c or "#FF6F91"}"/>')
        A(f'<circle cx="{x:.1f}" cy="{y - 48 * s:.1f}" r="{6 * s:.1f}" fill="#FFC23D"/>')
    elif k == "bird":
        col = c or "#4C9BE8"
        A(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{18 * s:.1f}" ry="{13 * s:.1f}" fill="{sv.rad(col)}"/><circle cx="{x + 14 * s:.1f}" cy="{y - 10 * s:.1f}" r="{9 * s:.1f}" fill="{sv.rad(col)}"/>'
          f'<path d="M{x + 22 * s:.1f} {y - 10 * s:.1f} l{8 * s:.1f} {3 * s:.1f} l{-8 * s:.1f} {3 * s:.1f}Z" fill="#FFC23D"/><circle cx="{x + 16 * s:.1f}" cy="{y - 12 * s:.1f}" r="{2 * s:.1f}" fill="{INK}"/>'
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
        col = c or "#FF6F91"
        A(f'<path d="M{x - 10 * s:.1f} {y - 56 * s:.1f} H{x + 10 * s:.1f} V{y - 16 * s:.1f} Q{x + 12 * s:.1f} {y:.1f} {x + 30 * s:.1f} {y - 2 * s:.1f} Q{x + 40 * s:.1f} {y - 8 * s:.1f} {x + 30 * s:.1f} {y - 18 * s:.1f} L{x + 14 * s:.1f} {y - 22 * s:.1f}" fill="none"/>')
        A(f'<path d="M{x - 10 * s:.1f} {y - 56 * s:.1f} H{x + 10 * s:.1f} V{y - 24 * s:.1f} Q{x + 10 * s:.1f} {y - 10 * s:.1f} {x + 24 * s:.1f} {y - 12 * s:.1f} Q{x + 34 * s:.1f} {y - 8 * s:.1f} {x + 26 * s:.1f} {y:.1f} H{x - 4 * s:.1f} Q{x - 10 * s:.1f} {y - 4 * s:.1f} {x - 10 * s:.1f} {y - 14 * s:.1f} Z" fill="{g(col)}"/>')
    elif k == "shirt":
        col = c or "#4C9BE8"
        A(f'<path d="M{x - 30 * s:.1f} {y - 60 * s:.1f} L{x - 12 * s:.1f} {y - 66 * s:.1f} Q{x:.1f} {y - 58 * s:.1f} {x + 12 * s:.1f} {y - 66 * s:.1f} L{x + 30 * s:.1f} {y - 60 * s:.1f} L{x + 40 * s:.1f} {y - 42 * s:.1f} L{x + 26 * s:.1f} {y - 38 * s:.1f} V{y:.1f} H{x - 26 * s:.1f} V{y - 38 * s:.1f} L{x - 40 * s:.1f} {y - 42 * s:.1f} Z" fill="{g(col)}"/>')
        A(f'<path d="M{x - 12 * s:.1f} {y - 66 * s:.1f} Q{x:.1f} {y - 54 * s:.1f} {x + 12 * s:.1f} {y - 66 * s:.1f}" fill="none" stroke="{light(col, .45)}" stroke-width="{3 * s:.1f}" stroke-linecap="round"/>')
        A(f'<path d="M{x - 26 * s:.1f} {y - 4 * s:.1f} H{x + 26 * s:.1f}" stroke="{dark(col, .15)}" stroke-width="{2 * s:.1f}"/>')
        A(f'<circle cx="{x + 10 * s:.1f}" cy="{y - 30 * s:.1f}" r="{7 * s:.1f}" fill="#FFC23D"/>')
    elif k == "box":  # a low storage box with a hand hole
        col = c or "#4C9BE8"
        A(f'<rect x="{x - 50 * s:.1f}" y="{y - 40 * s:.1f}" width="{100 * s:.1f}" height="{40 * s:.1f}" rx="{8 * s:.1f}" fill="{g(col)}"/><rect x="{x - 50 * s:.1f}" y="{y - 40 * s:.1f}" width="{100 * s:.1f}" height="{8 * s:.1f}" rx="4" fill="{light(col, .3)}"/>')
        A(f'<rect x="{x - 14 * s:.1f}" y="{y - 26 * s:.1f}" width="{28 * s:.1f}" height="{8 * s:.1f}" rx="{4 * s:.1f}" fill="{dark(col, .35)}"/>')
    elif k == "photo":  # a family photo: c = number of people
        n = c or 3
        A(f'<rect x="{x - 46 * s:.1f}" y="{y - 70 * s:.1f}" width="{92 * s:.1f}" height="{70 * s:.1f}" rx="{6 * s:.1f}" fill="{g("#C98A4B")}"/><rect x="{x - 38 * s:.1f}" y="{y - 62 * s:.1f}" width="{76 * s:.1f}" height="{54 * s:.1f}" rx="3" fill="#E6F1FB"/>')
        for i in range(n if CAST else 0):
            px = x - (n - 1) * 12 * s + i * 24 * s
            A(cast_icon(["otto", "moss", "mosto", "mochi"][i % 4], px, y - (34 if i == 0 else 28) * s, (10 if i == 0 else 9) * s))
        for i in range(0 if CAST else n):
            px = x - (n - 1) * 12 * s + i * 24 * s; big = i < 2
            A(f'<circle cx="{px:.1f}" cy="{y - (44 if big else 34) * s:.1f}" r="{(8 if big else 6) * s:.1f}" fill="{SKIN[i % 2]}"/>'
              f'<rect x="{px - (9 if big else 7) * s:.1f}" y="{y - (36 if big else 28) * s:.1f}" width="{(18 if big else 14) * s:.1f}" height="{(28 if big else 20) * s:.1f}" rx="{6 * s:.1f}" fill="{["#E2728C", "#55607E", "#FFC23D", "#4DB86A"][i % 4]}"/>')
    elif k == "phone":
        A(f'<rect x="{x - 18 * s:.1f}" y="{y - 64 * s:.1f}" width="{36 * s:.1f}" height="{64 * s:.1f}" rx="{8 * s:.1f}" fill="#3B3330"/><rect x="{x - 14 * s:.1f}" y="{y - 58 * s:.1f}" width="{28 * s:.1f}" height="{50 * s:.1f}" rx="4" fill="#E6F1FB"/>'
          + (cast_icon("otto", x, y - 32 * s, 9 * s) if CAST else f'<circle cx="{x:.1f}" cy="{y - 38 * s:.1f}" r="{8 * s:.1f}" fill="{SKIN[0]}"/><rect x="{x - 9 * s:.1f}" y="{y - 29 * s:.1f}" width="{18 * s:.1f}" height="{14 * s:.1f}" rx="5" fill="#4DB86A"/>'))
    elif k == "notebook":
        A(f'<rect x="{x - 34 * s:.1f}" y="{y - 46 * s:.1f}" width="{68 * s:.1f}" height="{46 * s:.1f}" rx="{5 * s:.1f}" fill="#FFFFFF" stroke="#E6DED0" stroke-width="2"/>')
        for i in range(3): A(f'<path d="M{x - 24 * s:.1f} {y - 34 * s + i * 11 * s:.1f} h{(40 - i * 8) * s:.1f}" stroke="#B9B2A8" stroke-width="{3 * s:.1f}" stroke-linecap="round"/>')
        A(f'<rect x="{x + 22 * s:.1f}" y="{y - 64 * s:.1f}" width="{7 * s:.1f}" height="{40 * s:.1f}" rx="3" fill="#FFC23D" transform="rotate(30 {x + 25 * s:.1f} {y - 44 * s:.1f})"/>')
    elif k == "mat":  # a play mat on the floor
        col = c or "#BFE3D6"
        A(f'<rect x="{x - 150 * s:.1f}" y="{y - 6:.1f}" width="{300 * s:.1f}" height="{14:.1f}" rx="7" fill="{g(col)}"/>')
    elif k == "table":  # a low child-height table; y = floor; top at y-120
        A(f'<rect x="{x - 110 * s:.1f}" y="{y - 124:.1f}" width="{220 * s:.1f}" height="{18}" rx="8" fill="{g("#D6A774")}"/>')
        for dx in (-90, 90): A(f'<rect x="{x + dx * s - 8:.1f}" y="{y - 108:.1f}" width="16" height="108" rx="6" fill="{g("#B8854F")}"/>')
    elif k == "stroller":
        A(f'<path d="M{x - 60:.1f} {y - 110:.1f} A60 60 0 0 1 {x + 40:.1f} {y - 150:.1f} L{x + 40:.1f} {y - 90:.1f} Z" fill="{g("#1FB5A6")}"/>'
          f'<rect x="{x - 64:.1f}" y="{y - 96:.1f}" width="{120}" height="40" rx="18" fill="{g("#1FB5A6")}"/><path d="M{x + 56:.1f} {y - 80:.1f} L{x + 90:.1f} {y - 150:.1f}" stroke="#55607E" stroke-width="7" stroke-linecap="round"/>')
        for dx in (-40, 36): A(f'<circle cx="{x + dx:.1f}" cy="{y - 20:.1f}" r="20" fill="#3B3330"/><circle cx="{x + dx:.1f}" cy="{y - 20:.1f}" r="7" fill="#B9B2A8"/>')
    elif k == "road":
        A(f'<rect x="0" y="{y - 4:.1f}" width="{W}" height="60" fill="#B9B2A8"/>')
        for i in range(7): A(f'<rect x="{30 + i * 100}" y="{y + 22:.1f}" width="56" height="8" rx="4" fill="#FFFFFF"/>')
    elif k == "kerb":
        A(f'<rect x="0" y="{y - 10:.1f}" width="{W}" height="12" fill="#D9D4C7"/>')
    elif k == "lantern":
        A(f'<path d="M{x:.1f} {y - 110 * s:.1f} V{y - 90 * s:.1f}" stroke="#B8854F" stroke-width="3"/><ellipse cx="{x:.1f}" cy="{y - 64 * s:.1f}" rx="{30 * s:.1f}" ry="{28 * s:.1f}" fill="{sv.rad("#F2554B")}"/>'
          f'<rect x="{x - 12 * s:.1f}" y="{y - 96 * s:.1f}" width="{24 * s:.1f}" height="{8 * s:.1f}" rx="3" fill="#FFC23D"/><rect x="{x - 12 * s:.1f}" y="{y - 40 * s:.1f}" width="{24 * s:.1f}" height="{8 * s:.1f}" rx="3" fill="#FFC23D"/>'
          f'<path d="M{x:.1f} {y - 32 * s:.1f} v{18 * s:.1f}" stroke="#FFC23D" stroke-width="3"/>')
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
            if CAST: A(cast_icon("otto" if big else "moss", fx, fy, r)); continue
            A(f'<circle cx="{fx:.1f}" cy="{fy:.1f}" r="{r:.1f}" fill="{SKIN[0 if big else 1]}" opacity=".85"/><circle cx="{fx - r * .3:.1f}" cy="{fy - r * .1:.1f}" r="{r * .1:.1f}" fill="{INK}"/><circle cx="{fx + r * .3:.1f}" cy="{fy - r * .1:.1f}" r="{r * .1:.1f}" fill="{INK}"/>'
              f'<path d="M{fx - r * .3:.1f} {fy + r * .3:.1f} q{r * .3:.1f} {r * .3:.1f} {r * .6:.1f} 0" stroke="{INK}" stroke-width="2" fill="none"/>')
    elif k == "speaker":
        A(f'<rect x="{x - 26 * s:.1f}" y="{y - 70 * s:.1f}" width="{52 * s:.1f}" height="{70 * s:.1f}" rx="{10 * s:.1f}" fill="{g("#9B7BEA")}"/><circle cx="{x:.1f}" cy="{y - 30 * s:.1f}" r="{16 * s:.1f}" fill="{dark("#9B7BEA", .3)}"/><circle cx="{x:.1f}" cy="{y - 56 * s:.1f}" r="{7 * s:.1f}" fill="{dark("#9B7BEA", .3)}"/>')
    sv.add("".join(out))


# The cast in small (the illustrations' people are Moss, Otto, Mosto and Mochi when scene3d sets CAST): for pictures
# inside the pictures — a family photo, a face in a mirror, a phone's screen, a speech bubble.
CAST = False
def cast_icon(who, x, y, r, asleep=False):
    """A small flat drawing of one of the cast, its face centred on (x, y), about 2r across."""
    def eyes(cx, cy, rr, n=2):
        o = ""
        if asleep:
            for dx in ((-0.36, 0.36) if n == 2 else (0,)):
                ex = cx + dx * rr
                o += f'<path d="M{ex - rr * .18:.1f} {cy:.1f} q{rr * .18:.1f} {rr * .14:.1f} {rr * .36:.1f} 0" stroke="{INK}" stroke-width="{max(1.2, rr * .07):.1f}" fill="none" stroke-linecap="round"/>'
            return o
        for dx in ((-0.36, 0.36) if n == 2 else (0,)):
            ex = cx + dx * rr
            o += f'<ellipse cx="{ex:.1f}" cy="{cy:.1f}" rx="{rr * (0.2 if n == 2 else 0.34):.1f}" ry="{rr * (0.24 if n == 2 else 0.3):.1f}" fill="#FFFFFF"/>'
            o += f'<circle cx="{ex + rr * 0.04:.1f}" cy="{cy + rr * 0.03:.1f}" r="{rr * (0.12 if n == 2 else 0.18):.1f}" fill="{INK}"/>'
        return o
    if who == "otto":
        o = f'<rect x="{x - r * .7:.1f}" y="{y - r * 1.0:.1f}" width="{r * 1.4:.1f}" height="{r * 2.0:.1f}" rx="{r * .7:.1f}" fill="#1F3366"/>'
        o += f'<path d="M{x:.1f} {y - r:.1f} q{-r * .1:.1f} {-r * .6:.1f} {-r * .6:.1f} {-r * .5:.1f}" stroke="#1F3366" stroke-width="{max(1.5, r * .12):.1f}" fill="none" stroke-linecap="round"/>'
        o += f'<circle cx="{x - r * .62:.1f}" cy="{y - r * 1.38:.1f}" r="{r * .16:.1f}" fill="#D4A21C"/>'
        return o + eyes(x, y - r * .3, r, 1)
    if who == "mochi":
        o = f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{r:.1f}" ry="{r * .82:.1f}" fill="#F4E4CF" stroke="#E2CFB6" stroke-width="1"/>'
        o += f'<ellipse cx="{x:.1f}" cy="{y - r * .62:.1f}" rx="{r * .72:.1f}" ry="{r * .36:.1f}" fill="#E07A6A"/>'
        return o + eyes(x, y + r * .05, r * .8)
    if who == "mosto":
        body, hi = "#5E43A0", "#8A70C8"
    else:
        body, hi = "#4F6B3C", "#6E8C55"
    o = ""
    for sx in (-1, 1):   # little dark feet
        o += f'<ellipse cx="{x + sx * r * .42:.1f}" cy="{y + r * .82:.1f}" rx="{r * .2:.1f}" ry="{r * .1:.1f}" fill="#22231F"/>'
    # a round, full pebble: wider than tall, its base gently flattened where it rests
    o += f'<path d="M{x - r * 1.02:.1f} {y + r * .45:.1f} C{x - r * 1.1:.1f} {y - r * .55:.1f} {x - r * .5:.1f} {y - r * .95:.1f} {x:.1f} {y - r * .95:.1f} C{x + r * .55:.1f} {y - r * .95:.1f} {x + r * 1.1:.1f} {y - r * .5:.1f} {x + r * 1.02:.1f} {y + r * .45:.1f} C{x + r * .9:.1f} {y + r * .85:.1f} {x - r * .9:.1f} {y + r * .85:.1f} {x - r * 1.02:.1f} {y + r * .45:.1f} Z" fill="{body}"/>'
    o += f'<ellipse cx="{x - r * .38:.1f}" cy="{y - r * .48:.1f}" rx="{r * .34:.1f}" ry="{r * .18:.1f}" fill="{hi}" opacity=".55" transform="rotate(-20 {x - r * .38:.1f} {y - r * .48:.1f})"/>'
    if who == "mosto":
        o += f'<g transform="rotate(14 {x + r * .1:.1f} {y - r * .95:.1f})"><path d="M{x - r * .3:.1f} {y - r * .9:.1f} l{r * .08:.1f} {-r * .38:.1f} l{r * .2:.1f} {r * .22:.1f} l{r * .12:.1f} {-r * .34:.1f} l{r * .12:.1f} {r * .34:.1f} l{r * .2:.1f} {-r * .22:.1f} l{r * .08:.1f} {r * .38:.1f} Z" fill="#C9A24A"/></g>'
        for sx in (-1, 1):
            o += f'<path d="M{x + sx * r * .62:.1f} {y - r * .62:.1f} q{sx * r * .3:.1f} {-r * .2:.1f} {sx * r * .18:.1f} {-r * .5:.1f}" stroke="#F1E2C4" stroke-width="{r * .16:.1f}" fill="none" stroke-linecap="round"/>'
    else:
        o += f'<path d="M{x:.1f} {y - r * .92:.1f} V{y - r * 1.25:.1f}" stroke="#3E7D4E" stroke-width="{max(1.2, r * .07):.1f}" stroke-linecap="round"/>'
        for sx in (-1, 1):
            o += f'<ellipse cx="{x + sx * r * .26:.1f}" cy="{y - r * 1.3:.1f}" rx="{r * .28:.1f}" ry="{r * .13:.1f}" fill="#7FCB8F" transform="rotate({-28 * sx} {x + sx * r * .26:.1f} {y - r * 1.3:.1f})"/>'
    for sx in (-1, 1):   # cheeks
        o += f'<ellipse cx="{x + sx * r * .66:.1f}" cy="{y + r * .12:.1f}" rx="{r * .15:.1f}" ry="{r * .09:.1f}" fill="#F49AB0" opacity=".85"/>'
    return o + eyes(x, y - r * .18, r)

# ---------- the cast, drawn (CAST): Moss plays the child, Otto the grown-up, Mosto a second child, Mochi a second
# grown-up — on the rig's staging, the same placement as their 3D figures (tools/scene3d.py), drawn flat in the
# picture book's soft volume ----------
CAST = "--cast" in sys.argv
CAST_FACES = []   # this picture's grown-ups' faces: (x, y, radius, facing) — kept clear of children and held things
def cast_role(s):
    who = getattr(s, "who", None)
    return {"child": "moss", "adult": "otto", "peer": "mosto", "adult2": "mochi"}.get(who, "moss" if s.kind == "child" else "otto")

CAST_PEOPLE = {}   # this picture's people by role key ("adult", "child", …), for placing one beside another

def cast_place(s):
    """Where a character of the cast stands and how: (x, y, H, deg, squash). The cast are not people: no long limbs,
    no kneeling or sitting cross-legged — they stand on the floor in their own shape (Moss a soft stone on short
    legs, Otto a tall lamp that leans toward Moss and turns his lamp head), at the rig's place; the rig's pose only
    colours how they stand (a crawl leans forward, tummy time squashes a little, a chair seats them)."""
    role = cast_role(s); age = getattr(s, "age", 12)
    if role == "moss": H = 100 * (0.8 + 0.3 * min(36, age) / 36)
    elif role == "mosto": H = 98
    elif role == "otto": H = 170
    else: H = 165
    if s.pose == "bundle": H *= 0.72
    x = (s.hip[0] + s.headc[0]) / 2 if s.pose != "bundle" else s.bundle_c[0]
    y = GROUND
    if s.pose == "chair": y = s.hip[1] + s.d["lw"] * 0.4
    held = s.pose == "bundle" or (s.kind == "child" and s.hip[1] < GROUND - 120)
    if held and "adult" in CAST_PEOPLE:
        # a held baby sits on the floor right beside the grown-up, on the side it faces
        a = CAST_PEOPLE["adult"]; ax = (a.hip[0] + a.headc[0]) / 2
        x = ax + a.f * (170 * 0.64 / 2 + H / 1.72 * 1.05 + 30); y = GROUND
    # never cut by the picture's edge
    half = H * (0.62 if role in ("moss", "mosto") else 0.4) * (1.5 if role == "mosto" else 1.0)
    z, c0 = VIEW["z"], VIEW["cx"]
    x = min(max(x, c0 - c0 / z + half + 6), c0 + (W - c0) / z - half - 6)
    deg, sq = 0.0, 1.0
    if role in ("otto", "mochi"): deg = 10 * s.f
    elif s.pose == "crawl": deg = 16 * s.f
    elif s.pose in ("walk", "run"): deg = 6 * s.f
    elif s.pose == "prone": sq = 0.86; deg = 8 * s.f
    elif s.pose == "lieback": sq = 0.9; deg = -8 * s.f
    return x, y, H, deg, sq

def cast_point(s, k):
    """A point k of the way up the character's body (0 the base, 1 the crown), leaning with it."""
    x, y, H, deg, sq = cast_place(s); r = math.radians(deg)
    return (x + math.sin(r) * H * k * sq, y - math.cos(r) * H * k * sq)

def cast_face(s): return cast_point(s, 0.6 if cast_role(s) in ("moss", "mosto") else 0.58)
def cast_top(s): return cast_point(s, 0.95)
def cast_head(s):
    t = cast_top(s); return (t[0], t[1] - 6)
def cast_hold(s):
    """Where a held thing goes: in front of Moss, hugged at mid height; for a grown-up, set down on the floor in
    front of it, toward the child (Otto has no hands — he brings things by leaning and lighting them)."""
    x, y, H, deg, sq = cast_place(s)
    if s.kind == "child": return (x + s.f * H * 0.42, y - H * 0.42)
    return (x + s.f * H * 0.42, GROUND)

def _look(s):
    t = s.look if isinstance(s.look, (tuple, list)) and len(s.look) == 2 and all(isinstance(v, (int, float)) for v in s.look) else None
    if t is None: return (0.55 * s.f, 0.05)
    f = cast_face(s); dx, dy = t[0] - f[0], t[1] - f[1]; d = max(1.0, math.hypot(dx, dy))
    return (max(-0.8, min(0.8, dx / d * 0.8)), max(-0.6, min(0.6, dy / d * 0.6)))

def _eye(sv, x, y, rx, ry, look, shut=False):
    if shut:
        sv.add(f'<path d="M{x - rx:.1f} {y:.1f} q{rx:.1f} {ry * .7:.1f} {rx * 2:.1f} 0" stroke="{INK}" stroke-width="{max(1.6, rx * .22):.1f}" fill="none" stroke-linecap="round"/>')
        return
    sv.add(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="#FFFFFF"/>')
    px, py = x + look[0] * rx * .38, y + look[1] * ry * .38
    sv.add(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{min(rx, ry) * .62:.1f}" fill="{INK}"/><circle cx="{px - rx * .2:.1f}" cy="{py - ry * .25:.1f}" r="{min(rx, ry) * .2:.1f}" fill="#FFFFFF"/>')

def draw_cast(s, sv):
    role = cast_role(s); r = s.d["head"]
    shut = s.expr in ("sleep", "calm") or s.pose == "bundle"
    look = _look(s)
    x, y, H, deg, sq = cast_place(s)
    body = {"moss": "#55703F", "mosto": "#5E43A0", "otto": "#22386E", "mochi": "#F4E4CF"}[role]
    sv.shadow(x, GROUND + 3 if y >= GROUND - 2 else y + 3, H * (0.42 if role in ("moss", "mosto") else 0.36), 8, .2)
    sv.add(f'<g transform="rotate({deg:.1f} {x:.1f} {y:.1f}) translate({x:.1f} {y:.1f}) scale(1 {sq:.2f}) translate({-x:.1f} {-y:.1f})">')
    if role in ("moss", "mosto"):
        R = H / 1.72
        cx, cy = x, y - R * 0.95
        if s.pose == "bundle":
            sv.add(f'<path d="M{cx - R * 1.15:.1f} {y:.1f} Q{cx - R * 1.2:.1f} {cy:.1f} {cx:.1f} {cy + R * .1:.1f} Q{cx + R * 1.2:.1f} {cy:.1f} {cx + R * 1.15:.1f} {y:.1f} Z" fill="{sv.lin("#F6D58C", 120)}"/>')
        for sx in (-1, 1):   # the short dark legs and feet
            sv.add(f'<rect x="{cx + sx * R * .36 - R * .1:.1f}" y="{y - R * .3:.1f}" width="{R * .2:.1f}" height="{R * .26:.1f}" rx="{R * .1:.1f}" fill="#22231F"/>')
            sv.add(f'<ellipse cx="{cx + sx * R * .38 + s.f * R * .06:.1f}" cy="{y - R * .04:.1f}" rx="{R * .2:.1f}" ry="{R * .09:.1f}" fill="#22231F"/>')
        sv.add(f'<path d="M{cx - R * 1.02:.1f} {cy + R * .45:.1f} C{cx - R * 1.1:.1f} {cy - R * .55:.1f} {cx - R * .5:.1f} {cy - R * .95:.1f} {cx:.1f} {cy - R * .95:.1f} C{cx + R * .55:.1f} {cy - R * .95:.1f} {cx + R * 1.1:.1f} {cy - R * .5:.1f} {cx + R * 1.02:.1f} {cy + R * .45:.1f} C{cx + R * .9:.1f} {cy + R * .85:.1f} {cx - R * .9:.1f} {cy + R * .85:.1f} {cx - R * 1.02:.1f} {cy + R * .45:.1f} Z" fill="{sv.rad(body)}"/>')
        sv.add(f'<ellipse cx="{cx - R * .4:.1f}" cy="{cy - R * .5:.1f}" rx="{R * .32:.1f}" ry="{R * .16:.1f}" fill="#FFFFFF" opacity=".16" transform="rotate(-20 {cx - R * .4:.1f} {cy - R * .5:.1f})"/>')
        if role == "moss":
            sv.add(f'<path d="M{cx:.1f} {cy - R * .92:.1f} V{cy - R * 1.28:.1f}" stroke="#3E7D4E" stroke-width="{max(2, R * .07):.1f}" stroke-linecap="round"/>')
            for sx in (-1, 1):
                sv.add(f'<ellipse cx="{cx + sx * R * .27:.1f}" cy="{cy - R * 1.32:.1f}" rx="{R * .3:.1f}" ry="{R * .14:.1f}" fill="{sv.lin("#7FCB8F")}" transform="rotate({-28 * sx} {cx + sx * R * .27:.1f} {cy - R * 1.32:.1f})"/>')
        else:
            for sx in (-1, 1):
                sv.add(f'<path d="M{cx + sx * R * .6:.1f} {cy - R * .6:.1f} q{sx * R * .32:.1f} {-R * .22:.1f} {sx * R * .18:.1f} {-R * .52:.1f}" stroke="#F1E2C4" stroke-width="{R * .16:.1f}" fill="none" stroke-linecap="round"/>')
                sv.add(f'<path d="M{cx + sx * R * .95:.1f} {cy - R * .1:.1f} l{sx * R * .5:.1f} {-R * .25:.1f} l{-sx * R * .12:.1f} {R * .2:.1f} l{sx * R * .1:.1f} {R * .16:.1f} Z" fill="#3E2A72"/>')
            sv.add(f'<g transform="rotate(14 {cx + R * .1:.1f} {cy - R * .95:.1f})"><path d="M{cx - R * .3:.1f} {cy - R * .88:.1f} l{R * .08:.1f} {-R * .38:.1f} l{R * .2:.1f} {R * .22:.1f} l{R * .12:.1f} {-R * .34:.1f} l{R * .12:.1f} {R * .34:.1f} l{R * .2:.1f} {-R * .22:.1f} l{R * .08:.1f} {R * .38:.1f} Z" fill="#C9A24A"/></g>')
            sv.add(f'<path d="M{cx - R * .9:.1f} {cy + R * .5:.1f} q{-R * .5:.1f} {R * .1:.1f} {-R * .6:.1f} {-R * .4:.1f}" stroke="{body}" stroke-width="{R * .1:.1f}" fill="none" stroke-linecap="round"/>')
            sv.add(pict("heart", cx - R * 1.5, cy + R * .02, R / 60).replace("#FF6F91", "#B9A6E8"))
        for sx in (-1, 1):
            sv.add(f'<ellipse cx="{cx + sx * R * .66:.1f}" cy="{cy + R * .12:.1f}" rx="{R * .15:.1f}" ry="{R * .09:.1f}" fill="#F49AB0" opacity=".85"/>')
        er = R * (0.22 if s.expr == "wow" else 0.19)
        for sx in (-1, 1): _eye(sv, cx + sx * R * .34, cy - R * .2, er * .8, er, look, shut)
        if role == "mosto":
            for sx in (-1, 1): sv.add(f'<path d="M{cx + sx * R * .55:.1f} {cy - R * .5:.1f} L{cx + sx * R * .2:.1f} {cy - R * .4:.1f}" stroke="{INK}" stroke-width="{R * .06:.1f}" stroke-linecap="round"/>')
            sv.add(f'<path d="M{cx + R * .02:.1f} {cy + R * .08:.1f} l{R * .05:.1f} {R * .1:.1f} l{R * .05:.1f} {-R * .1:.1f}Z" fill="#FFFFFF"/>')
        elif s.expr in ("talk", "sing", "wow", "laugh") and not shut:
            sv.add(f'<ellipse cx="{cx:.1f}" cy="{cy + R * .12:.1f}" rx="{R * .08:.1f}" ry="{R * .07:.1f}" fill="#5B2A2A"/>')
        if getattr(s, "holding", False):
            # a pair of small round hands, out only to hold something
            for dy in (-0.05, 0.25):
                sv.add(f'<circle cx="{cx + s.f * R * .78:.1f}" cy="{cy + R * dy:.1f}" r="{R * .15:.1f}" fill="{sv.rad(dark(body, .05))}"/>')
    elif role == "otto":
        w = H * 0.64
        cx, top, bot = x, y - H, y
        for sx in (-1, 1):   # short dark legs and feet
            sv.add(f'<rect x="{cx + sx * w * .2 - w * .06:.1f}" y="{bot - w * .2:.1f}" width="{w * .12:.1f}" height="{w * .16:.1f}" rx="{w * .06:.1f}" fill="#22231F"/>')
            sv.add(f'<ellipse cx="{cx + sx * w * .22 + s.f * w * .04:.1f}" cy="{bot - w * .03:.1f}" rx="{w * .12:.1f}" ry="{w * .05:.1f}" fill="#22231F"/>')
        bot -= w * .1
        sv.add(f'<path d="M{cx - w / 2:.1f} {bot - w * .2:.1f} V{top + w * .55:.1f} A{w / 2:.1f} {w * .55:.1f} 0 0 1 {cx + w / 2:.1f} {top + w * .55:.1f} V{bot - w * .2:.1f} Q{cx + w / 2:.1f} {bot:.1f} {cx:.1f} {bot:.1f} Q{cx - w / 2:.1f} {bot:.1f} {cx - w / 2:.1f} {bot - w * .2:.1f} Z" fill="{sv.lin("#2A4580", 120)}"/>')
        sv.add(f'<path d="M{cx - w / 2:.1f} {bot - H * .3:.1f} H{cx + w / 2:.1f} V{bot - w * .2:.1f} Q{cx + w / 2:.1f} {bot:.1f} {cx:.1f} {bot:.1f} Q{cx - w / 2:.1f} {bot:.1f} {cx - w / 2:.1f} {bot - w * .2:.1f} Z" fill="#15264D"/>')
        sv.add(f'<ellipse cx="{cx - w * .2:.1f}" cy="{top + w * .4:.1f}" rx="{w * .14:.1f}" ry="{w * .24:.1f}" fill="#FFFFFF" opacity=".1"/>')
        f = s.f; rt = top + 2
        sv.add(f'<path d="M{cx:.1f} {rt:.1f} C{cx:.1f} {rt - H * .34:.1f} {cx + f * w * .7:.1f} {rt - H * .4:.1f} {cx + f * w * .66:.1f} {rt - H * .1:.1f}" stroke="#1C2F5E" stroke-width="{max(2.5, w * .05):.1f}" fill="none" stroke-linecap="round"/>')
        sv.add(f'<circle cx="{cx + f * w * .66:.1f}" cy="{rt - H * .06:.1f}" r="{w * .1:.1f}" fill="{sv.rad("#D4A21C")}"/>')
        ey = top + H * .42
        _eye(sv, cx + f * w * .06, ey, w * .26, w * .22, look, shut)
        if not shut: sv.add(f'<path d="M{cx + f * w * .06 - w * .3:.1f} {ey - w * .14:.1f} Q{cx + f * w * .06:.1f} {ey - w * .3:.1f} {cx + f * w * .06 + w * .3:.1f} {ey - w * .14:.1f}" fill="#22386E" opacity=".85"/>')
        if s.expr in ("smile", "talk", "sing"):
            sv.add(f'<path d="M{cx - w * .02:.1f} {ey + w * .34:.1f} q{w * .1:.1f} {w * .03:.1f} {w * .18:.1f} {-w * .05:.1f}" stroke="{INK}" stroke-width="{max(1.5, w * .025):.1f}" fill="none" stroke-linecap="round"/>')
    else:
        R = H / 2.2
        cx, cy = x, y - R * 1.0
        for sx in (-1, 1):
            sv.add(f'<ellipse cx="{cx + sx * R * .4:.1f}" cy="{y - R * .06:.1f}" rx="{R * .2:.1f}" ry="{R * .08:.1f}" fill="#22231F"/>')
        sv.add(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{R * 1.05:.1f}" ry="{R * .95:.1f}" fill="{sv.rad(body)}"/>')
        sv.add(f'<ellipse cx="{cx:.1f}" cy="{cy - R * .78:.1f}" rx="{R * .8:.1f}" ry="{R * .38:.1f}" fill="{sv.rad("#E07A6A")}"/><circle cx="{cx:.1f}" cy="{cy - R * 1.2:.1f}" r="{R * .14:.1f}" fill="#F7EFE4"/>')
        for sx in (-1, 1):
            _eye(sv, cx + sx * R * .3, cy - R * .05, R * .13, R * .16, look, shut)
            sv.add(f'<ellipse cx="{cx + sx * R * .6:.1f}" cy="{cy + R * .2:.1f}" rx="{R * .15:.1f}" ry="{R * .09:.1f}" fill="#F49AB0" opacity=".85"/>')
    sv.add('</g>')

def pict(kind, x, y, s):
    """A small picture of a thing, centred on (x, y): for cards, bubbles and real objects."""
    if kind == "apple":
        return (f'<circle cx="{x:.1f}" cy="{y + 2 * s:.1f}" r="{18 * s:.1f}" fill="#F2554B"/><path d="M{x:.1f} {y - 14 * s:.1f} q{4 * s:.1f} {-10 * s:.1f} {12 * s:.1f} {-10 * s:.1f}" stroke="#4DB86A" stroke-width="{4 * s:.1f}" fill="none" stroke-linecap="round"/>')
    if kind == "cup":
        return f'<path d="M{x - 14 * s:.1f} {y - 16 * s:.1f} H{x + 14 * s:.1f} L{x + 10 * s:.1f} {y + 18 * s:.1f} H{x - 10 * s:.1f} Z" fill="#1FB5A6"/>'
    if kind == "ball":
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{17 * s:.1f}" fill="#FF8A3D"/><path d="M{x - 17 * s:.1f} {y:.1f} Q{x:.1f} {y + 8 * s:.1f} {x + 17 * s:.1f} {y:.1f}" stroke="#FFFFFF" stroke-width="{3 * s:.1f}" fill="none"/>'
    if kind == "car":
        return (f'<rect x="{x - 20 * s:.1f}" y="{y - 6 * s:.1f}" width="{40 * s:.1f}" height="{14 * s:.1f}" rx="{5 * s:.1f}" fill="#4C9BE8"/><rect x="{x - 10 * s:.1f}" y="{y - 16 * s:.1f}" width="{20 * s:.1f}" height="{12 * s:.1f}" rx="{4 * s:.1f}" fill="#4C9BE8"/>'
                f'<circle cx="{x - 11 * s:.1f}" cy="{y + 9 * s:.1f}" r="{5 * s:.1f}" fill="#3B3330"/><circle cx="{x + 11 * s:.1f}" cy="{y + 9 * s:.1f}" r="{5 * s:.1f}" fill="#3B3330"/>')
    if kind == "sun":
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{14 * s:.1f}" fill="#FFC23D"/>' + "".join(f'<path d="M{x + math.cos(a) * 19 * s:.1f} {y + math.sin(a) * 19 * s:.1f} L{x + math.cos(a) * 26 * s:.1f} {y + math.sin(a) * 26 * s:.1f}" stroke="#FFC23D" stroke-width="{3 * s:.1f}" stroke-linecap="round"/>' for a in [k * math.pi / 4 for k in range(8)])
    if kind == "cat":
        return (f'<circle cx="{x:.1f}" cy="{y + 2 * s:.1f}" r="{15 * s:.1f}" fill="#FF8A3D"/><path d="M{x - 13 * s:.1f} {y - 6 * s:.1f} l{2 * s:.1f} {-14 * s:.1f} l{8 * s:.1f} {8 * s:.1f}Z M{x + 13 * s:.1f} {y - 6 * s:.1f} l{-2 * s:.1f} {-14 * s:.1f} l{-8 * s:.1f} {8 * s:.1f}Z" fill="#FF8A3D"/>'
                f'<circle cx="{x - 5 * s:.1f}" cy="{y:.1f}" r="{2 * s:.1f}" fill="{INK}"/><circle cx="{x + 5 * s:.1f}" cy="{y:.1f}" r="{2 * s:.1f}" fill="{INK}"/>')
    if kind == "sock":
        return f'<path d="M{x - 6 * s:.1f} {y - 18 * s:.1f} h{12 * s:.1f} v{20 * s:.1f} q0 {8 * s:.1f} {10 * s:.1f} {8 * s:.1f} v{8 * s:.1f} h{-18 * s:.1f} q{-4 * s:.1f} 0 {-4 * s:.1f} {-6 * s:.1f}Z" fill="#FF6F91"/>'
    if kind == "heart":
        return f'<path d="M{x:.1f} {y + 12 * s:.1f} C{x - 26 * s:.1f} {y - 6 * s:.1f} {x - 10 * s:.1f} {y - 22 * s:.1f} {x:.1f} {y - 8 * s:.1f} C{x + 10 * s:.1f} {y - 22 * s:.1f} {x + 26 * s:.1f} {y - 6 * s:.1f} {x:.1f} {y + 12 * s:.1f} Z" fill="#FF6F91"/>'
    if kind == "note":
        return f'<path d="M{x - 4 * s:.1f} {y + 10 * s:.1f} V{y - 16 * s:.1f} L{x + 12 * s:.1f} {y - 20 * s:.1f} V{y + 4 * s:.1f}" stroke="#9B7BEA" stroke-width="{4 * s:.1f}" fill="none"/><ellipse cx="{x - 9 * s:.1f}" cy="{y + 11 * s:.1f}" rx="{7 * s:.1f}" ry="{5 * s:.1f}" fill="#9B7BEA"/><ellipse cx="{x + 7 * s:.1f}" cy="{y + 5 * s:.1f}" rx="{7 * s:.1f}" ry="{5 * s:.1f}" fill="#9B7BEA"/>'
    if kind == "dots":
        return "".join(f'<circle cx="{x + dx * s:.1f}" cy="{y:.1f}" r="{4.5 * s:.1f}" fill="#8A7F76"/>' for dx in (-12, 0, 12))
    if kind == "q":
        return f'<path d="M{x - 8 * s:.1f} {y - 8 * s:.1f} q0 {-10 * s:.1f} {9 * s:.1f} {-10 * s:.1f} q{9 * s:.1f} 0 {9 * s:.1f} {9 * s:.1f} q0 {7 * s:.1f} {-9 * s:.1f} {11 * s:.1f} v{4 * s:.1f}" stroke="#4C9BE8" stroke-width="{4.5 * s:.1f}" fill="none" stroke-linecap="round"/><circle cx="{x + 1 * s:.1f}" cy="{y + 16 * s:.1f}" r="{3 * s:.1f}" fill="#4C9BE8"/>'
    if kind == "sad":
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{16 * s:.1f}" fill="#4C9BE8"/><circle cx="{x - 6 * s:.1f}" cy="{y - 4 * s:.1f}" r="{2.4 * s:.1f}" fill="#FFFFFF"/><circle cx="{x + 6 * s:.1f}" cy="{y - 4 * s:.1f}" r="{2.4 * s:.1f}" fill="#FFFFFF"/><path d="M{x - 7 * s:.1f} {y + 9 * s:.1f} q{7 * s:.1f} {-7 * s:.1f} {14 * s:.1f} 0" stroke="#FFFFFF" stroke-width="{2.6 * s:.1f}" fill="none" stroke-linecap="round"/>'
    if kind == "happy":
        return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{16 * s:.1f}" fill="#FFC23D"/><circle cx="{x - 6 * s:.1f}" cy="{y - 4 * s:.1f}" r="{2.4 * s:.1f}" fill="{INK}"/><circle cx="{x + 6 * s:.1f}" cy="{y - 4 * s:.1f}" r="{2.4 * s:.1f}" fill="{INK}"/><path d="M{x - 7 * s:.1f} {y + 5 * s:.1f} q{7 * s:.1f} {7 * s:.1f} {14 * s:.1f} 0" stroke="{INK}" stroke-width="{2.6 * s:.1f}" fill="none" stroke-linecap="round"/>'
    if kind == "zh":  # the sound of one language
        return f'<rect x="{x - 16 * s:.1f}" y="{y - 14 * s:.1f}" width="{32 * s:.1f}" height="{28 * s:.1f}" rx="{6 * s:.1f}" fill="#F2554B"/><circle cx="{x:.1f}" cy="{y:.1f}" r="{6 * s:.1f}" fill="#FFC23D"/>'
    if kind == "en":
        return f'<rect x="{x - 16 * s:.1f}" y="{y - 14 * s:.1f}" width="{32 * s:.1f}" height="{28 * s:.1f}" rx="{6 * s:.1f}" fill="#4C9BE8"/><path d="M{x - 9 * s:.1f} {y:.1f} h{18 * s:.1f} M{x:.1f} {y - 8 * s:.1f} v{16 * s:.1f}" stroke="#FFFFFF" stroke-width="{3.6 * s:.1f}" stroke-linecap="round"/>'
    if kind == "moon":
        return f'<path d="M{x + 6 * s:.1f} {y - 16 * s:.1f} A16 16 0 1 0 {x + 8 * s:.1f} {y + 14 * s:.1f} A12 12 0 1 1 {x + 6 * s:.1f} {y - 16 * s:.1f} Z" fill="#FFC23D"/>'
    if kind == "hand":
        return f'<circle cx="{x:.1f}" cy="{y + 4 * s:.1f}" r="{11 * s:.1f}" fill="{SKIN[0]}"/>' + "".join(f'<rect x="{x + dx * s - 3 * s:.1f}" y="{y - 16 * s:.1f}" width="{6 * s:.1f}" height="{16 * s:.1f}" rx="{3 * s:.1f}" fill="{SKIN[0]}"/>' for dx in (-8, -3, 2, 7))
    if kind == "scribble":
        return "".join(f'<path d="M{x - 18 * s:.1f} {y + (i * 9 - 9) * s:.1f} q{9 * s:.1f} {-12 * s:.1f} {18 * s:.1f} 0 t{18 * s:.1f} 0" stroke="{c}" stroke-width="{4 * s:.1f}" fill="none" stroke-linecap="round"/>' for i, c in enumerate(["#F2554B", "#4C9BE8", "#4DB86A"]))
    if kind == "tower":
        return "".join(f'<rect x="{x - 10 * s:.1f}" y="{y + 8 * s - i * 14 * s:.1f}" width="{20 * s:.1f}" height="{13 * s:.1f}" rx="{3 * s:.1f}" fill="{c}"/>' for i, c in enumerate(["#4C9BE8", "#FFC23D", "#F2554B"]))
    if kind == "leaf":
        return f'<path d="M{x:.1f} {y + 16 * s:.1f} C{x - 16 * s:.1f} {y + 4 * s:.1f} {x - 12 * s:.1f} {y - 14 * s:.1f} {x:.1f} {y - 18 * s:.1f} C{x + 12 * s:.1f} {y - 14 * s:.1f} {x + 16 * s:.1f} {y + 4 * s:.1f} {x:.1f} {y + 16 * s:.1f} Z" fill="#FF8A3D"/>'
    if kind == "eye":
        return f'<path d="M{x - 18 * s:.1f} {y:.1f} Q{x:.1f} {y - 16 * s:.1f} {x + 18 * s:.1f} {y:.1f} Q{x:.1f} {y + 16 * s:.1f} {x - 18 * s:.1f} {y:.1f} Z" fill="#FFFFFF" stroke="#4C9BE8" stroke-width="{3 * s:.1f}"/><circle cx="{x:.1f}" cy="{y:.1f}" r="{6 * s:.1f}" fill="#4C9BE8"/>'
    if kind == "bird":
        return f'<ellipse cx="{x:.1f}" cy="{y + 2 * s:.1f}" rx="{14 * s:.1f}" ry="{10 * s:.1f}" fill="#4C9BE8"/><circle cx="{x + 10 * s:.1f}" cy="{y - 6 * s:.1f}" r="{7 * s:.1f}" fill="#4C9BE8"/><path d="M{x + 16 * s:.1f} {y - 6 * s:.1f} l{6 * s:.1f} {2 * s:.1f} l{-6 * s:.1f} {2 * s:.1f}Z" fill="#FFC23D"/>'
    if kind == "shirt":
        return f'<path d="M{x - 14 * s:.1f} {y - 14 * s:.1f} L{x - 5 * s:.1f} {y - 17 * s:.1f} Q{x:.1f} {y - 13 * s:.1f} {x + 5 * s:.1f} {y - 17 * s:.1f} L{x + 14 * s:.1f} {y - 14 * s:.1f} L{x + 19 * s:.1f} {y - 5 * s:.1f} L{x + 12 * s:.1f} {y - 3 * s:.1f} V{y + 15 * s:.1f} H{x - 12 * s:.1f} V{y - 3 * s:.1f} L{x - 19 * s:.1f} {y - 5 * s:.1f} Z" fill="#4C9BE8"/>'
    if kind == "check":
        return f'<path d="M{x - 10 * s:.1f} {y:.1f} l{7 * s:.1f} {7 * s:.1f} l{13 * s:.1f} {-14 * s:.1f}" stroke="#4DB86A" stroke-width="{5 * s:.1f}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
    if kind == "stop":
        return f'<rect x="{x - 9 * s:.1f}" y="{y - 12 * s:.1f}" width="{6 * s:.1f}" height="{24 * s:.1f}" rx="{2 * s:.1f}" fill="#F2554B"/><rect x="{x + 3 * s:.1f}" y="{y - 12 * s:.1f}" width="{6 * s:.1f}" height="{24 * s:.1f}" rx="{2 * s:.1f}" fill="#F2554B"/>'
    if kind == "people" and CAST:
        return cast_icon("otto", x - 9 * s, y + 2 * s, 9 * s) + cast_icon("moss", x + 10 * s, y + 6 * s, 8 * s)
    if kind == "people":
        return f'<circle cx="{x - 9 * s:.1f}" cy="{y - 6 * s:.1f}" r="{6 * s:.1f}" fill="{SKIN[0]}"/><circle cx="{x + 9 * s:.1f}" cy="{y - 2 * s:.1f}" r="{5 * s:.1f}" fill="{SKIN[1]}"/><rect x="{x - 16 * s:.1f}" y="{y + 1 * s:.1f}" width="{14 * s:.1f}" height="{14 * s:.1f}" rx="{5 * s:.1f}" fill="#E2728C"/><rect x="{x + 3 * s:.1f}" y="{y + 4 * s:.1f}" width="{12 * s:.1f}" height="{11 * s:.1f}" rx="{4 * s:.1f}" fill="#FFC23D"/>'
    if kind == "lantern":
        return f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{16 * s:.1f}" ry="{14 * s:.1f}" fill="#F2554B"/><rect x="{x - 6 * s:.1f}" y="{y - 18 * s:.1f}" width="{12 * s:.1f}" height="{5 * s:.1f}" fill="#FFC23D"/>'
    if kind == "bowl":
        return f'<path d="M{x - 16 * s:.1f} {y - 4 * s:.1f} Q{x:.1f} {y + 18 * s:.1f} {x + 16 * s:.1f} {y - 4 * s:.1f} Z" fill="#1FB5A6"/><circle cx="{x - 4 * s:.1f}" cy="{y - 6 * s:.1f}" r="{5 * s:.1f}" fill="#FFC23D"/>'
    if kind == "drop":
        return f'<path d="M{x:.1f} {y - 16 * s:.1f} Q{x + 14 * s:.1f} {y + 2 * s:.1f} {x:.1f} {y + 12 * s:.1f} Q{x - 14 * s:.1f} {y + 2 * s:.1f} {x:.1f} {y - 16 * s:.1f} Z" fill="#4C9BE8"/>'
    if kind == "bed" and CAST:
        return f'<rect x="{x - 18 * s:.1f}" y="{y - 2 * s:.1f}" width="{36 * s:.1f}" height="{12 * s:.1f}" rx="{4 * s:.1f}" fill="#9B7BEA"/>' + cast_icon("moss", x - 9 * s, y - 6 * s, 6 * s)
    if kind == "bed":
        return f'<rect x="{x - 18 * s:.1f}" y="{y - 2 * s:.1f}" width="{36 * s:.1f}" height="{12 * s:.1f}" rx="{4 * s:.1f}" fill="#9B7BEA"/><circle cx="{x - 10 * s:.1f}" cy="{y - 6 * s:.1f}" r="{6 * s:.1f}" fill="{SKIN[1]}"/>'
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
    if CAST:
        # Otto's lamp arches forward over the side he faces: a sign over his head floats on the other side, clear of
        # the rod and the bead
        src = m.get("at") if k == "badge" else m.get("from", "adult.mouth") if k == "say" else None
        if isinstance(src, str) and src.split(".")[0].startswith("adult") and src.split(".")[0] in ppl:
            f = ppl[src.split(".")[0]].f
            if k == "badge": m = dict(m, dx=-f * max(40, abs(m.get("dx", 0))))
            else: m = dict(m, side=-f)
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
            sv.add(f'<path d="M{a[0] + d * r * .5:.1f} {a[1] - r * .8:.1f} A{r} {r} 0 0 {1 if d > 0 else 0} {a[0] + d * r * .5:.1f} {a[1] + r * .8:.1f}" fill="none" stroke="{m.get("c", "#9B7BEA")}" stroke-width="5" stroke-linecap="round" opacity="{1 - i * .25:.2f}"/>')
    elif k == "look":  # a dotted line of sight
        a, b = pt(m["a"]), pt(m["b"])
        sv.add(f'<path d="M{a[0]:.1f} {a[1]:.1f} L{b[0]:.1f} {b[1]:.1f}" stroke="{m.get("c", "#4C9BE8")}" stroke-width="5" stroke-dasharray="1 13" stroke-linecap="round" fill="none"/>')
    elif k == "arrow":  # a motion arrow along a gentle curve
        a, b = pt(m["a"]), pt(m["b"]); bend = m.get("bend", -40); c = m.get("c", "#FF8A3D")
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
            sv.add(f'<rect x="{a[0] - r * .36:.1f}" y="{a[1] - r * .42:.1f}" width="{r * .24:.1f}" height="{r * .84:.1f}" rx="3" fill="#9B7BEA"/><rect x="{a[0] + r * .12:.1f}" y="{a[1] - r * .42:.1f}" width="{r * .24:.1f}" height="{r * .84:.1f}" rx="3" fill="#9B7BEA"/>')
        elif sy == "repeat":
            sv.add(f'<path d="M{a[0] - r * .5:.1f} {a[1]:.1f} A{r * .5:.1f} {r * .5:.1f} 0 1 1 {a[0]:.1f} {a[1] + r * .5:.1f}" stroke="#1FB5A6" stroke-width="{r * .16:.1f}" fill="none" stroke-linecap="round"/><path d="M{a[0] - r * .74:.1f} {a[1] - r * .16:.1f} L{a[0] - r * .5:.1f} {a[1] + r * .12:.1f} L{a[0] - r * .24:.1f} {a[1] - r * .16:.1f}" stroke="#1FB5A6" stroke-width="{r * .16:.1f}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
        elif sy == "clock":
            sv.add(f'<circle cx="{a[0]:.1f}" cy="{a[1]:.1f}" r="{r * .55:.1f}" fill="none" stroke="#FF8A3D" stroke-width="{r * .13:.1f}"/><path d="M{a[0]:.1f} {a[1] - r * .32:.1f} V{a[1]:.1f} H{a[0] + r * .24:.1f}" stroke="#FF8A3D" stroke-width="{r * .13:.1f}" fill="none" stroke-linecap="round"/>')
        elif sy == "grow":  # short, longer, longest
            for i in range(3): sv.add(f'<rect x="{a[0] - r * .5 + i * r * .36:.1f}" y="{a[1] + r * .4 - (i + 1) * r * .26:.1f}" width="{r * .24:.1f}" height="{(i + 1) * r * .26:.1f}" rx="2" fill="#4DB86A"/>')
        elif sy == "two":  # two choices
            sv.add(f'<circle cx="{a[0] - r * .3:.1f}" cy="{a[1]:.1f}" r="{r * .24:.1f}" fill="#4C9BE8"/><circle cx="{a[0] + r * .3:.1f}" cy="{a[1]:.1f}" r="{r * .24:.1f}" fill="#FF6F91"/>')
        else:
            sv.add(pict(sy, a[0], a[1], r / 26 * .95))
    elif k == "sparkle":
        a = pt(m["at"])
        for dx, dy, r in ((0, 0, 9), (22, -16, 6), (-18, -22, 5)):
            x, y = a[0] + dx, a[1] + dy
            sv.add(f'<path d="M{x:.1f} {y - r * 1.6:.1f} Q{x:.1f} {y:.1f} {x + r * 1.6:.1f} {y:.1f} Q{x:.1f} {y:.1f} {x:.1f} {y + r * 1.6:.1f} Q{x:.1f} {y:.1f} {x - r * 1.6:.1f} {y:.1f} Q{x:.1f} {y:.1f} {x:.1f} {y - r * 1.6:.1f} Z" fill="{m.get("c", "#FFC23D")}"/>')
    elif k == "zz":
        a = pt(m["at"])
        for i, s in enumerate((1, .75, .55)):
            x, y = a[0] + i * 20, a[1] - i * 22
            sv.add(f'<path d="M{x:.1f} {y:.1f} h{14 * s:.1f} l{-14 * s:.1f} {14 * s:.1f} h{14 * s:.1f}" stroke="#9B7BEA" stroke-width="{4 * s:.1f}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    elif k == "hands_cover":  # both adult hands over the face
        p = ppl[m.get("who", "adult")]; c = p.head(); r = p.d["head"]
        for dy in (-.25, .25):
            sv.add(f'<ellipse cx="{c[0] + p.f * r * .62:.1f}" cy="{c[1] + dy * r:.1f}" rx="{r * .42:.1f}" ry="{r * .3:.1f}" fill="{sv.rad(p.skin)}"/>')

# ---------- a scene ----------
def scene(spec, area, sv=None, watch=None):
    sv = sv or SVG()
    ground, back = AREA[area]
    setting = spec.get("set", "floor")
    if BACKDROP or setting == "outdoor": sv.add(f'<rect width="{W}" height="{H}" fill="{PAPER}"/>')
    if setting == "outdoor":
        sv.add(f'<rect width="{W}" height="{GROUND}" fill="#E6F2F8"/>')
        sv.add(f'<path d="M0 {GROUND - 40} Q{W * .3} {GROUND - 90} {W * .62} {GROUND - 50} T{W} {GROUND - 60} V{H} H0 Z" fill="#CFE6B8"/>')
        sv.add(f'<rect y="{GROUND}" width="{W}" height="{H - GROUND}" fill="#B9DA9C"/>')
    elif BACKDROP:
        # a soft disc of the area colour on the wall behind the action, lit from the upper left like the figures
        dc = spec.get("disc", 360)
        g = sv.id(); sv.defs.append(f'<radialGradient id="{g}" cx=".36" cy=".3" r=".8"><stop offset="0" stop-color="{light(back, .45)}"/>'
                                   f'<stop offset=".7" stop-color="{back}"/><stop offset="1" stop-color="{dark(back, .04)}"/></radialGradient>')
        sv.add(f'<circle cx="{dc}" cy="{GROUND - 150}" r="210" fill="url(#{g})"/>')
        # the floor runs the full width of the picture into a soft horizon (a room, not an island): lighter toward
        # the back, a breath deeper at the front edge
        t = sv.id(); sv.defs.append(f'<linearGradient id="{t}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{light(ground, .45)}" stop-opacity="0"/>'
                                   f'<stop offset=".12" stop-color="{light(ground, .42)}"/><stop offset=".55" stop-color="{light(ground, .2)}"/><stop offset="1" stop-color="{ground}"/></linearGradient>')
        sv.add(f'<rect x="0" y="{GROUND - 46}" width="{W}" height="{H - GROUND + 46}" fill="url(#{t})"/>')
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
        # gestures toward one's own face: a hand at the chin (thinking, waiting), by the ear (listening), at the mouth (hush)
        if part in ("chin", "ear", "mouth"):
            c, r = p.head(), p.d["head"]
            return {"chin": (c[0] + p.f * r * .45, c[1] + r * .95), "ear": (c[0] - p.f * r * .4, c[1] + r * .1),
                    "mouth": (c[0] + p.f * r * 1.15, c[1] + r * .4)}[part]
        if part == "up": c = p.head(); return (c[0] + p.f * p.d["head"] * 1.3, c[1] - p.d["head"] * 1.6)   # a raised hand: waving, a hello
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
            built[who] = p_ = Person(kind, q["pose"], q["x"], face=q.get("f", 1 if kind == "adult" else -1), age=q.get("age", 30),
                                top=top, leg=leg, expr=q.get("e", "smile"), look=look, hands=hands, hair=q.get("hair"),
                                at=tuple(q["at"]) if "at" in q else None, tilt=q.get("tilt", 0), girl=GIRL and who == "child", lean=q.get("lean", 0))
            p_.who = who
    CAST_PEOPLE.clear(); CAST_PEOPLE.update(built)
    if CAST:
        for o in spec.get("objs", []):
            if isinstance(o.get("on"), str):
                w_ = o["on"].split(".")[0]
                if w_ in built and built[w_].kind == "child": built[w_].holding = True
    # back objects (scenery), shadows, people and front objects
    for o in spec.get("objs", []):
        if o.get("back"): obj(sv, o["k"], o.get("x", 360), o.get("y", GROUND), o.get("s", 1), o.get("c"), o.get("r", 0))
    for p in built.values():
        if CAST or p.pose == "bundle": pass   # the cast cast their own soft shadow where they stand
        elif p.pose not in ("prone", "lieback"): p.draw_shadow(sv)
        else:
            # lying down: the whole body on the floor — a long soft shade and a dark core along it
            sv.shadow(p.hip[0] - p.f * p.d["torso"] * .4, GROUND + 4, p.d["torso"] * 1.2, 11, .24)
            sv.shadow(p.hip[0] - p.f * p.d["torso"] * .4, GROUND + 2, p.d["torso"] * .9, 4, .32)
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
            w_ = o["on"].split(".")[0] if isinstance(o["on"], str) else None
            if CAST and w_ in built and o["on"].split(".")[-1] in ("hand", "hand2"):
                # the cast hold things their own way: Moss hugs it in front of him; a grown-up of the cast has set it
                # down on the floor in front of him, toward the child
                hx, hy = cast_hold(built[w_])
                if o["on"].endswith("hand2"): hx += built[w_].f * 26
                if built[w_].kind == "adult":
                    obj(sv, o["k"], hx + o.get("dx", 0), hy, o.get("s", 1), o.get("c"), o.get("r", 0)); continue
            obj(sv, o["k"], hx + o.get("dx", 0), hy + o.get("h", 30) * o.get("s", 1) + o.get("dy", 0), o.get("s", 1), o.get("c"), o.get("r", 0))
    for m in spec.get("marks", []): mark(sv, m, built)
    if spec.get("companions") and not FLAT: companions(sv, 540, GROUND + 2, 0.8, look=(-0.9, 0.1))
    sv.add('</g>')
    if watch: watchers(sv, *watch)
    return sv

# ---------- Moss and Otto in every step (docs/IP.md: the two are always there, watching, never doing it for them) ----------
def watch_box(x, base, k):
    """The space the two take with Moss's feet at (x, base): Moss in front, Otto a step behind to the right."""
    return (x - 38 * k, base - 80 * k, x + 58 * k, base + 6)

def busy(img, box, area):
    """How much of `box` already has something drawn in it (anything but paper, floor and backdrop tints)."""
    ground, back = AREA[area]
    keep = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in (PAPER, ground, back, "#E6F2F8", "#CFE6B8", "#B9DA9C")]
    sx, sy = img.width / W, img.height / H
    b = (max(0, box[0]), max(0, box[1]), min(W, box[2]), min(H, box[3]))
    if b[2] - b[0] < 40 or b != (box[0], box[1], box[2], box[3]): return 1.0   # off the picture
    crop = img.crop((int(b[0] * sx), int(b[1] * sy), int(b[2] * sx), int(b[3] * sy))).convert("RGB").resize((48, 40))
    px = list(crop.get_flattened_data()) if hasattr(crop, "get_flattened_data") else list(crop.getdata())
    return sum(1 for p in px if min(sum(abs(a - b) for a, b in zip(p, k)) for k in keep) > 36) / len(px)

def place_watchers(img, spec, area, prev=None):
    """A free place on the floor, as near the action as it can be without touching anything: the largest size first.
    Within one play they keep their place from step to step when it is still free (no jumping about)."""
    ch = spec.get("child", {})
    ax = ch["at"][0] if "at" in ch else ch.get("x", 400)
    cx0, z = spec.get("cx", 380), spec.get("zoom", 1.32)
    ax = cx0 + (ax - cx0) * z   # where the child is on the page (the scene is drawn zoomed about the floor)
    if prev and busy(img, watch_box(prev[0], prev[1], prev[2]), area) < 0.02: return prev[0], prev[1], prev[2], ax
    for k in (1.15, 1.0, 0.86):
        best = None
        # feet on the floor and high enough to stay in the 16:10 crop of the lead card (y 45–495 of 540)
        for base in (GROUND + 22, GROUND + 38):
            for x in range(int(40 * k), int(W - 60 * k), 12):
                if busy(img, watch_box(x, base, k), area) < 0.02:
                    d = abs(x - ax) + (base - GROUND) * 0.6
                    if best is None or d < best[0]: best = (d, x, base)
        if best: return best[1], best[2], k, ax
    return None

def watchers(sv, where, i, n):
    x, base, k, ax = where
    # they look into the picture, at the action; at the last step, the play done, they smile
    look = (0.9 if ax > x else -0.9, -0.5)
    companions(sv, x, base, k, look=look, happy=(i == n - 1))

def render(svg, path, width=1440, figs=None):
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=width)
    im = Image.open(io.BytesIO(png)).convert("RGB")
    if figs is not None: im = finish2d(im, figs, width)
    im.save(path, "WEBP", quality=90, method=6)
    return im.size

def figures_only(spec, area):
    """The people and things of a step alone, on nothing (no paper, disc, floor, shadows or marks): for their outline."""
    global BACKDROP
    keep = BACKDROP, SVG.shadow, mark
    BACKDROP = False; SVG.shadow = lambda *a, **k: None
    globals()["mark"] = lambda *a, **k: None
    try: return scene(spec, area).svg()
    finally: BACKDROP, SVG.shadow = keep[0], keep[1]; globals()["mark"] = keep[2]

_GRAIN = {}
def finish2d(im, figs_svg, width):
    """The print finish of the 2D pictures: a fine warm contour round every person and thing (so a light face or a
    white cloth never melts into a light page), a gentle contrast and colour lift, and the tooth of the paper."""
    from PIL import ImageFilter, ImageEnhance, ImageChops
    f = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=figs_svg.encode(), output_width=width))).convert("RGBA")
    a = f.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    k = max(3, int(width / 1440 * 6) | 1)
    ring = ImageChops.subtract(a.filter(ImageFilter.MaxFilter(k)), a).filter(ImageFilter.GaussianBlur(0.6))
    out = im.convert("RGBA")
    col = Image.new("RGBA", im.size, (84, 54, 30, 0)); col.putalpha(ring.point(lambda v: int(v * 0.42)))
    out.alpha_composite(col)
    # the jelly: a soft bright rim along every top-left edge (light catching a glossy surface) and a faint deeper
    # shade along the bottom-right ones — a little volume, still drawn
    d = max(3, int(width / 1440 * 7))
    tl = ImageChops.subtract(a, ImageChops.offset(a, d, d)).filter(ImageFilter.GaussianBlur(d * 0.6))
    br = ImageChops.subtract(a, ImageChops.offset(a, -d, -d)).filter(ImageFilter.GaussianBlur(d * 0.8))
    tl = ImageChops.multiply(tl, a); br = ImageChops.multiply(br, a)
    hi = Image.new("RGBA", im.size, (255, 255, 255, 0)); hi.putalpha(tl.point(lambda v: int(min(255, v * 0.42 * max(JELLY, 0.35)))))
    lo = Image.new("RGBA", im.size, (60, 30, 40, 0)); lo.putalpha(br.point(lambda v: int(v * 0.16)))
    if JELLY > 0: out.alpha_composite(lo); out.alpha_composite(hi)
    rgb = ImageEnhance.Color(ImageEnhance.Contrast(out.convert("RGB")).enhance(1.06)).enhance(1.04 + 0.1 * min(JELLY, 1))
    if im.size not in _GRAIN:
        n = Image.effect_noise(im.size, 22).filter(ImageFilter.GaussianBlur(0.5))
        _GRAIN[im.size] = n.point(lambda v: 255 - int(max(0, 128 - v) * 0.10))
    g = _GRAIN[im.size]
    return ImageChops.multiply(rgb, Image.merge("RGB", (g, g, g)))

# ---------- the companions (the app's own shapes, tools/mint.json), with the same soft volume ----------
MINT = json.load(open(os.path.join(ROOT, "tools", "mint.json")))
MOSS_BODY = "M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z"
MOSS_TUFTS = "M24 52 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M64 44 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M70 72 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M28 72 c2 -2 5 -2 7 0 c-2 1.6 -5 1.6 -7 0Z"
OTTO_BODY = "M30 84 C25 74 24 58 26 44 C28 28 38 16 52 16 C65 17 74 28 75 44 C76 60 74 75 70 84 C60 88 40 88 30 84Z"
OTTO_DIP = "M25.2 64 C35 68 64 68 75.4 63 C75 71 73 78 70 84 C60 88 40 88 30 84 C27.6 78 26 71 25.2 64Z"

def companions(sv, x, base, k, look=(-1, 0), happy=False):
    """Otto a step behind, Moss in front, feet on `base`; both look the way of `look`. `happy`: eyes closed in a smile,
    pink cheeks (the end of a play, docs/IP.md: a reply only to what really happened — the play done)."""
    lx, ly = look
    def legs(xs): return "".join(f'<rect x="{a}" y="80" width="6.5" height="10" rx="3.2" fill="#1C1D19"/>' for a in xs)
    def eye(cx, cy, rx, ry, pr, lid=0):
        if happy:
            return (f'<path d="M{cx - rx * .9:.1f},{cy + 1:.1f} Q{cx:.1f},{cy - ry * .95:.1f} {cx + rx * .9:.1f},{cy + 1:.1f}" stroke="#1C1D19" stroke-width="{max(1.8, ry * .34):.1f}" fill="none" stroke-linecap="round"/>'
                    f'<ellipse cx="{cx + (rx * .2 if rx > 10 else 0):.1f}" cy="{cy + ry * 1.25:.1f}" rx="{min(4.5, rx * .55):.1f}" ry="2.6" fill="#F49AB0" fill-opacity=".8"/>')
        px, py = cx + lx * (rx - pr - .4), cy + ly * (ry - pr - .4)
        e = f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#FBF9F3"/><circle cx="{px:.1f}" cy="{py:.1f}" r="{pr}" fill="#1C1D19"/><circle cx="{px - pr * .35:.1f}" cy="{py - pr * .35:.1f}" r="{pr * .3:.1f}" fill="#FFFFFF"/>'
        if lid: e += f'<path d="M{cx - rx - .5},{cy - ry - .5} H{cx + rx + .5} V{cy - ry + ry * 2 * lid} H{cx - rx - .5}Z" fill="#2D4A8C"/>'
        return e
    sv.shadow(x + 18 * k, base + 2, 60 * k, 9 * k)
    ox = x + 34 * k
    # as on the app icon: flat colours, Otto's rod curving forward with the golden bead hanging from it
    sv.add(f'<g transform="translate({ox - 50 * k * .82:.1f} {base - 90 * k * .82:.1f}) scale({k * .82:.3f})">'
           f'<path d="M50 16.5 C45 4 30 1 21 8 L20 11.5" stroke="#1F3566" stroke-width="2.4" fill="none" stroke-linecap="round"/><circle cx="20" cy="11.5" r="5" fill="#D4A21C"/>'
           f'{legs((38, 56))}<path d="{OTTO_BODY}" fill="#2D4A8C"/>'
           f'<path d="{OTTO_DIP}" fill="#1F3566" fill-opacity=".55"/>{eye(51, 44, 12.5, 11.5, 7.1, .34)}</g>')
    leaves = "".join(f'<path d="{m[0]}" fill="{c}"/>' for m, c in zip([MINT[1], MINT[0], MINT[3], MINT[2]], ["#7FCBA0", "#4FAE7F", "#A9E0C0", "#A9E0C0"]))
    under = "M14 68 C30 76 70 76 88 66 C88 76 80 84 70 86 C56 88 33 89 22 82 C17 78 14 74 14 68Z"
    sv.add(f'<g transform="translate({x - 50 * k:.1f} {base - 90 * k:.1f}) scale({k:.3f})">'
           f'<path d="M49 36 C48 30 49.2 23 50 17.6" stroke="#3D5434" stroke-width="2.2" fill="none" stroke-linecap="round"/>{leaves}'
           f'{legs((33, 59))}<clipPath id="mossc"><path d="{MOSS_BODY}"/></clipPath><path d="{MOSS_BODY}" fill="#55704A"/>'
           f'<path d="{under}" fill="#3D5434" fill-opacity=".55" clip-path="url(#mossc)"/>{eye(43, 55, 6.4, 7.4, 4.0)}{eye(58, 55, 6.4, 7.4, 4.0)}</g>')

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

# the child alone, at each stage, on a transparent ground: for the growth wheel, so the child there is the same child
# one scale for all, so the child grows from figure to figure
FIGURES = [("lieback", 1, 196, 1.12), ("prone", 4, 190, 1.12), ("sit", 7, 160, 1.12), ("crawl", 10, 176, 1.12),
           ("stand", 14, 166, 1.12), ("walk", 22, 158, 1.12), ("run", 30, 150, 1.12)]
def figures(index):
    CAST_FACES.clear(); VIEW.update(z=1.0, cx=150)
    for i, (pose, age, x, k) in enumerate(FIGURES):
        sv = SVG(300, 300)
        at = (x, 286)
        c = Person("child", pose, x, face=-1, age=age, expr="wow" if pose == "lieback" else "smile", at=at,
                   hands=[(x - 60, 200), None] if pose in ("stand", "walk") else [None, None], girl=GIRL)
        sv.add(f'<g transform="translate(150 286) scale({k}) translate(-150 -286)">')
        lying = pose in ("prone", "lieback")
        sv.shadow(c.hip[0] - (c.d["torso"] * .45 * c.f if lying else 0), 290, 60, 7)
        c.draw(sv); sv.add('</g>')
        im = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=sv.svg().encode(), output_width=600))).convert("RGBA")
        n = f"{PREFIX}child_{i}{SUFFIX}.webp"; im.save(os.path.join(OUT, n), "WEBP", quality=90, method=6)
        index["size"][n] = [600, 600]

def main():
    if "--rig" in sys.argv: return rig_sheet(sys.argv[sys.argv.index("--rig") + 1])
    scenes = json.load(open(SCENES))
    only = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else None
    os.makedirs(OUT, exist_ok=True)
    ipath = os.path.join(OUT, "index.json")
    index = json.load(open(ipath)) if os.path.exists(ipath) else {"plays": {}, "covers": {}, "size": {}}
    missing, skipped = [], []
    for p in C["activities"]:
        if only and p["code"] not in only: continue
        area = area_of(p); names = []; prev = None
        for i, t in enumerate(p["steps"]):
            spec = scenes.get(p["code"], [None] * len(p["steps"]))
            if i >= len(spec) or spec[i] is None: missing.append(f'{p["code"]}.{i + 1}'); continue
            n = f"{PREFIX}play_{p['code'].lower()}_{i + 1}{SUFFIX}.webp"
            path = os.path.join(OUT, n)
            # the two watch from a free place on the floor near the action; with no free place, they sit this one out
            base = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=scene(spec[i], area).svg().encode(), output_width=360)))
            where = None if spec[i].get("companions") or FLAT else place_watchers(base, spec[i], area, prev)
            prev = where
            w = (where, i, len(p["steps"])) if where else None
            if w is None and not FLAT: skipped.append(f'{p["code"]}.{i + 1}')
            index["size"][n] = list(render(scene(spec[i], area, watch=w).svg(), path, figs=figures_only(spec[i], area) if FLAT else None)); names.append(n)
        if not GIRL and not FLAT: index["plays"][p["code"]] = names   # the girl's pictures share the names, with _g
    if not only:
        for mo in C["months"]:
            spec, area = cover_spec(mo["month"], mo, scenes)
            n = "%scover_%02d%s.webp" % (PREFIX, mo["month"], SUFFIX)
            sv = scene(spec, area); sv.w, sv.h = W, H
            index["size"][n] = list(render(sv.svg(), os.path.join(OUT, n), figs=figures_only(spec, area) if FLAT else None))
            if not GIRL and not FLAT: index["covers"][str(mo["month"])] = n
    if not only: figures(index)
    json.dump(index, open(ipath, "w"), separators=(",", ":"))
    if missing: print("no scene for", ", ".join(missing))
    if skipped: print(f"companions left out (no free corner) in {len(skipped)}:", ", ".join(skipped))
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
