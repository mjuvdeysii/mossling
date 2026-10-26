"""The app's category marks, made like the characters: each is a small soft-vinyl badge with its object standing out
of it in relief, rendered in Blender under the same product light as Moss and Otto (tools/ip3d.py) and the tab bar
(tools/tab_icons3d.py). Replaces the flat die-cut stickers of tools/stickers.py with the same names, so every place
that shows a category (IconTile: 记录 board and timeline, 本月 grid, 专题, 我的 rows, toasts) changes at once.

  the badge   a thick, softly bevelled disc in a pale tint of the category's colour (the colour code is kept)
  the object  modelled from soft primitives and puffed outlines in the category's colour, never a glyph

Each object is the one tools/stickers.py drew (comments there say what each one stands for). Feeding is a rose
heart with a drop of milk, never a red drop.

Usage: python3 tools/stickers3d.py [--only key,key] [--sheet out.png] [--size 360]
"""
import os, sys, json, math
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
ARGV = sys.argv[1:]
sys.argv = sys.argv[:1] + ["--samples", "40"]
import bpy
from mathutils import Euler
import ip3d
from ip3d import hexcol
from PIL import Image

OUT = os.path.join(HERE, "..", "ios", "Art", "art")
TMP = "/tmp/stickers3d"
def opt(n, d): return type(d)(ARGV[ARGV.index(n) + 1]) if n in ARGV else d
SIZE = opt("--size", 360)

TEAL, PINK, YELLOW, RED, BLUE, ORANGE = "#1FB5A6", "#FF6F91", "#FFC23D", "#F2554B", "#4C9BE8", "#FF8A3D"
LILAC, MINT, GREEN, CARAMEL, GREY, PEACH = "#9B7BEA", "#3CC9A0", "#4DB86A", "#D9964F", "#9A9289", "#FF9E7A"
WHITE, CREAM, INK, WOOD, ROSE = "#FBF8F2", "#F4EBD9", "#2E2A26", "#C98F55", "#E8577A"

def mix(a, b, t):
    a = [int(a[i:i + 2], 16) for i in (1, 3, 5)]; b = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(a, b))
def pale(c, t=0.62): return mix(c, "#FFFFFF", t)
def deep(c, t=0.25): return mix(c, "#000000", t)

MATS = {}
def V(c, rough=0.62):
    if c not in MATS: MATS[c] = ip3d.rubber("v" + c, c, rough=rough)
    return MATS[c]
def glow(c, s=1.2):
    k = "glow" + c
    if k not in MATS: MATS[k] = ip3d.mat(k, c, rough=0.5, emit=c, emit_strength=s, sss=0.2)
    return MATS[k]

def smooth_all(o):
    if o.type == "MESH":
        for p in o.data.polygons: p.use_smooth = True
    return o
def bevel(o, w, seg=5):
    m = o.modifiers.new("b", "BEVEL"); m.width = w; m.segments = seg; m.limit_method = "NONE"; return o

# ---------- primitives (x right, -y towards the camera, z up) ----------
def sph(loc, r, c, sc=(1, 1, 1)):
    if isinstance(r, (int, float)): r = (r * sc[0], r * sc[1], r * sc[2])
    return ip3d.sphere("s", loc, r, V(c) if isinstance(c, str) else c, seg=40)

def box(c0, size, c, bv=0.3, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c0); b = bpy.context.object
    b.scale = size; b.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(b, min(size) * bv); smooth_all(b)
    b.data.materials.append(V(c) if isinstance(c, str) else c); return b

def cyl(c0, r, h, c, rot=(0, 0, 0), r2=None, bv=0.25, verts=48):
    if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=c0, rotation=rot)
    else: bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=c0, rotation=rot)
    o = bpy.context.object; bevel(o, min(r, h) * bv, 4); smooth_all(o)
    o.data.materials.append(V(c) if isinstance(c, str) else c); return o

def tor(c0, R, r, c, rot=(math.pi / 2, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=c0, rotation=rot, major_segments=64, minor_segments=20)
    t = bpy.context.object; smooth_all(t); t.data.materials.append(V(c) if isinstance(c, str) else c); return t

def tube(pts, r, c):
    return ip3d.tube("t", pts, r, V(c) if isinstance(c, str) else c)

def puff(pts, c, y=-0.1, depth=0.06, bv=0.05, rot=0.0):
    """A soft, puffed shape from a 2D outline (in x, z), facing the camera, `depth` thick, with rounded edges."""
    cd = bpy.data.curves.new("p", "CURVE"); cd.dimensions = "2D"; cd.fill_mode = "BOTH"
    cd.extrude = depth; cd.bevel_depth = bv; cd.bevel_resolution = 6
    sp = cd.splines.new("POLY"); sp.points.add(len(pts) - 1)
    for p, (x, z) in zip(sp.points, pts): p.co = (x, z, 0, 1)
    sp.use_cyclic_u = True
    o = bpy.data.objects.new("p", cd); bpy.context.collection.objects.link(o)
    o.rotation_euler = (math.pi / 2, rot, 0); o.location = (0, y, 0)
    o.data.materials.append(V(c) if isinstance(c, str) else c); return o

def chaikin(pts, k=3):
    for _ in range(k):
        q = []
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            q += [(0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]), (0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1])]
        pts = q
    return pts

def heart(cx, cz, s, n=22):
    """A heart with its dip and point rounded (a sharp dip makes the puffed edge fold over itself)."""
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3; z = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        out.append((cx + x * s / 16, cz + (z + 2) * s / 16))
    return chaikin(out, 4)

def circle(cx, cz, r, n=48, a0=0.0, a1=2 * math.pi):
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cz + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]

def crescent(R, dx, dz, r, n=40):
    """A crescent: the disc of radius R at the origin less the disc of radius r at (dx, dz)."""
    inside = lambda x, z, cx, cz, rr: (x - cx) ** 2 + (z - cz) ** 2 < rr * rr
    away = math.atan2(-dz, -dx)
    outer = []
    for i in range(-180, 181, 3):
        a = away + math.radians(i); x, z = R * math.cos(a), R * math.sin(a)
        if not inside(x, z, dx, dz, r): outer.append((i, x, z))
    lo, hi = outer[0][0], outer[-1][0]
    pts = [(x, z) for _, x, z in outer]
    toward = math.atan2(dz, dx)
    inner = []
    for i in range(-180, 181, 3):
        a = toward + math.pi + math.radians(i); x, z = dx + r * math.cos(a), dz + r * math.sin(a)
        if inside(x, z, 0, 0, R): inner.append((x, z))
    # walk the inner arc from the outer arc's end back to its start
    e = pts[-1]
    if inner and math.dist(inner[0], e) > math.dist(inner[-1], e): inner = inner[::-1]
    return chaikin(pts + inner, 2)

def rrect(cx, cz, w, h, r, n=8):
    pts = []
    for (qx, qz, a) in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for i in range(n + 1):
            t = math.radians(a + 90 * i / n); pts.append((cx + qx + r * math.cos(t), cz + qz + r * math.sin(t)))
    return pts

def poly_round(pts, r=0.06, n=6):
    """A polygon with every corner rounded by r."""
    out = []; k = len(pts)
    for i in range(k):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % k]
        def toward(a, b, d):
            dx, dz = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dz) or 1; d = min(d, L / 2)
            return (a[0] + dx / L * d, a[1] + dz / L * d)
        a = toward(p1, p0, r); b = toward(p1, p2, r)
        for j in range(n + 1):
            t = j / n
            out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * p1[0] + t * t * b[0], (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * p1[1] + t * t * b[1]))
    return out

def star(cx, cz, R, r=None, n=5, rot=90):
    r = r or R * 0.48
    return poly_round([(cx + (R if i % 2 == 0 else r) * math.cos(math.radians(rot + 180 * i / n)),
                        cz + (R if i % 2 == 0 else r) * math.sin(math.radians(rot + 180 * i / n))) for i in range(2 * n)], R * 0.12, 4)

def eyes(cx, cz, y, d=0.07, r=0.028):
    for s in (-1, 1): sph((cx + s * d, y, cz), r, INK, (1, 0.5, 1.15))
def smile(cx, cz, y, w=0.06):
    tube([(cx - w, y, cz + 0.01), (cx, y - 0.01, cz - w * 0.55), (cx + w, y, cz + 0.01)], 0.014, INK)

# ---------- the badge ----------
def badge(c):
    """A pebble-round disc, thick and softly bevelled, in a pale tint of the category colour."""
    pts = []
    for i in range(96):
        t = 2 * math.pi * i / 96
        r = 1.0 + 0.025 * math.sin(3 * t + 0.6) + 0.015 * math.sin(5 * t)
        pts.append((r * math.cos(t), r * math.sin(t)))
    o = puff(pts, pale(c, 0.42), y=0.16, depth=0.07, bv=0.09)
    return o

# ---------- the objects ----------
D = {}
def icon(key, colour):
    def deco(fn): D[key] = (colour, fn); return fn
    return deco

# the six areas
@icon("bubble_left_and_bubble_right_fill", TEAL)
def _():
    for s in (-1, 1):
        box((s * 0.3, -0.12, -0.32), (0.58, 0.07, 0.62), WHITE, 0.4, rot=(0, s * math.radians(-8), 0))
        box((s * 0.3, -0.06, -0.34), (0.6, 0.06, 0.64), deep(TEAL, 0.15), 0.4, rot=(0, s * math.radians(-8), 0))
    for i in range(3): box((-0.3, -0.17, -0.18 - i * 0.12), (0.36, 0.02, 0.035), pale(TEAL, 0.3), 0.4)
    bub = rrect(0.32, 0.42, 0.66, 0.42, 0.2)
    puff(bub, WHITE, y=-0.18, depth=0.05)
    puff(poly_round([(0.08, 0.26), (0.0, 0.1), (0.2, 0.24)], 0.03), WHITE, y=-0.18, depth=0.05)
    for i in range(3): sph((0.17 + i * 0.15, -0.3, 0.42), 0.045, TEAL)

@icon("figure_walk", ORANGE)
def _():
    b = sph((0.12, -0.35, -0.05), 0.5, ORANGE)
    for a in (-35, 35): tor((0.12, -0.35, -0.05), 0.497, 0.03, WHITE, rot=(math.radians(15), math.radians(a), 0))
    for i, z in enumerate((0.28, 0.02, -0.24)): tube([(-0.85 + i * 0.05, -0.2, z), (-0.5 + i * 0.03, -0.2, z)], 0.04, WHITE)

@icon("hand_raised_fingers_spread_fill", YELLOW)
def _():
    z = -0.72
    for i in range(5):
        s = 0.64 - i * 0.105
        box((0.0, -0.3, z + s * 0.36), (s, 0.3, s * 0.72), mix(PINK, "#FFFFFF", 0.2 + i * 0.1), 0.16)
        z += s * 0.72 + 0.01

@icon("face_smiling_inverse", PINK)
def _():
    sph((-0.3, -0.25, -0.05), 0.38, "#F6C9A8"); sph((0.32, -0.22, -0.12), 0.32, "#E9B48C")
    eyes(-0.3, -0.02, -0.6, 0.12, 0.04); eyes(0.32, -0.08, -0.52, 0.1, 0.036)
    smile(-0.3, -0.16, -0.62, 0.07); smile(0.32, -0.22, -0.53, 0.06)
    puff(heart(0.02, 0.42, 0.22), ROSE, y=-0.35, depth=0.06, bv=0.05)

@icon("house_fill", BLUE)
def _():
    cyl((-0.25, -0.32, -0.2), 0.3, 0.7, BLUE, r2=0.22)
    tube([(-0.52, -0.32, 0.05), (-0.72, -0.32, -0.05), (-0.68, -0.32, -0.3), (-0.5, -0.32, -0.38)], 0.05, BLUE)
    sph((-0.04, -0.32, 0.14), 0.07, BLUE, (1.6, 0.8, 0.6))
    cyl((0.38, -0.32, -0.38), 0.22, 0.38, WHITE, r2=0.26)
    cyl((0.38, -0.36, -0.22), 0.2, 0.04, pale(BLUE, 0.35), bv=0.4)
    tube([(0.06, -0.32, 0.14), (0.2, -0.32, 0.05), (0.33, -0.32, -0.16)], 0.025, pale(BLUE, 0.35))

@icon("cross_case_fill", RED)
def _():
    box((0, -0.3, -0.22), (1.1, 0.5, 0.78), RED, 0.22)
    tor((0, -0.3, 0.2), 0.2, 0.05, deep(RED, 0.3), rot=(math.radians(90), 0, 0))
    puff(heart(0, -0.24, 0.26), WHITE, y=-0.56, depth=0.04, bv=0.03)

# 本月 · 这个月
@icon("circle_hexagongrid_fill", TEAL)
def _():
    cols = [ORANGE, YELLOW, GREEN, BLUE, LILAC, PINK]
    for i, c in enumerate(cols):
        a = math.radians(90 + 60 * i); sph((0.5 * math.cos(a), -0.3, 0.5 * math.sin(a)), 0.2, c)
    sph((0, -0.36, 0), 0.24, "#E9B23A")
    tor((0, -0.3, 0), 0.5, 0.02, CREAM)

@icon("eye_fill", BLUE)
def _():
    tube([(0, -0.25, -0.62), (0.01, -0.25, -0.35), (0, -0.25, -0.12)], 0.035, "#3D8A55")
    ip3d.leaf("l1", (0, -0.27, -0.2), Euler((-1.05, -math.radians(35), math.radians(185))), 0.32, V(GREEN), width=0.6)
    ip3d.leaf("l2", (0, -0.27, -0.2), Euler((1.05, -math.radians(35), math.radians(-5))), 0.34, V(GREEN), width=0.6)
    tor((0.12, -0.5, 0.08), 0.4, 0.07, BLUE)
    cyl((0.12, -0.48, 0.08), 0.36, 0.02, "#DDF2FF", rot=(math.pi / 2, 0, 0))
    tube([(0.44, -0.5, -0.22), (0.72, -0.5, -0.56)], 0.085, deep(BLUE, 0.2))

@icon("syringe_fill", PINK)
def _():
    box((0, -0.24, -0.04), (0.9, 0.12, 1.15), PINK, 0.15, rot=(0, math.radians(-6), 0))
    box((-0.44, -0.3, -0.04), (0.08, 0.1, 1.1), deep(PINK, 0.2), 0.4, rot=(0, math.radians(-6), 0))
    for i in range(3): box((0.08, -0.31, -0.3 - i * 0.14), (0.5, 0.02, 0.05), pale(PINK, 0.5), 0.4)
    puff(star(0.06, 0.22, 0.3), YELLOW, y=-0.33, depth=0.06, bv=0.04)

@icon("lightbulb_fill", YELLOW)
def _():
    sph((0, -0.3, 0.16), 0.48, glow("#FFD45C", 0.9), (1, 1, 1.02))
    cyl((0, -0.3, -0.36), 0.23, 0.2, "#FFD45C", r2=0.2)
    for i in range(3): cyl((0, -0.3, -0.44 - i * 0.09), 0.2, 0.08, "#B7AFA3", bv=0.45)
    sph((0, -0.3, -0.72), 0.1, "#8E867B")
    tube([(-0.1, -0.78, 0.0), (-0.1, -0.78, 0.14), (0.1, -0.78, 0.14), (0.1, -0.78, 0.0)], 0.025, "#E39B22")

@icon("sun_and_horizon_fill", ORANGE)
def _():
    # the day's two ends: the sun rising over a hill, the moon already waiting
    sph((-0.2, -0.24, 0.0), 0.42, ORANGE)
    for i in range(5):
        a = math.radians(20 + i * 35)
        sph((-0.2 + 0.62 * math.cos(a), -0.3, 0.0 + 0.62 * math.sin(a)), 0.07, YELLOW, (1, 0.8, 1))
    o = puff(crescent(0.26, 0.12, 0.08, 0.21), "#8C82DE", y=-0.5, depth=0.08, bv=0.05); o.location.x = 0.48; o.location.z = 0.42
    puff(chaikin([(-0.9, -0.32), (-0.4, -0.22), (0.2, -0.28), (0.9, -0.3), (0.9, -0.75), (-0.9, -0.75)], 3), "#7FC48F", y=-0.5, depth=0.12, bv=0.06)

@icon("chart_line_uptrend_xyaxis", ORANGE)
def _():
    box((-0.25, -0.24, 0.0), (0.32, 0.1, 1.4), "#FFD27A", 0.2)
    for i in range(9): box((-0.36 + (0.04 if i % 2 else 0), -0.3, -0.56 + i * 0.14), (0.12 if i % 2 else 0.2, 0.02, 0.025), deep(ORANGE, 0.1), 0.4)
    tube([(0.25, -0.3, -0.66), (0.22, -0.3, -0.2), (0.3, -0.3, 0.3)], 0.03, "#3D8A55")
    for z, s in ((-0.32, 1), (0.02, -1), (0.3, 1)):
        ip3d.leaf("l", (0.24 + s * 0.02, -0.33, z), Euler((s * 1.05, -math.radians(30), math.radians(-5 if s > 0 else 185))), 0.26, V(GREEN), width=0.6)

# topics
@icon("moon_zzz_fill", LILAC)
def _():
    o = puff(crescent(0.62, 0.3, 0.16, 0.5), "#FFD45C", y=-0.24, depth=0.12, bv=0.07); o.location.x = -0.12
    puff(star(0.5, 0.42, 0.17), WHITE, y=-0.3, depth=0.04, bv=0.03)
    puff(star(0.58, -0.08, 0.11), WHITE, y=-0.3, depth=0.04, bv=0.03)

@icon("bed_double_fill", BLUE)
def _():
    box((0, -0.25, -0.32), (1.3, 0.4, 0.14), WOOD, 0.3)
    box((0, -0.32, -0.2), (1.14, 0.34, 0.14), WHITE, 0.4)
    for s in (-1, 1): box((s * 0.62, -0.3, -0.08), (0.1, 0.12, 0.92), WOOD, 0.4)
    box((0, -0.38, 0.32), (1.3, 0.08, 0.08), WOOD, 0.4)
    for i in range(7): cyl((-0.45 + i * 0.15, -0.4, 0.06), 0.025, 0.52, pale(WOOD, 0.25))
    sph((-0.3, -0.4, -0.04), 0.13, "#F6C9A8")
    box((0.12, -0.42, -0.08), (0.5, 0.14, 0.14), pale(BLUE, 0.3), 0.45)

@icon("fork_knife", GREEN)
def _():
    cyl((-0.08, -0.3, -0.25), 0.55, 0.36, WHITE, r2=0.34, rot=(math.pi, 0, 0))
    tor((-0.08, -0.3, -0.07), 0.55, 0.04, GREEN, rot=(0, 0, 0))
    for x, c in ((-0.28, ORANGE), (0.0, YELLOW), (0.2, GREEN)): sph((x, -0.38, -0.02), 0.16, c, (1, 1, 0.75))
    tube([(0.3, -0.62, 0.0), (0.72, -0.62, 0.62)], 0.045, PEACH)
    sph((0.25, -0.62, -0.05), 0.13, PEACH, (1, 0.5, 1.3))

@icon("mouth_fill", TEAL)
def _():
    t = poly_round([(-0.32, 0.36), (0.32, 0.36), (0.36, -0.06), (0.24, -0.5), (0.1, -0.5), (0.0, -0.18), (-0.1, -0.5), (-0.24, -0.5), (-0.36, -0.06)], 0.14)
    o = puff(t, WHITE, y=-0.25, depth=0.12, bv=0.08); o.location.x = -0.2
    eyes(-0.2, 0.08, -0.43, 0.1, 0.035); smile(-0.2, -0.04, -0.44, 0.06)
    tube([(0.38, -0.5, -0.66), (0.5, -0.5, 0.2)], 0.05, TEAL)
    box((0.52, -0.52, 0.34), (0.16, 0.12, 0.3), WHITE, 0.4, rot=(0, math.radians(-8), 0))

@icon("book_pages_fill", TEAL)
def _():
    box((0, -0.24, 0), (0.88, 0.22, 1.12), TEAL, 0.14, rot=(0, math.radians(-5), 0))
    box((0.06, -0.24, 0), (0.78, 0.18, 1.06), WHITE, 0.2, rot=(0, math.radians(-5), 0))
    box((-0.04, -0.36, 0), (0.86, 0.04, 1.12), TEAL, 0.3, rot=(0, math.radians(-5), 0))
    box((0.2, -0.4, 0.28), (0.32, 0.03, 0.22), WHITE, 0.4, rot=(0, math.radians(-5), 0))
    puff(poly_round([(0.18, 0.62), (0.34, 0.62), (0.34, 0.1), (0.26, 0.2), (0.18, 0.1)], 0.02), YELLOW, y=-0.4, depth=0.02, bv=0.015)

# 记录
@icon("heart_fill", PINK)
def _():
    puff(heart(-0.02, -0.06, 0.66), ROSE, y=-0.2, depth=0.16, bv=0.08)
    sph((0.3, -0.5, 0.26), 0.12, WHITE, (1, 0.7, 1.12))   # a drop of milk: white, round, never a red drop

@icon("waterbottle_fill", PEACH)
def _():
    cyl((0, -0.3, -0.25), 0.3, 0.8, "#FFF9EF", bv=0.35)
    cyl((0, -0.31, -0.42), 0.29, 0.44, "#FFF1D6", bv=0.3)
    for i in range(3): box((0.2, -0.6, -0.5 + i * 0.16), (0.12, 0.02, 0.025), PEACH, 0.4)
    cyl((0, -0.3, 0.2), 0.33, 0.16, PEACH, bv=0.4)
    cyl((0, -0.3, 0.36), 0.18, 0.2, pale(PEACH, 0.3), r2=0.1, bv=0.2)
    sph((0, -0.3, 0.5), 0.1, pale(PEACH, 0.3))

@icon("circle_bottomhalf_filled", BLUE)
def _():
    n = poly_round([(-0.62, 0.3), (0.62, 0.3), (0.5, -0.05), (0.18, -0.48), (-0.18, -0.48), (-0.5, -0.05)], 0.16)
    puff(n, WHITE, y=-0.22, depth=0.16, bv=0.1)
    for s in (-1, 1): box((s * 0.5, -0.5, 0.18), (0.2, 0.04, 0.14), BLUE, 0.4)
    box((0, -0.5, 0.22), (1.0, 0.03, 0.06), pale(BLUE, 0.3), 0.4)
    for x in (-0.2, 0.0, 0.2): sph((x, -0.5, -0.06), 0.045, pale(BLUE, 0.2))

@icon("bathtub_fill", TEAL)
def _():
    tub = [(-0.72, 0.0), (0.72, 0.0)] + [(0.66 * math.cos(math.radians(a)), -0.02 + 0.5 * math.sin(math.radians(a))) for a in range(0, -181, -10)][1:-1]
    puff(tub, WHITE, y=-0.18, depth=0.2, bv=0.07)
    for s in (-1, 1): cyl((s * 0.42, -0.3, -0.6), 0.06, 0.12, WOOD)
    for x, z, r in ((-0.5, 0.12, 0.15), (-0.28, 0.2, 0.12), (0.48, 0.14, 0.13), (0.62, 0.36, 0.09), (-0.4, 0.42, 0.08)):
        sph((x, -0.36, z), r, "#DFF6FF")
    sph((0.08, -0.36, 0.14), 0.22, YELLOW, (1.2, 1, 0.8))
    sph((0.18, -0.38, 0.38), 0.14, YELLOW)
    sph((0.33, -0.42, 0.36), 0.07, ORANGE, (1.3, 0.8, 0.6))
    sph((0.2, -0.52, 0.42), 0.02, INK)

@icon("thermometer_medium", RED)
def _():
    tube([(-0.4, -0.3, -0.38), (0.36, -0.3, 0.38)], 0.12, WHITE)
    sph((-0.44, -0.3, -0.42), 0.2, RED)
    tube([(-0.38, -0.42, -0.36), (0.05, -0.42, 0.07)], 0.05, RED)
    for i in range(4): sph((-0.06 + i * 0.1, -0.44, 0.12 + i * 0.1), 0.02, deep(RED, 0.2))

@icon("pills_fill", YELLOW)
def _():
    cyl((-0.22, -0.28, -0.25), 0.34, 0.7, "#E0A040", bv=0.3)
    box((-0.22, -0.6, -0.28), (0.44, 0.02, 0.36), WHITE, 0.3)
    sph((-0.22, -0.62, -0.28), 0.08, "#E0A040", (1, 0.3, 1))
    cyl((-0.22, -0.28, 0.16), 0.2, 0.14, "#5C4A3D")
    tube([(0.42, -0.4, -0.5), (0.42, -0.4, 0.1)], 0.05, "#DDF2FF")
    sph((0.42, -0.4, 0.3), 0.15, RED, (1, 1, 1.35))
    cyl((0.42, -0.4, 0.12), 0.1, 0.06, deep(RED, 0.2))
    sph((0.42, -0.4, -0.62), 0.05, "#DDF2FF")

@icon("ruler_fill", ORANGE)
def _():
    cyl((-0.18, -0.25, 0.1), 0.5, 0.32, ORANGE, rot=(math.pi / 2, 0, 0), bv=0.3)
    cyl((-0.18, -0.42, 0.1), 0.2, 0.04, deep(ORANGE, 0.15), rot=(math.pi / 2, 0, 0), bv=0.4)
    box((0.3, -0.3, -0.36), (0.9, 0.08, 0.22), YELLOW, 0.3, rot=(0, math.radians(14), 0))
    for i in range(6): box((-0.02 + i * 0.13, -0.36, -0.28 - i * 0.032), (0.025, 0.02, 0.1 if i % 2 else 0.14), INK, 0.3, rot=(0, math.radians(14), 0))

@icon("pencil", GREY)
def _():
    box((-0.1, -0.15, -0.02), (0.92, 0.06, 1.1), WHITE, 0.1, rot=(0, math.radians(6), 0))
    for i in range(4): box((-0.18, -0.2, 0.32 - i * 0.18), (0.6 - (0.2 if i == 3 else 0), 0.02, 0.04), "#C9C1B5", 0.4, rot=(0, math.radians(6), 0))
    a = math.radians(-40)
    def along(t): return (0.26 + t * math.cos(a), -0.45, -0.22 - t * math.sin(a))
    o = cyl(along(0.25), 0.1, 0.62, YELLOW, verts=6, bv=0.15); o.rotation_euler = (0, math.pi / 2 - a, 0)
    o = cyl(along(-0.12), 0.1, 0.13, WOOD, r2=0.03, bv=0.1); o.rotation_euler = (0, -(math.pi / 2 + a), 0)
    sph(along(-0.2), 0.035, INK)
    o = cyl(along(0.6), 0.1, 0.1, "#C6C6CC", bv=0.3); o.rotation_euler = (0, math.pi / 2 - a, 0)
    o = cyl(along(0.69), 0.1, 0.1, PINK, bv=0.5); o.rotation_euler = (0, math.pi / 2 - a, 0)

@icon("puzzlepiece_fill", TEAL)
def _():
    pts = []
    def bump(cx, cz, ang):
        return [(cx + 0.17 * math.cos(math.radians(a)), cz + 0.17 * math.sin(math.radians(a))) for a in range(ang - 140, ang + 141, 10)]
    pts += [(-0.45, -0.45)]
    pts += [(0.45, -0.45), (0.45, -0.12)] + bump(0.58, 0.0, 0) + [(0.45, 0.12), (0.45, 0.45), (0.12, 0.45)] + bump(0.0, 0.58, 90) + [(-0.12, 0.45), (-0.45, 0.45)]
    puff(pts, TEAL, y=-0.22, depth=0.16, bv=0.08)

@icon("list_bullet_clipboard_fill", ORANGE)
def _():
    box((0, -0.2, -0.06), (0.96, 0.1, 1.22), WOOD, 0.12)
    box((0, -0.27, -0.12), (0.8, 0.04, 1.0), WHITE, 0.2)
    box((0, -0.34, 0.5), (0.4, 0.12, 0.18), "#B9B2A8", 0.4)
    for i, c in enumerate((PINK, TEAL, YELLOW)):
        sph((-0.24, -0.33, 0.2 - i * 0.26), 0.07, c)
        box((0.1, -0.31, 0.2 - i * 0.26), (0.38, 0.02, 0.05), "#C9C1B5", 0.4)

@icon("faceid", GREEN)
def _():
    tor((0, -0.25, 0.18), 0.3, 0.07, "#B9B2A8", rot=(math.pi / 2, 0, 0))
    box((0, -0.3, -0.26), (0.92, 0.42, 0.74), GREEN, 0.22)
    eyes(0, -0.18, -0.54, 0.14, 0.045); smile(0, -0.34, -0.54, 0.09)

@icon("circle_lefthalf_filled", LILAC)
def _():
    p = []
    for i in range(80):
        t = 2 * math.pi * i / 80; r = 0.68 * (1 + 0.08 * math.sin(2 * t)); p.append((r * math.cos(t) * 1.05, r * math.sin(t) * 0.86))
    puff(p, CREAM, y=-0.2, depth=0.08, bv=0.06)
    cyl((0.3, -0.38, -0.32), 0.12, 0.06, "#E9DFCC", rot=(math.pi / 2, 0, 0), bv=0.4)
    for (x, z), c in zip(((-0.38, 0.22), (-0.06, 0.38), (0.28, 0.3), (-0.4, -0.18)), (PINK, YELLOW, TEAL, LILAC)):
        sph((x, -0.38, z), 0.13, c, (1, 0.6, 0.9))

@icon("info", TEAL)
def _():
    ip3d.materials()
    r = ip3d.build_moss(lid=0.05, look=(0.1, 0.1), er=0.13, pupil=0.56, perk=0.7)
    r.location = (0, -0.3, -0.66); r.scale = (1.15, 1.15, 1.15)

def parcel(c):
    box((0, -0.25, -0.3), (0.96, 0.46, 0.7), "#E2B178", 0.12)
    box((0, -0.5, -0.3), (0.16, 0.04, 0.72), "#C99257", 0.3)
@icon("square_and_arrow_up", BLUE)
def _():
    parcel(BLUE)
    puff(poly_round([(-0.1, 0.18), (0.1, 0.18), (0.1, 0.45), (0.28, 0.45), (0.0, 0.78), (-0.28, 0.45), (-0.1, 0.45)], 0.04), BLUE, y=-0.5, depth=0.08, bv=0.05)
@icon("square_and_arrow_down", LILAC)
def _():
    parcel(LILAC)
    puff(poly_round([(-0.1, 0.8), (0.1, 0.8), (0.1, 0.5), (0.28, 0.5), (0.0, 0.16), (-0.28, 0.5), (-0.1, 0.5)], 0.04), LILAC, y=-0.5, depth=0.08, bv=0.05)

@icon("doc_text_fill", GREY)
def _():
    puff(poly_round([(-0.42, -0.62), (0.42, -0.62), (0.42, 0.36), (0.16, 0.62), (-0.42, 0.62)], 0.06), WHITE, y=-0.22, depth=0.06, bv=0.04)
    puff(poly_round([(0.16, 0.36), (0.42, 0.36), (0.16, 0.62)], 0.03), "#E3DCD0", y=-0.3, depth=0.02, bv=0.02)
    for i in range(5): box((-0.06 if i < 4 else -0.14, -0.34, 0.24 - i * 0.18), (0.52 if i < 4 else 0.36, 0.02, 0.05), "#B9B2A8", 0.4)

@icon("hand_raised_fill", BLUE)
def _():
    skin = "#F2C29B"
    sph((0, -0.3, -0.18), 0.36, skin, (1, 0.55, 1.05))
    for i, (x, h) in enumerate(((-0.27, 0.36), (-0.1, 0.46), (0.08, 0.44), (0.24, 0.36))):
        tube([(x, -0.3, 0.05), (x * 1.18, -0.3, 0.05 + h)], 0.075, skin)
    tube([(0.28, -0.3, -0.22), (0.5, -0.3, -0.02), (0.58, -0.3, 0.12)], 0.08, skin)
    box((0, -0.3, -0.62), (0.56, 0.3, 0.22), BLUE, 0.4)

@icon("exclamationmark_bubble_fill", ORANGE)
def _():
    puff(rrect(0, 0.08, 1.2, 0.86, 0.36), WHITE, y=-0.2, depth=0.08, bv=0.06)
    puff(poly_round([(-0.32, -0.26), (-0.44, -0.62), (-0.06, -0.3)], 0.04), WHITE, y=-0.2, depth=0.08, bv=0.06)
    tube([(0, -0.42, 0.36), (0, -0.42, 0.0)], 0.07, ORANGE)
    sph((0, -0.42, -0.16), 0.08, ORANGE)

@icon("books_vertical_fill", CARAMEL)
def _():
    for x, w, h, c, r in ((-0.42, 0.26, 1.0, TEAL, 0), (-0.14, 0.24, 1.1, ORANGE, 0), (0.1, 0.2, 0.92, PINK, 0), (0.38, 0.26, 0.96, BLUE, -12)):
        box((x, -0.3, -0.62 + h / 2), (w, 0.42, h), c, 0.14, rot=(0, math.radians(r), 0))
        box((x, -0.52, -0.62 + h * 0.72), (w * 0.8, 0.02, 0.06), WHITE, 0.4, rot=(0, math.radians(r), 0))
    box((0, -0.3, -0.68), (1.3, 0.5, 0.1), WOOD, 0.4)

@icon("checkmark_seal_fill", TEAL)
def _():
    for s in (-1, 1): puff(poly_round([(s * 0.1, -0.1), (s * 0.34, -0.12), (s * 0.4, -0.72), (s * 0.26, -0.6), (s * 0.16, -0.74)], 0.03), deep(TEAL, 0.1), y=-0.2, depth=0.04, bv=0.03)
    pts = []
    for i in range(120):
        t = 2 * math.pi * i / 120; r = 0.5 + 0.045 * math.cos(12 * t); pts.append((r * math.cos(t), 0.14 + r * math.sin(t)))
    puff(pts, TEAL, y=-0.3, depth=0.1, bv=0.06)
    o = cyl((0, -0.46, 0.14), 0.33, 0.04, pale(TEAL, 0.5), rot=(math.pi / 2, 0, 0), bv=0.4)
    tube([(-0.14, -0.5, 0.14), (-0.03, -0.5, 0.02), (0.16, -0.5, 0.28)], 0.04, TEAL)

@icon("clock_arrow_circlepath", LILAC)
def _():
    box((0, -0.24, -0.1), (1.08, 0.12, 1.06), WHITE, 0.12)
    box((0, -0.27, 0.32), (1.08, 0.12, 0.24), LILAC, 0.3)
    for s in (-1, 1): tor((s * 0.26, -0.34, 0.46), 0.08, 0.025, "#8E867B", rot=(0, math.pi / 2, 0))
    for r in range(3):
        for c in range(4):
            col = YELLOW if (r, c) == (1, 2) else "#E3DCD0"
            box((-0.33 + c * 0.22, -0.32, 0.04 - r * 0.22), (0.14, 0.03, 0.14), col, 0.4)

@icon("envelope_fill", PINK)
def _():
    box((0, -0.25, -0.12), (1.2, 0.12, 0.8), WHITE, 0.14)
    puff(poly_round([(-0.58, 0.26), (0.58, 0.26), (0.0, -0.18)], 0.08), "#F1EADF", y=-0.3, depth=0.03, bv=0.03)
    puff(heart(0, -0.12, 0.2), ROSE, y=-0.36, depth=0.04, bv=0.04)

@icon("exclamationmark_triangle_fill", ORANGE)
def _():
    sh = poly_round([(-0.52, 0.56), (0.0, 0.7), (0.52, 0.56), (0.48, -0.06), (0.0, -0.7), (-0.48, -0.06)], 0.16)
    puff(sh, ORANGE, y=-0.2, depth=0.12, bv=0.08)
    puff(heart(0, -0.02, 0.28), WHITE, y=-0.42, depth=0.04, bv=0.04)

@icon("tray_full_fill", CARAMEL)
def _():
    box((0, -0.3, -0.4), (1.4, 0.7, 0.12), WOOD, 0.4)
    for s in (-1, 1): box((s * 0.68, -0.3, -0.3), (0.08, 0.7, 0.22), deep(WOOD, 0.1), 0.4)
    sph((-0.34, -0.36, -0.12), 0.2, ORANGE)
    box((0.12, -0.36, -0.18), (0.26, 0.26, 0.26), BLUE, 0.2, rot=(0, 0, math.radians(15)))
    cyl((0.42, -0.36, -0.08), 0.12, 0.36, YELLOW)

@icon("person_2_fill", PINK)
def _():
    sph((-0.26, -0.3, 0.26), 0.25, "#F6C9A8"); box((-0.26, -0.3, -0.34), (0.5, 0.38, 0.66), PINK, 0.4)
    sph((0.34, -0.36, 0.06), 0.2, "#E9B48C"); box((0.34, -0.36, -0.44), (0.4, 0.32, 0.5), YELLOW, 0.4)
    eyes(-0.26, 0.28, -0.53, 0.08, 0.03); eyes(0.34, 0.08, -0.55, 0.07, 0.026)
    smile(-0.26, 0.18, -0.54, 0.05); smile(0.34, 0.0, -0.56, 0.04)

# figures without a badge, for the companions' moments (a hug's heart rises between them)
FX = {}
def fx_heart(): puff(heart(0, -0.05, 0.85), ROSE, y=-0.2, depth=0.18, bv=0.1)
FX["fx_heart"] = fx_heart

# ---------- render ----------
def scene():
    s = ip3d.reset(); s.render.film_transparent = True; s.cycles.samples = 40
    s.view_settings.exposure = 0.25  # the marks sit on a light page: lifted a little so the badges read clean, not dusty
    MATS.clear(); ip3d.sprite_lights(); return s

def camera():
    t = math.radians(9)
    bpy.ops.object.camera_add(location=(0, -8 * math.cos(t), 8 * math.sin(t))); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = 2.42
    bpy.context.scene.camera = c

def render(key, px=SIZE):
    scene()
    if key in FX: FX[key]()
    else: colour, fn = D[key]; badge(colour); fn()
    camera()
    os.makedirs(TMP, exist_ok=True)
    p = os.path.join(TMP, key + ".png"); ip3d.render(p, px, px)
    n = f"{key}.webp" if key in FX else f"ic_{key}.webp"
    Image.open(p).convert("RGBA").save(os.path.join(OUT, n), "WEBP", quality=90, method=6)
    return n

def main():
    keys = opt("--only", "").split(",") if "--only" in ARGV else list(D) + list(FX)
    ipath = os.path.join(OUT, "index.json"); index = json.load(open(ipath))
    names = []
    for k in keys:
        names.append(render(k)); index["size"][names[-1]] = [SIZE, SIZE]; print(k, flush=True)
    json.dump(index, open(ipath, "w"), separators=(",", ":"))
    if "--sheet" in ARGV:
        out = opt("--sheet", "sheet.png"); cols = 8; rows = (len(names) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * 150, rows * 150), (251, 247, 240, 255))
        for k, n in enumerate(names): sheet.alpha_composite(Image.open(os.path.join(OUT, n)).resize((150, 150), Image.LANCZOS), ((k % cols) * 150, (k // cols) * 150))
        sheet.save(out)

if __name__ == "__main__":
    main()
