"""The app's icons, made like Moss and Otto: each category mark is a small matte soft-vinyl object standing on a round
vinyl token in its colour, rendered in Blender under the characters' product light (tools/ip3d.py), seen a little
from above. They replace the flat die-cut stickers (tools/stickers.py) under the same names (ic_<symbol>.webp), so
the app picks them up wherever IconTile shows a mark.

Usage: python3 tools/icons3d.py [--only key,key] [--sheet out.png]
"""
import math, os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv = sys.argv[:1] + ["--samples", "24"] + sys.argv[1:]
import bpy
from mathutils import Vector, Euler
import ip3d
from ip3d import M, sphere, tube, hexcol, rubber, mat, build_moss
from PIL import Image, ImageDraw, ImageFilter

ART = os.path.join(HERE, "..", "ios", "Art", "art")
ARGS = sys.argv[1:]
PX = 360
TEAL, PINK, YELLOW, RED, BLUE, ORANGE = "#1FB5A6", "#FF6F91", "#FFC23D", "#F2554B", "#4C9BE8", "#FF8A3D"
LILAC, MINT, GREEN, CARAMEL, GREY, PEACH = "#9B7BEA", "#3CC9A0", "#4DB86A", "#D9964F", "#9A9289", "#FF9E7A"
CREAM, INKC, SKIN = "#FFF6E6", "#2A2522", "#F2CDA8"

MATS = {}
def v(hexc, rough=0.6):
    if hexc not in MATS: MATS[hexc] = rubber("v" + hexc, hexc, rough=rough)
    return MATS[hexc]
def glossy(hexc): return MATS.setdefault("g" + hexc, mat("g" + hexc, hexc, rough=0.15, coat=0.6))
def glow(hexc, s=2.0): return MATS.setdefault("e" + hexc, mat("e" + hexc, hexc, rough=0.4, emit=hexc, emit_strength=s))
def mix(a, b, t):
    a = [int(a[i:i + 2], 16) for i in (1, 3, 5)]; b = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{int(x + (y - x) * t):02X}" for x, y in zip(a, b))

def rbox(c, size, col, bevel=0.3, rot=(0, 0, 0), rough=0.6):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c); b = bpy.context.object
    b.scale = size; b.rotation_euler = rot
    m = b.modifiers.new("b", "BEVEL"); m.width = min(size) * bevel; m.segments = 6; m.limit_method = "NONE"
    b.data.materials.append(v(col, rough) if isinstance(col, str) else col); return b
def cyl(c, r, h, col, r2=None, rot=(0, 0, 0), bevel=0.25, verts=48):
    if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=c, rotation=rot)
    else: bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=c, rotation=rot)
    o = bpy.context.object
    m = o.modifiers.new("b", "BEVEL"); m.width = min(r, h) * bevel; m.segments = 5; m.limit_method = "NONE"
    for p in o.data.polygons: p.use_smooth = True
    o.data.materials.append(v(col) if isinstance(col, str) else col); return o
def tor(c, R, r, col, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=c, rotation=rot); t = bpy.context.object
    for p in t.data.polygons: p.use_smooth = True
    t.data.materials.append(v(col) if isinstance(col, str) else col); return t
def sph(c, s, col): return sphere("s", c, s if isinstance(s, tuple) else (s, s, s), v(col) if isinstance(col, str) else col)
def cap(a, b, r, col): return tube("t", [a, tuple((x + y) / 2 for x, y in zip(a, b)), b], r, v(col) if isinstance(col, str) else col)
def face(c, r, front=-1.0, spread=0.32, smile=True, z=0.0):
    """Two dot eyes and a small smile on the camera side of a round thing centred at c with radius r."""
    for sx in (-1, 1):
        sph((c[0] + sx * r * spread, c[1] + front * r * 0.93, c[2] + r * 0.12 + z), (r * 0.09, r * 0.05, r * 0.12), INKC)
    if smile:
        y = c[1] + front * r * 0.95
        tube("m", [(c[0] - r * 0.14, y, c[2] - r * 0.1 + z), (c[0], y - 0.002, c[2] - r * 0.2 + z), (c[0] + r * 0.14, y, c[2] - r * 0.1 + z)], r * 0.03, v(INKC))
def heart(c, s, col):
    """A plump heart: two round lobes and a soft point, overlapping so they read as one shape."""
    for sx in (-1, 1): sph((c[0] + sx * s * 0.34, c[1], c[2] + s * 0.22), (s * 0.5, s * 0.4, s * 0.5), col)
    o = cyl((c[0], c[1], c[2] - s * 0.18), s * 0.74, s * 0.86, col, r2=0.04, rot=(math.pi, 0, 0), bevel=0.35)
    o.scale = (1.0, 0.54, 1.0); return o
def star(c, s, col, depth=0.06):
    pts = [(c[0] + math.cos(math.radians(90 + i * 36)) * (s if i % 2 == 0 else s * 0.45), c[2] + math.sin(math.radians(90 + i * 36)) * (s if i % 2 == 0 else s * 0.45)) for i in range(10)]
    me = bpy.data.meshes.new("star"); me.from_pydata([(x, c[1], z) for x, z in pts], [], [list(range(10))])
    o = bpy.data.objects.new("star", me); bpy.context.collection.objects.link(o)
    so = o.modifiers.new("s", "SOLIDIFY"); so.thickness = depth
    bv = o.modifiers.new("b", "BEVEL"); bv.width = depth * 0.4; bv.segments = 3; bv.limit_method = "NONE"
    o.data.materials.append(v(col)); return o
def leafpair(base, h, col=GREEN):
    cap(base, (base[0], base[1], base[2] + h), 0.025, col)
    for sx, hh in ((-1, 0.65), (1, 0.85)):
        l = sph((base[0] + sx * 0.12, base[1], base[2] + h * hh), (0.13, 0.03, 0.07), col if sx < 0 else "#7FD49A")
        l.rotation_euler = (0, math.radians(-30 * sx), 0)

# ---------- the scene for one icon ----------
def setup(colour):
    s = ip3d.reset(); s.render.film_transparent = True
    s.view_settings.view_transform = "Standard"; s.view_settings.look = "None"; s.view_settings.exposure = -0.6
    ip3d.materials(); MATS.clear(); ip3d.sprite_lights()
    # the token: a round, thick, soft vinyl coaster in a light tint of the colour
    t = cyl((0, 0, -0.06), 0.86, 0.12, mix(colour, "#FFFFFF", 0.55), bevel=0.45, verts=96)
    return s
def shoot(s, path):
    bpy.ops.object.camera_add(location=(0, -8 * math.cos(math.radians(20)), 0.5 + 8 * math.sin(math.radians(20))))
    c = bpy.context.object; c.rotation_euler = (math.radians(70), 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = 1.95
    s.camera = c; ip3d.render(path, PX, PX)

I = {}
def icon(key, colour):
    def deco(fn): I[key] = (colour, fn); return fn
    return deco

# areas
@icon("bubble_left_and_bubble_right_fill", TEAL)          # 语言: an open book and a speech bubble
def _():
    for sx in (-1, 1): rbox((sx * 0.3, 0, 0.12), (0.56, 0.42, 0.06), CREAM, 0.3, (0, math.radians(-12 * sx), 0))
    rbox((0, 0.02, 0.05), (1.2, 0.46, 0.06), "#0B7D74", 0.3)
    sph((0.22, 0.05, 0.78), (0.36, 0.2, 0.26), "#FFFFFF"); sph((0.06, 0.05, 0.58), (0.09, 0.08, 0.09), "#FFFFFF")
    for i in range(3): sph((0.08 + i * 0.14, -0.15, 0.8), 0.045, TEAL)
@icon("figure_walk", ORANGE)                              # 大运动: a soft ball, rolling
def _():
    sph((0.05, 0, 0.42), 0.42, ORANGE)
    for rz in (60, -60):
        t = tor((0.05, 0, 0.42), 0.415, 0.05, CREAM, (math.radians(90), 0, math.radians(rz))); t.scale = (1, 1, 0.5)
    for i, z in enumerate((0.25, 0.45, 0.65)): cap((-0.75 + i * 0.05, -0.1, z), (-0.45, -0.1, z), 0.03, "#FFFFFF")
@icon("hand_raised_fingers_spread_fill", YELLOW)          # 精细: the pink tower
def _():
    z = 0.0
    for i, w in enumerate((0.62, 0.5, 0.4, 0.3, 0.2)):
        h = w * 0.55; rbox((0, 0, z + h / 2), (w, w, h), PINK if i % 2 == 0 else "#FF8FAA", 0.15, (0, 0, math.radians(18))); z += h
@icon("face_smiling_inverse", PINK)                       # 社会情绪: two faces close, a heart above
def _():
    sph((-0.25, 0, 0.42), 0.36, SKIN); face((-0.25, 0, 0.42), 0.36)
    sph((-0.25, 0.06, 0.6), (0.34, 0.3, 0.2), "#4A3428")
    sph((0.32, 0, 0.32), 0.27, "#D9A57C"); face((0.32, 0, 0.32), 0.27)
    heart((0.05, 0, 0.98), 0.17, RED)
@icon("house_fill", BLUE)                                 # 生活与文化: a jug pouring into a cup
def _():
    j = cyl((-0.28, 0, 0.5), 0.2, 0.5, BLUE, r2=0.24, rot=(0, math.radians(-30), 0))
    tor((-0.06, 0, 0.6), 0.1, 0.03, BLUE, (math.radians(90), 0, 0))
    cyl((0.32, 0, 0.18), 0.17, 0.36, TEAL, r2=0.21); tor((0.5, 0, 0.2), 0.08, 0.025, TEAL, (math.radians(90), 0, 0))
    cap((0.12, -0.02, 0.62), (0.3, -0.02, 0.4), 0.03, "#9CCBF5")
@icon("cross_case_fill", RED)                             # 照护与安全: a doctor's bag with a white cross
def _():
    rbox((0, 0, 0.36), (1.1, 0.55, 0.7), RED, 0.25)
    tor((0, 0.0, 0.74), 0.2, 0.045, "#B8302A", (math.radians(90), 0, 0))
    rbox((0, -0.28, 0.36), (0.14, 0.04, 0.42), "#FFFFFF", 0.4); rbox((0, -0.28, 0.36), (0.42, 0.04, 0.14), "#FFFFFF", 0.4)
# the month's parts
@icon("circle_hexagongrid_fill", TEAL)                    # 六个方面: six beads round a golden one
def _():
    for i, c in enumerate([TEAL, ORANGE, YELLOW, PINK, BLUE, RED]):
        a = math.radians(i * 60 + 90); sph((math.cos(a) * 0.48, 0, 0.5 + math.sin(a) * 0.42), 0.19, glossy(c))
    sph((0, 0, 0.5), 0.18, glossy("#D4A21C"))
@icon("eye_fill", BLUE)                                   # 可以留意: a magnifying glass over a sprout
def _():
    leafpair((-0.15, 0.05, 0.0), 0.6)
    tor((0.12, -0.12, 0.62), 0.3, 0.06, YELLOW, (math.radians(80), 0, 0))
    g = cyl((0.12, -0.12, 0.62), 0.28, 0.02, MATS.setdefault("glass", mat("glass", "#DCEFF6", rough=0.05, coat=1.0)), rot=(math.radians(80), 0, 0))
    cap((0.36, -0.12, 0.38), (0.62, -0.12, 0.1), 0.07, "#8A5A2B")
@icon("syringe_fill", PINK)                               # 接种与儿保: the health booklet with a star sticker
def _():
    rbox((0, 0, 0.5), (0.7, 0.12, 0.92), PINK, 0.2, (math.radians(-12), 0, 0))
    rbox((-0.3, -0.01, 0.5), (0.12, 0.13, 0.92), "#C7365C", 0.3, (math.radians(-12), 0, 0))
    rbox((0.08, -0.1, 0.66), (0.4, 0.02, 0.24), "#FFFFFF", 0.3, (math.radians(-12), 0, 0))
    star((0.16, -0.2, 0.26), 0.17, YELLOW)
@icon("lightbulb_fill", YELLOW)                           # 还要知道: a warm bulb with a face
def _():
    sph((0, 0, 0.62), 0.4, glow("#FFD45C", 0.6)); face((0, 0, 0.62), 0.4)
    cyl((0, 0, 0.18), 0.18, 0.26, GREY); tor((0, 0, 0.14), 0.18, 0.025, "#7A736B"); tor((0, 0, 0.22), 0.18, 0.025, "#7A736B")
@icon("sun_and_horizon_fill", ORANGE)                     # 一天的节奏: a sun and a moon, side by side
def _():
    sph((-0.28, 0, 0.5), 0.34, YELLOW); face((-0.28, 0, 0.5), 0.34)
    curve = [(0.38 + math.cos(math.radians(140 + i * 10)) * 0.24, 0, 0.62 + math.sin(math.radians(140 + i * 10)) * 0.24) for i in range(9)]
    tube("cres", curve, 0.08, v("#3E5A86"))
    for end in (curve[0], curve[-1]): sph(end, 0.08, "#3E5A86")
    star((0.62, -0.1, 0.3), 0.08, "#FFE9A8", 0.04)
@icon("chart_line_uptrend_xyaxis", ORANGE)                # 生长曲线: a growth ruler with a sprout climbing it
def _():
    rbox((-0.25, 0, 0.55), (0.26, 0.12, 1.1), YELLOW, 0.2)
    for i in range(8): rbox((-0.33, -0.065, 0.12 + i * 0.12), (0.1 if i % 2 else 0.16, 0.01, 0.02), "#8A5A00", 0.3)
    leafpair((0.2, 0, 0.0), 0.85)
# topics
@icon("moon_zzz_fill", LILAC)                             # 睡眠: a sleepy crescent and stars
def _():
    # a crescent: a ring segment, plump, its points up and down
    me = bpy.data.meshes.new("cres"); pts = []
    for i in range(25):
        t = math.radians(-120 + i * 10); pts.append((math.cos(t + math.pi) * 0.38, math.sin(t + math.pi) * 0.38))
    curve = [(x, 0, 0.55 + z) for x, z in pts]
    tube("cres", curve, 0.15, v("#FFE9A8"))
    for end in (curve[0], curve[-1]): sph(end, 0.15, "#FFE9A8")
    for x, z, s in ((0.45, 0.85, 0.09), (0.35, 0.35, 0.06), (0.6, 0.55, 0.05)): star((x, -0.1, z), s, "#FFFFFF", 0.04)
@icon("bed_double_fill", BLUE)                            # 安全睡眠: a crib
def _():
    rbox((0, 0, 0.18), (1.1, 0.5, 0.1), "#D6A774", 0.3)
    rbox((0, 0, 0.27), (1.0, 0.45, 0.08), "#FFFFFF", 0.4)
    for sx in (-1, 1): rbox((sx * 0.55, 0, 0.42), (0.07, 0.5, 0.84), "#C99258", 0.3)
    for i in range(7): cap((-0.45 + i * 0.15, -0.24, 0.24), (-0.45 + i * 0.15, -0.24, 0.66), 0.022, "#D6A774")
    cap((-0.55, -0.24, 0.68), (0.55, -0.24, 0.68), 0.035, "#C99258")
@icon("fork_knife", GREEN)                                # 辅食: a bowl of food and a spoon
def _():
    b = sph((0, 0, 0.32), (0.5, 0.5, 0.42), GREEN)
    import bmesh
    bm = bmesh.new(); bm.from_mesh(b.data); bmesh.ops.delete(bm, geom=[x for x in bm.verts if x.co.z > 0.0], context="VERTS"); bm.to_mesh(b.data); bm.free()
    b.modifiers.new("s", "SOLIDIFY").thickness = 0.06
    sph((-0.12, 0, 0.36), 0.16, YELLOW); sph((0.14, 0.02, 0.34), 0.14, "#FF9E7A"); sph((0.02, 0.12, 0.38), 0.12, "#7FD49A")
    cap((0.3, -0.05, 0.4), (0.7, -0.05, 0.85), 0.035, "#CFC9C0"); sph((0.27, -0.05, 0.36), (0.1, 0.06, 0.07), "#CFC9C0")
@icon("mouth_fill", TEAL)                                 # 口腔: a smiling tooth and a toothbrush
def _():
    sph((-0.12, 0, 0.55), (0.34, 0.28, 0.3), "#FFFFFF"); face((-0.12, 0, 0.55), 0.3)
    for sx in (-1, 1): cap((-0.12 + sx * 0.16, 0, 0.42), (-0.12 + sx * 0.18, 0, 0.1), 0.11, "#FFFFFF")
    cap((0.3, -0.1, 0.1), (0.62, -0.1, 0.9), 0.05, TEAL); rbox((0.62, -0.12, 0.9), (0.1, 0.14, 0.16), "#FFFFFF", 0.3, (0, math.radians(20), 0))
@icon("book_pages_fill", TEAL)                            # 专题: a closed book with a bookmark
def _():
    rbox((0, 0, 0.5), (0.7, 0.24, 0.9), TEAL, 0.18, (0, 0, math.radians(-14)))
    rbox((0.04, 0.0, 0.5), (0.64, 0.2, 0.84), CREAM, 0.15, (0, 0, math.radians(-14)))
    rbox((0.0, -0.13, 0.5), (0.66, 0.02, 0.86), TEAL, 0.2, (0, 0, math.radians(-14)))
    rbox((0.12, -0.1, 0.02), (0.1, 0.04, 0.2), RED, 0.3)
# records
@icon("heart_fill", PINK)                                 # 亲喂: a rose heart with a drop of milk (never red)
def _():
    heart((0, 0, 0.6), 0.5, "#F06B8E")
    sph((0.42, -0.25, 0.24), (0.12, 0.1, 0.13), "#FFFFFF"); cyl((0.42, -0.25, 0.38), 0.085, 0.14, "#FFFFFF", r2=0.0)
@icon("waterbottle_fill", PEACH)                          # 瓶喂: a baby bottle
def _():
    cyl((0, 0, 0.36), 0.22, 0.72, MATS.setdefault("bottle", mat("bottle", "#FFFFFF", rough=0.2, coat=0.5)))
    cyl((0, 0, 0.3), 0.205, 0.5, "#FFF3D6"); cyl((0, 0, 0.78), 0.24, 0.12, PEACH)
    cyl((0, 0, 0.93), 0.1, 0.2, "#F5C78E", r2=0.05, bevel=0.4)
    for z in (0.2, 0.35, 0.5): tor((0, 0, z), 0.215, 0.008, "#E8B490")
@icon("circle_bottomhalf_filled", BLUE)                   # 尿布: a nappy
def _():
    rbox((0, 0, 0.32), (0.95, 0.5, 0.55), "#FFFFFF", 0.4)
    rbox((0, -0.04, 0.42), (0.96, 0.46, 0.14), "#9CCBF5", 0.4)
    for sx in (-1, 1): rbox((sx * 0.4, -0.25, 0.42), (0.12, 0.04, 0.12), YELLOW, 0.4)
@icon("bathtub_fill", TEAL)                               # 洗澡: a tub, bubbles and a duck
def _():
    cyl((0, 0, 0.26), 0.62, 0.5, "#FFFFFF", r2=0.5, rot=(math.pi, 0, 0)); cyl((0, 0, 0.5), 0.56, 0.02, "#9CDDE6")
    for x, z, s in ((-0.35, 0.62, 0.12), (-0.18, 0.7, 0.09), (0.35, 0.6, 0.1)): sph((x, 0.1, z), s, MATS.setdefault("bub", mat("bub", "#FFFFFF", rough=0.05, coat=1.0)))
    sph((0.08, -0.05, 0.6), (0.2, 0.14, 0.12), YELLOW); sph((0.18, -0.05, 0.76), 0.1, YELLOW); sph((0.28, -0.05, 0.75), (0.06, 0.03, 0.03), ORANGE)
@icon("thermometer_medium", RED)                          # 体温: a thermometer
def _():
    cap((0, 0, 0.3), (0, 0, 1.05), 0.12, "#FFFFFF"); cap((0, -0.05, 0.3), (0, -0.05, 0.7), 0.06, RED); sph((0, 0, 0.22), 0.2, RED)
    for i in range(5): rbox((-0.1, -0.12, 0.55 + i * 0.1), (0.08, 0.01, 0.015), "#9A9289", 0.3)
@icon("pills_fill", YELLOW)                               # 用药: a dropper and its bottle
def _():
    cyl((-0.15, 0, 0.3), 0.26, 0.6, "#C98A4B"); rbox((-0.15, -0.25, 0.3), (0.32, 0.02, 0.24), "#FFFFFF", 0.3)
    cyl((-0.15, 0, 0.66), 0.14, 0.12, "#FFFFFF")
    cap((0.32, -0.05, 0.12), (0.4, -0.05, 0.7), 0.045, "#DCEFF6"); sph((0.41, -0.05, 0.78), (0.09, 0.09, 0.12), RED)
@icon("ruler_fill", ORANGE)                               # 生长: a tape measure
def _():
    cyl((-0.15, 0, 0.42), 0.38, 0.28, YELLOW, rot=(math.radians(90), 0, 0)); cyl((-0.15, -0.15, 0.42), 0.1, 0.02, "#C9921C", rot=(math.radians(90), 0, 0))
    rbox((0.42, -0.05, 0.07), (0.85, 0.22, 0.03), "#FFF3B0", 0.2)
    for i in range(6): rbox((0.12 + i * 0.12, -0.1, 0.09), (0.015, 0.1, 0.01), "#8A5A00", 0.3)
@icon("pencil", GREY)                                     # 备注: a pencil on a note
def _():
    rbox((0, 0.05, 0.05), (0.8, 0.9, 0.04), "#FFFFFF", 0.15, (0, 0, math.radians(-8)))
    for i in range(3): rbox((-0.08, -0.05 - i * 0.18 + 0.2, 0.08), (0.5 - i * 0.1, 0.03, 0.01), "#B9B2A8", 0.4, (0, 0, math.radians(-8)))
    cap((-0.25, -0.35, 0.18), (0.45, 0.25, 0.42), 0.07, YELLOW); cyl((0.5, 0.29, 0.44), 0.07, 0.12, "#FF8FAA", rot=(0, math.radians(55), math.radians(40)))
    sph((-0.29, -0.38, 0.17), (0.06, 0.06, 0.06), "#3B3330")
@icon("puzzlepiece_fill", TEAL)                           # 玩过: a puzzle piece
def _():
    rbox((0, 0, 0.12), (0.8, 0.8, 0.2), TEAL, 0.2); cyl((0, 0, 0.12), 0.16, 0.2, TEAL, verts=48).location = (0, 0.48, 0.12)
    cyl((0.48, 0, 0.12), 0.16, 0.2, TEAL)
@icon("list_bullet_clipboard_fill", ORANGE)               # 记录: a clipboard with stickers
def _():
    rbox((0, 0.05, 0.5), (0.8, 0.1, 1.0), "#D6A774", 0.12, (math.radians(-15), 0, 0))
    rbox((0, -0.01, 0.48), (0.66, 0.02, 0.82), "#FFFFFF", 0.1, (math.radians(-15), 0, 0))
    rbox((0, 0.02, 0.98), (0.34, 0.12, 0.12), GREY, 0.4, (math.radians(-15), 0, 0))
    for i, c in enumerate((PINK, LILAC, TEAL)): sph((-0.18, -0.06 - i * 0.05, 0.75 - i * 0.2), (0.06, 0.02, 0.06), c); rbox((0.08, -0.06 - i * 0.05, 0.75 - i * 0.2), (0.3, 0.01, 0.03), "#D8D2C8", 0.4, (math.radians(-15), 0, 0))
@icon("faceid", GREEN)                                    # 面容 ID: a padlock with a happy face
def _():
    rbox((0, 0, 0.36), (0.7, 0.4, 0.58), GREEN, 0.3); face((0, -0.15, 0.36), 0.28)
    tor((0, 0, 0.66), 0.22, 0.06, "#B9B2A8", (math.radians(90), 0, 0))
@icon("circle_lefthalf_filled", LILAC)                    # 外观: a painter's palette
def _():
    p = cyl((0, 0, 0.5), 0.55, 0.1, "#E8C48C", rot=(math.radians(70), 0, 0), bevel=0.4); p.scale = (1.15, 0.85, 1)
    for (x, z, c) in ((-0.32, 0.62, RED), (-0.08, 0.78, YELLOW), (0.22, 0.72, BLUE), (0.36, 0.45, GREEN), (-0.3, 0.32, LILAC)): sph((x, -0.08, z), (0.11, 0.06, 0.1), c)
@icon("info", TEAL)                                       # 关于: Moss himself
def _():
    r = build_moss(lid=0.05, look=(0.1, 0.1), er=0.13, pupil=0.56, perk=0.7); r.scale = (0.85, 0.85, 0.85)
@icon("square_and_arrow_up", BLUE)                        # 导出: a parcel going out
def _():
    rbox((0, 0, 0.3), (0.72, 0.6, 0.6), "#D9A86C", 0.15); rbox((0, -0.31, 0.3), (0.1, 0.02, 0.62), "#B8854F", 0.3)
    cap((0.45, -0.2, 0.55), (0.45, -0.2, 1.0), 0.06, BLUE); cyl((0.45, -0.2, 1.05), 0.14, 0.18, BLUE, r2=0.0)
@icon("square_and_arrow_down", LILAC)                     # 导入: a parcel coming in
def _():
    rbox((0, 0, 0.3), (0.72, 0.6, 0.6), "#D9A86C", 0.15); rbox((0, -0.31, 0.3), (0.1, 0.02, 0.62), "#B8854F", 0.3)
    cap((0.45, -0.2, 1.1), (0.45, -0.2, 0.7), 0.06, LILAC); cyl((0.45, -0.2, 0.62), 0.14, 0.18, LILAC, r2=0.0, rot=(math.pi, 0, 0))
@icon("doc_text_fill", GREY)                              # 使用条款: a page
def _():
    rbox((0, 0, 0.5), (0.7, 0.06, 0.95), "#FFFFFF", 0.12, (math.radians(-12), 0, 0))
    for i in range(5): rbox((-0.04, -0.04, 0.78 - i * 0.14), (0.46 - (i == 4) * 0.2, 0.01, 0.035), "#B9B2A8", 0.4, (math.radians(-12), 0, 0))
@icon("hand_raised_fill", BLUE)                           # 隐私 / 停下来: an open hand
def _():
    rbox((0, 0, 0.42), (0.5, 0.22, 0.5), SKIN, 0.4)
    for i, (x, h) in enumerate(((-0.18, 0.32), (-0.06, 0.38), (0.06, 0.38), (0.18, 0.32))): cap((x, 0, 0.6), (x, 0, 0.6 + h), 0.06, SKIN)
    cap((-0.26, 0, 0.42), (-0.42, 0, 0.62), 0.065, SKIN)
@icon("exclamationmark_bubble_fill", ORANGE)              # 免责声明: a bubble with a note
def _():
    sph((0, 0, 0.6), (0.5, 0.28, 0.4), "#FFFFFF"); sph((-0.25, 0, 0.25), (0.1, 0.1, 0.12), "#FFFFFF")
    cap((0, -0.26, 0.72), (0, -0.26, 0.56), 0.05, ORANGE); sph((0, -0.27, 0.45), 0.05, ORANGE)
@icon("books_vertical_fill", CARAMEL)                     # 内容来源: books on a shelf
def _():
    for i, (x, c, h, r) in enumerate(((-0.32, TEAL, 0.8, 0), (-0.1, RED, 0.9, 0), (0.12, YELLOW, 0.75, 0), (0.36, BLUE, 0.7, -14))):
        rbox((x, 0, h / 2 + 0.02), (0.2, 0.55, h), c, 0.15, (0, math.radians(r), 0))
@icon("checkmark_seal_fill", TEAL)                        # 许可与致谢: a rosette
def _():
    for sx in (-1, 1): rbox((sx * 0.12, 0, 0.3), (0.16, 0.04, 0.5), RED, 0.3, (0, math.radians(15 * sx), 0))
    cyl((0, -0.05, 0.68), 0.36, 0.1, YELLOW, rot=(math.radians(90), 0, 0), bevel=0.4); star((0, -0.12, 0.68), 0.18, "#FFFFFF", 0.04)
@icon("clock_arrow_circlepath", LILAC)                    # 更新日志: a calendar page
def _():
    rbox((0, 0, 0.45), (0.8, 0.2, 0.85), "#FFFFFF", 0.15); rbox((0, -0.005, 0.8), (0.8, 0.21, 0.2), LILAC, 0.3)
    for sx in (-1, 1): cap((sx * 0.22, -0.05, 0.86), (sx * 0.22, -0.05, 1.0), 0.04, GREY)
    sph((0, -0.11, 0.4), (0.16, 0.02, 0.16), PINK)
@icon("envelope_fill", PINK)                              # 反馈问题: an envelope with a heart
def _():
    rbox((0, 0, 0.36), (0.95, 0.12, 0.66), "#FFFFFF", 0.12, (math.radians(-8), 0, 0))
    heart((0, -0.12, 0.36), 0.16, PINK)
@icon("exclamationmark_triangle_fill", ORANGE)            # 安全 / 需要留意: a shield keeping a heart safe
def _():
    rbox((0, 0, 0.66), (0.72, 0.16, 0.56), "#4C9BE8", 0.4)
    o = cyl((0, 0, 0.32), 0.36, 0.4, "#4C9BE8", r2=0.03, rot=(math.pi, 0, 0), bevel=0.3); o.scale = (1, 0.22, 1)
    heart((0, -0.1, 0.6), 0.2, "#FFFFFF")
@icon("tray_full_fill", CARAMEL)                          # 准备: a wooden tray with things on it
def _():
    rbox((0, 0, 0.08), (1.1, 0.7, 0.08), "#D9AE76", 0.3)
    for (cx, cy, w, d) in ((0, -0.33, 1.1, 0.06), (0, 0.33, 1.1, 0.06), (-0.53, 0, 0.06, 0.7), (0.53, 0, 0.06, 0.7)): rbox((cx, cy, 0.15), (w, d, 0.14), "#C99258", 0.4)
    rbox((-0.25, 0, 0.3), (0.24, 0.24, 0.24), RED, 0.15, (0, 0, math.radians(20))); sph((0.15, 0, 0.3), 0.16, BLUE)
@icon("person_2_fill", PINK)                              # 一起: two small people, close
def _():
    for x, s, col, hair in ((-0.2, 1.0, "#F07BA0", "#4A3428"), (0.25, 0.75, YELLOW, "#6B4A32")):
        cap((x, 0, 0.12), (x, 0, 0.12 + 0.4 * s), 0.18 * s, col); sph((x, 0, 0.72 * s + 0.12), 0.18 * s, SKIN)
        sph((x, 0.05, 0.78 * s + 0.12), (0.17 * s, 0.15 * s, 0.1 * s), hair); face((x, 0, 0.72 * s + 0.12), 0.18 * s)
# the rest of the marks the app shows in tiles (journal links, the data page, settings, the growth book's facts)
@icon("chart_bar_fill", LILAC)                            # 最近七天: three soft bars, rising
def _():
    for i, (h, c) in enumerate(((0.38, "#C9B6F5"), (0.62, LILAC), (0.86, "#7A5BD6"))):
        rbox((-0.36 + i * 0.36, 0, h / 2 + 0.02), (0.26, 0.26, h), c, 0.3)
@icon("square_and_arrow_down_on_square_fill", LILAC)      # 导入备份: a parcel on a tray, an arrow coming in
def _():
    rbox((0, 0, 0.06), (1.0, 0.7, 0.08), "#D9AE76", 0.3)
    rbox((0, 0, 0.34), (0.6, 0.5, 0.46), "#D9A86C", 0.15); rbox((0, -0.26, 0.34), (0.1, 0.02, 0.48), "#B8854F", 0.3)
    cap((0.0, -0.3, 1.12), (0.0, -0.3, 0.8), 0.06, LILAC); cyl((0.0, -0.3, 0.72), 0.14, 0.18, LILAC, r2=0.0, rot=(math.pi, 0, 0))
@icon("lamp_desk_fill", YELLOW)                           # 摸索台灯的故事: Otto's lamp, its bead lit
def _():
    cyl((0.25, 0, 0.05), 0.28, 0.1, "#3E5A86", bevel=0.45)
    tube("rod", [(0.25, 0, 0.08), (0.25, 0, 0.6), (0.12, 0, 0.92), (-0.12, 0, 0.92), (-0.25, 0, 0.78)], 0.05, v("#3E5A86"))
    sph((-0.25, 0, 0.6), 0.16, glow("#FFC94D", 1.6))
@icon("leaf_fill", GREEN)                                 # 看他长大 / 草地: a mint sprig
def _():
    leafpair((0, 0, 0.0), 0.95)
    for sx in (-1, 1):
        l = sph((sx * 0.2, 0, 0.42), (0.2, 0.04, 0.11), GREEN if sx > 0 else "#7FD49A"); l.rotation_euler = (0, math.radians(25 * sx), 0)
@icon("tree_fill", GREEN)                                 # 树林: a round tree
def _():
    cap((0, 0, 0.0), (0, 0, 0.45), 0.09, "#A0703F")
    for x, z, s in ((0, 0.72, 0.36), (-0.25, 0.55, 0.24), (0.26, 0.56, 0.25)): sph((x, 0, z), s, GREEN if s > 0.3 else "#62C47C")
@icon("externaldrive_fill", BLUE)                         # 备份: a soft box with a light
def _():
    rbox((0, 0, 0.3), (1.0, 0.6, 0.42), "#E9EEF5", 0.3)
    rbox((0, -0.3, 0.3), (0.86, 0.02, 0.24), "#C8D3E3", 0.4); sph((0.32, -0.32, 0.3), 0.05, glow("#3CC9A0", 1.4))
@icon("exclamationmark_shield_fill", ORANGE)              # 免责声明: a shield with a soft note
def _():
    rbox((0, 0, 0.66), (0.72, 0.16, 0.56), ORANGE, 0.4)
    o = cyl((0, 0, 0.32), 0.36, 0.4, ORANGE, r2=0.03, rot=(math.pi, 0, 0), bevel=0.3); o.scale = (1, 0.22, 1)
    cap((0, -0.1, 0.8), (0, -0.1, 0.56), 0.055, "#FFFFFF"); sph((0, -0.1, 0.42), 0.055, "#FFFFFF")
@icon("scalemass_fill", GREEN)                            # 体重: a baby scale
def _():
    rbox((0, 0, 0.18), (0.95, 0.6, 0.3), "#FFFFFF", 0.35)
    cyl((0, -0.31, 0.2), 0.16, 0.02, "#DCEFF6", rot=(math.radians(90), 0, 0)); cap((0, -0.33, 0.2), (0.08, -0.33, 0.28), 0.015, RED)
    s = sph((0, 0.05, 0.42), (0.42, 0.28, 0.1), "#BDE6C8")
@icon("tablecells_fill", TEAL)                            # 表格: a grid of soft tiles
def _():
    for r in range(3):
        for c in range(3): rbox((-0.3 + c * 0.3, 0, 0.18 + r * 0.3), (0.26, 0.16, 0.26), TEAL if r == 2 else "#BFEDE8", 0.3)
@icon("square_grid_2x2_fill", YELLOW)                     # 一起玩: four blocks
def _():
    for i, (x, z, c) in enumerate(((-0.22, 0.2, RED), (0.22, 0.2, BLUE), (-0.22, 0.62, YELLOW), (0.22, 0.62, GREEN))):
        rbox((x, 0, z), (0.4, 0.4, 0.4), c, 0.22, (0, 0, math.radians(8 * (1 if i % 2 else -1))))
@icon("stethoscope", RED)                                 # 就诊摘要: a stethoscope
def _():
    pts = [(math.cos(math.radians(a)) * 0.34, 0, 0.62 + math.sin(math.radians(a)) * 0.34) for a in range(200, 341, 10)]
    tube("st", [(-0.3, 0, 1.0)] + pts + [(0.3, 0, 1.0)], 0.04, v("#3E5A86"))
    tube("st2", [(0, 0, 0.28), (0.1, 0, 0.18), (0.25, 0, 0.14)], 0.035, v("#3E5A86"))
    cyl((0.33, 0, 0.14), 0.13, 0.08, "#CFC9C0", rot=(math.radians(90), 0, 0))
    for sx in (-1, 1): sph((sx * 0.3, 0, 1.02), 0.06, RED)
@icon("circle_dashed", PINK)                              # 头围: a soft tape loop
def _():
    tor((0, 0, 0.5), 0.36, 0.07, "#FFF3B0", (math.radians(90), 0, 0))
    for i in range(10):
        a = math.radians(i * 36); rbox((math.cos(a) * 0.36, -0.07, 0.5 + math.sin(a) * 0.36), (0.02, 0.01, 0.06), "#8A5A00", 0.3, (0, -a, 0))
@icon("clock_fill", LILAC)                                # 时间: a round alarm clock
def _():
    cyl((0, 0, 0.5), 0.4, 0.22, LILAC, rot=(math.radians(90), 0, 0), bevel=0.4)
    cyl((0, -0.12, 0.5), 0.32, 0.02, "#FFFFFF", rot=(math.radians(90), 0, 0))
    cap((0, -0.14, 0.5), (0, -0.14, 0.72), 0.03, INKC); cap((0, -0.14, 0.5), (0.15, -0.14, 0.5), 0.03, INKC)
    for sx in (-1, 1): sph((sx * 0.28, 0, 0.9), 0.1, YELLOW); cap((sx * 0.25, 0, 0.1), (sx * 0.3, 0, 0.0), 0.04, LILAC)

def main():
    only = ARGS[ARGS.index("--only") + 1].split(",") if "--only" in ARGS else None
    ipath = os.path.join(ART, "index.json"); index = json.load(open(ipath))
    os.makedirs("/tmp/icons3d", exist_ok=True)
    for key, (colour, fn) in I.items():
        if only and key not in only: continue
        s = setup(colour); fn()
        p = f"/tmp/icons3d/{key}.png"; shoot(s, p)
        im = Image.open(p).convert("RGBA")
        n = f"ic_{key}.webp"; im.resize((240, 240), Image.LANCZOS).save(os.path.join(ART, n), "WEBP", quality=92, method=6)
        index["size"][n] = [240, 240]; print("wrote", n, flush=True)
    json.dump(index, open(ipath, "w"), separators=(",", ":"))
    if "--sheet" in ARGS:
        keys = [k for k in I if not only or k in only]
        sheet = Image.new("RGB", (8 * 140, ((len(keys) + 7) // 8) * 140), "#F7F2EA")
        for i, k in enumerate(keys):
            im = Image.open(os.path.join(ART, f"ic_{k}.webp")).convert("RGBA").resize((130, 130))
            sheet.paste(im, ((i % 8) * 140 + 5, (i // 8) * 140 + 5), im)
        sheet.save(ARGS[ARGS.index("--sheet") + 1])

if __name__ == "__main__":
    main()
