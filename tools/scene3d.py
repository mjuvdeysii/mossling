"""The picture-book steps as small matte soft-vinyl dioramas, so the pictures and Moss & Otto are one world (the
illustration route after the characters were settled, docs/REBUILD.md §4).

The staging is not redrawn: every step keeps its storyboard in tools/scenes.json and the 2D rig of
tools/picturebook.py — who kneels where, where the hands reach, what is held. This script takes the rig's joints and
builds the figures from them as vinyl toys (capsule limbs, an egg body for the child, round heads with painted dot eyes),
the props as rounded toy objects, and renders them with Cycles under the same product light as the characters, from
the front with an orthographic camera, so every point of the rig lands where the 2D picture had it. The paper, floor
and the drawn marks (arrows, badges, speech) stay 2D and are laid over exactly as before; Moss and Otto are the app's
own renders (tools/ip3d.py sprites), placed where picturebook.py would place them.

Usage: python3 tools/scene3d.py OUT_DIR --play A11 [--samples 64] [--sprites DIR]
"""
import io, math, os, sys, json
import bpy
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import ip3d
from ip3d import hexcol, rubber, mat, sphere, tube, smooth, M
import picturebook as pb
import cairosvg

ARGS = sys.argv[1:]
def arg(n, d): return type(d)(ARGS[ARGS.index(n) + 1]) if n in ARGS else d
U = 100.0                       # page pixels per Blender unit

# ---------- capturing the rig ----------
BUILT, OBJS = [], []
class Rec(pb.Person):
    def __init__(s, *a, **k):
        super().__init__(*a, **k); BUILT.append(s)
pb.Person = Rec
_obj = pb.obj
def rec_obj(sv, k, x, y, s=1.0, c=None, rot=0): OBJS.append(dict(k=k, x=x, y=y, s=s, c=c, rot=rot))
def capture(spec, area):
    BUILT.clear(); OBJS.clear()
    pb.obj = rec_obj
    keep = pb.Person.draw, pb.Person.draw_shadow, pb.mark
    pb.Person.draw = lambda s, sv: None
    try: pb.scene(spec, area)
    finally: pb.Person.draw = keep[0]; pb.obj = _obj
    # the last build of each person is the one with cross-references resolved (the scene builds them twice)
    people = {}
    for p in BUILT: people[id(p)] = p
    last = BUILT[-len([w for w in ("adult", "child", "peer", "adult2") if w in spec]):]
    return last, list(OBJS)

def layers(spec, area, watch=None):
    """The 2D layers: the backdrop with the scenery and the contact shadows (under the 3D), and the flat props and the
    marks (over it)."""
    keep = pb.Person.draw, pb.obj, pb.mark
    def only(kinds):
        def f(sv, k, *a, **kw):
            if k in kinds: _obj(sv, k, *a, **kw)
        return f
    pb.Person.draw = lambda s, sv: None; pb.obj = only(SCENERY); pb.mark = lambda *a, **k: None
    try: back = pb.scene(spec, area)
    finally: pb.Person.draw, pb.obj, pb.mark = keep
    pb.Person.draw = lambda s, sv: None; pb.obj = only(FLAT)
    sh = pb.SVG.shadow; pb.SVG.shadow = lambda *a, **k: None
    try: front = pb.scene(spec, area)
    finally: pb.Person.draw, pb.obj = keep[0], keep[1]; pb.SVG.shadow = sh
    i = next(n for n, e in enumerate(front.body) if e.startswith('<g transform="translate('))
    front.body = front.body[i:]
    return back, front

# ---------- page → world ----------
VIEW = {}
def W3(p, depth=0.0):
    """A page point of the rig (before the scene's zoom) to world space: x right, z up, y into the picture."""
    z, cx = VIEW["z"], VIEW["cx"]
    x = cx + (p[0] - cx) * z; y = pb.GROUND + (p[1] - pb.GROUND) * z
    return (x / U, depth, (pb.GROUND - y) / U)
def L(v): return v * VIEW["z"] / U        # a length in rig pixels to world units

MATS = {}
def vinyl(hexc, rough=0.62):
    if hexc not in MATS: MATS[hexc] = rubber("v" + hexc, hexc, rough=rough)
    return MATS[hexc]
def ink(): return MATS.setdefault("ink", mat("ink", "#2A2522", rough=0.4, coat=0.6))

def capsule(name, a, b, r, m):
    return tube(name, [a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), b], r, m)

def limb(name, pts, r, m):
    """A toy's limb: straight segments with a round joint at each bend (an articulated vinyl figure), not a hose."""
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        capsule(f"{name}_{i}", a, b, r, m)
    for i, p in enumerate(pts):   # round joints and round ends
        sphere(f"{name}_j{i}", p, (r * 1.0,) * 3, m, seg=32)

def hair_cap(c, r, f, hexc, kind):
    """Hair as a smooth cast cap: a sphere a touch larger than the head, set back and up, so it covers the crown and the
    back and leaves the face clear with a clean curved hairline (no cut edges)."""
    k = 1.0 if kind == "adult" else 0.97
    return sphere("hair", (c[0] - f * r * 0.1, c[1] + r * 0.1, c[2] + r * (0.13 if kind == "adult" else 0.3)), (r * k, r * k, r * k), vinyl(hexc, 0.7), seg=64)

def person3d(p, depth):
    d, f = p.d, p.f
    skin = vinyl(p.skin, 0.55); top = vinyl(p.top); leg = vinyl(p.leg)
    sp = 0.16 * (1.0 if p.kind == "adult" else 0.7)          # half the body's depth: near limbs in front, far behind
    if p.pose == "bundle":
        c = W3(p.bundle_c, depth); Lb = L(d["torso"] * 1.9); w = L(d["tw"] * 1.25)
        o = sphere("bundle", c, (Lb / 2, w * 0.6, w / 2), vinyl("#BFE3F0")); o.rotation_euler = (0, -math.radians(p.bundle_a), 0)
    else:
        for k, (knee, foot) in enumerate(p.legs):
            dd = depth + (sp if k == 1 else -sp)
            m = leg if k == 0 else vinyl(pb.dark(p.leg, .08))
            limb(f"leg{k}", [W3(p.hip, dd * 0.5 + depth * 0.5), W3(knee, dd), W3(foot, dd)], L(d["lw"]) / 2, m)
            if not (p.kind == "child" and p.age < 10):
                fx = W3(foot, dd); sphere(f"foot{k}", (fx[0] + f * L(d["lw"]) * 0.35, fx[1], fx[2] - L(d["lw"]) * 0.1),
                                          (L(d["lw"]) * 0.62, L(d["lw"]) * 0.5, L(d["lw"]) * 0.36), vinyl(pb.dark(p.leg, .3)))
        a, b = W3(p.hip, depth), W3(p.sh, depth)
        ln = math.dist(a, b); ang = math.atan2(b[2] - a[2], b[0] - a[0])
        mid = ((a[0] + b[0]) / 2, depth, (a[2] + b[2]) / 2)
        if p.kind == "child":
            w = L(d["tw"]) * 1.18
            t = sphere("tummy", mid, (ln / 2 + w * 0.32, w * 0.55, w * 0.55), top); t.rotation_euler = (0, -ang, 0)
            if p.age < 12: sphere("nappy", a, (w * 0.5, w * 0.5, w * 0.48), leg)
        else:
            w = L(d["tw"])
            t = sphere("torso", mid, (ln / 2 + w * 0.3, w * 0.42, w / 2), top); t.rotation_euler = (0, -ang, 0)
        for k, (shp, el, hd) in enumerate(p.arms):
            dd = depth + (sp * 1.1 if k == 1 else -sp * 1.1)
            m = top if k == 0 else vinyl(pb.dark(p.top, .08))
            limb(f"arm{k}", [W3(shp, depth + (dd - depth) * 0.6), W3(el, dd), W3(hd, dd)], L(d["aw"]) / 2, m)
            sphere(f"hand{k}", W3(hd, dd), (L(d["hand"]),) * 3, skin)
        capsule("neck", W3(p.sh, depth), W3(p.headc, depth), L(d["head"]) * 0.28, skin)
    # the head: a round vinyl head, painted dot eyes on the side it faces, turned a little toward us
    c = W3(p.headc, depth); r = L(d["head"])
    sphere("head", c, (r, r, r), skin)
    fdir = (f * 0.5, -0.866)                               # the face: toward its side and toward the camera
    def on_face(dx, dz, out=1.0):
        # a point on the head's surface, dx along the face's width, dz up
        nx, ny = fdir; px, py = -ny, nx                    # perpendicular in the floor plane
        x = nx * math.sqrt(max(0, 1 - dx * dx - dz * dz)) + px * dx * f
        y = ny * math.sqrt(max(0, 1 - dx * dx - dz * dz)) + py * dx * f
        return (c[0] + x * r * out, c[1] + y * r * out, c[2] + dz * r * out)
    if p.hair in ("bun", "bob", "short"): hair_cap(c, r, f, pb.HAIR["adult" if p.kind == "adult" else "child"], p.kind)
    if p.hair == "bun": sphere("bun", (c[0] - f * r * 0.7, c[1] + r * 0.2, c[2] + r * 0.65), (r * 0.42,) * 3, vinyl(pb.HAIR["adult"], 0.7))
    if p.hair == "tuft": tube("tuft", [(c[0], c[1], c[2] + r * 0.95), (c[0] + f * r * 0.2, c[1], c[2] + r * 1.25), (c[0] + f * r * 0.42, c[1], c[2] + r * 1.12)], r * 0.07, vinyl(pb.HAIR["child"]))
    sleep = p.expr in ("sleep", "calm")
    for k, dx in enumerate((-0.32, 0.22)):
        e = on_face(dx, 0.12, 1.0)
        if sleep:
            tube(f"lid{k}", [(e[0] - r * 0.1, e[1] - r * 0.02, e[2] + r * 0.01), (e[0], e[1] - r * 0.03, e[2] - r * 0.05), (e[0] + r * 0.1, e[1] - r * 0.02, e[2] + r * 0.01)], r * 0.028, ink())
        else:
            big = 1.15 if p.expr == "wow" else 1.0
            sphere(f"eye{k}", e, (r * 0.12 * big, r * 0.07, r * 0.16 * big), ink())
    ch = on_face(0.32 if f > 0 else -0.45, -0.2, 0.99)
    sphere("cheek", ch, (r * 0.16, r * 0.05, r * 0.1), MATS.setdefault("cheek", mat("cheekp", "#F2A0A0", rough=0.7)))
    mo = on_face(-0.04, -0.36, 1.0)
    if p.expr in ("talk", "sing", "wow"):
        sphere("mouth", mo, (r * 0.09, r * 0.05, r * (0.11 if p.expr != "talk" else 0.08)), MATS.setdefault("mouth", rubber("mouthm", "#7A2E2E", rough=0.7)))
    elif p.expr == "flat":
        tube("mouth", [(mo[0] - r * 0.1, mo[1], mo[2]), (mo[0] + r * 0.1, mo[1], mo[2])], r * 0.025, ink())
    else:
        tube("mouth", [(mo[0] - r * 0.12, mo[1], mo[2] + r * 0.03), (mo[0], mo[1] - r * 0.02, mo[2] - r * 0.05), (mo[0] + r * 0.12, mo[1], mo[2] + r * 0.03)], r * 0.028, ink())
    if p.kind == "adult": sphere("nose", on_face(-0.02, -0.08, 1.02), (r * 0.08, r * 0.08, r * 0.09), skin)

# Props: the things a family has at home, as rounded vinyl toys. Flat paper things (cards, books, photos, a phone)
# and the outdoor scenery stay as the picture book draws them — flat in life, flat here — laid in the 2D layers.
FLAT = {"card", "thing", "paper", "photo", "phone", "notebook", "book", "bookopen", "mirrorfaces", "mirror", "leaf",
        "crayon", "lantern", "dumpling", "sock", "shirt", "cloth", "cloth2", "speaker"}
SCENERY = {"tree", "sun", "cloud", "bird", "flower", "road", "kerb", "stroller"}

def rbox(name, centre, size, col, bevel=0.3, rough=0.6, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre); b = bpy.context.object; b.name = name
    b.scale = size; b.rotation_euler = rot
    m = b.modifiers.new("b", "BEVEL"); m.width = min(size) * bevel; m.segments = 5; m.limit_method = "NONE"
    b.data.materials.append(vinyl(col, rough)); return b

def cyl(name, base, r, h, col, r2=None, rough=0.6, axis="Z", bevel=0.25):
    if r2 is None: bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=r, depth=h, location=base)
    else: bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=r, radius2=r2, depth=h, location=base)
    o = bpy.context.object; o.name = name
    if axis == "Y": o.rotation_euler = (math.radians(90), 0, 0)
    m = o.modifiers.new("b", "BEVEL"); m.width = min(r, h) * bevel; m.segments = 4; m.limit_method = "NONE"
    for poly in o.data.polygons: poly.use_smooth = True
    o.data.materials.append(vinyl(col, rough)); return o

def torus(name, at, R, r, col, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=at, rotation=rot)
    t = bpy.context.object; t.name = name
    for poly in t.data.polygons: poly.use_smooth = True
    t.data.materials.append(vinyl(col)); return t

def prop3d(o, depth):
    k, s, c = o["k"], o["s"], o["c"]
    if k in FLAT or k in SCENERY: return
    X, _, Z = W3((o["x"], o["y"]), depth)
    l = lambda v: L(v * s)
    D = depth
    if k == "block":
        h = l(30)
        b = rbox("block", (X, D, Z + h), (2 * h, 2 * h, 2 * h), c or "#F2554B", 0.14, 0.5, (0, math.radians(o.get("rot", 0)), math.radians(-24)))
        d = sphere("carve", (0, -0.5, 0), (0.21, 0.04, 0.21), vinyl("#FFF3E0", 0.5)); d.parent = b
    elif k in ("blocks", "tumble"):
        cols = (c if isinstance(c, list) else None) or ["#4C9BE8", "#FFC23D", "#F2554B"]
        zz = Z
        for i, col in enumerate(cols):
            h = l(30 - i * 2) if k == "blocks" else l(26)
            if k == "blocks":
                rbox(f"blk{i}", (X + l(3) * (i % 2), D, zz + h), (2 * h, 2 * h, 2 * h), col, 0.14, 0.5, (0, 0, math.radians(-20 + i * 14))); zz += 2 * h
            else:
                dx, r = [(-44, -18), (0, 12), (46, 30)][i]
                rbox(f"blk{i}", (X + l(dx), D, Z + h), (2 * h, 2 * h, 2 * h), col, 0.14, 0.5, (0, math.radians(r), math.radians(-20)))
    elif k == "ball":
        r = l(34)
        sphere("ball", (X, D, Z + r), (r, r, r), vinyl(c or "#F2554B", 0.55), seg=48)
        for rz in (62, -62):
            t = torus("band", (X, D, Z + r), r * 0.985, r * 0.11, "#FFF3E0", (math.radians(90), 0, math.radians(rz))); t.scale = (1, 1, 0.5)
    elif k == "mat":
        w = l(300); t = L(20)
        rbox("mat", (X, D + 0.9, Z - t * 0.1), (w, 2.6, t), c or "#BFE3D6", 0.45, 0.8)
    elif k == "table":
        rbox("top", (X, D, Z + L(115)), (l(220), 1.5, L(18)), "#D6A774", 0.35, 0.55)
        for dx in (-90, 90):
            for dy in (-0.55, 0.55): cyl("leg", (X + l(dx), D + dy, Z + L(54)), L(8), L(108), "#B8854F")
    elif k == "stool":
        rbox("seat", (X, D, Z + l(74)), (l(80), 0.8, l(16)), "#D6A774", 0.4, 0.55)
        for dx in (-28, 28): cyl("leg", (X + l(dx), D, Z + l(35)), L(6), l(70), "#B8854F")
    elif k == "basket":
        col = c or "#C98A4B"
        cyl("basket", (X, D, Z + l(22)), l(52), l(44), col, r2=l(42), rough=0.8)
        bk = bpy.context.object; bk.rotation_euler = (math.radians(180), 0, 0)   # wider at the top
        for i in range(1, 4): torus("weave", (X, D, Z + l(44 - i * 11)), l(42 + i * 2.6), l(2.2), pb.dark(col, .15))
        torus("rim", (X, D, Z + l(45)), l(53), l(4.5), pb.dark(col, .06))
    elif k == "cup":
        col = c or "#1FB5A6"
        o2 = cyl("cup", (X, D, Z + l(25)), l(17), l(50), col, r2=l(22), rough=0.5)
        torus("handle", (X + l(22), D, Z + l(28)), l(11), l(3.2), pb.dark(col, .1), (math.radians(90), 0, 0))
    elif k == "drum":
        col = c or "#F2554B"
        cyl("drum", (X, D, Z + l(23)), l(40), l(46), col, rough=0.55)
        for zz in (2, 44): torus("rim", (X, D, Z + l(zz)), l(40), l(4), "#FFC23D")
        cyl("skin", (X, D, Z + l(46.5)), l(37), l(1.5), "#FFF3E0", rough=0.7)
    elif k == "cushion":
        rbox("cushion", (X, D, Z + l(15)), (l(108), 0.9, l(30)), c or "#9B7BEA", 0.48, 0.75)
    elif k == "box":
        col = c or "#4C9BE8"
        b = rbox("box", (X, D, Z + l(20)), (l(100), 0.9, l(40)), col, 0.15, 0.55)
        rbox("hole", (X, D - 0.45, Z + l(22)), (l(28), 0.05, l(8)), pb.dark(col, .45), 0.45, 0.8)
    elif k == "car":
        col = c or "#F2554B"
        rbox("body", (X, D, Z + l(27)), (l(92), l(46), l(26)), col, 0.3, 0.5)
        rbox("cab", (X + l(6), D, Z + l(46)), (l(40), l(40), l(22)), col, 0.35, 0.5)
        rbox("glass", (X + l(6), D - l(20.5), Z + l(47)), (l(30), l(1), l(13)), "#DCEFF6", 0.3, 0.2)
        for dx in (-26, 26):
            for dy in (-1, 1): cyl("wheel", (X + l(dx), D + dy * l(22), Z + l(12)), l(12), l(9), "#3B3330", axis="Y")
    elif k == "bowl":
        col = c or "#1FB5A6"
        b = sphere("bowl", (X, D, Z + l(26)), (l(34), l(34), l(30)), vinyl(col, 0.5))
        import bmesh
        bm = bmesh.new(); bm.from_mesh(b.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.0], context="VERTS"); bm.to_mesh(b.data); bm.free()
        sol = b.modifiers.new("t", "SOLIDIFY"); sol.thickness = 0.08
        sphere("fruit", (X - l(8), D, Z + l(24)), (l(9),) * 3, vinyl("#FFC23D")); sphere("fruit2", (X + l(10), D - l(4), Z + l(22)), (l(8),) * 3, vinyl("#4DB86A"))
    elif k == "plate":
        cyl("plate", (X, D, Z + l(3)), l(44), l(5), "#FFFFFF", r2=l(36), rough=0.4)
        bpy.context.object.rotation_euler = (math.radians(180), 0, 0)
    elif k == "pot":
        col = c or "#F2554B"
        cyl("pot", (X, D, Z + l(20)), l(38), l(40), col, rough=0.5)
        torus("rim", (X, D, Z + l(41)), l(40), l(4), pb.dark(col, .1))
        rbox("handle", (X + l(50), D, Z + l(32)), (l(26), l(8), l(8)), pb.dark(col, .25), 0.45)
    elif k == "spoon":
        a = math.radians(-(o.get("rot") or 30))
        tip = (X + math.sin(-a) * l(40), D, Z + math.cos(a) * l(40))
        capsule("spoon", (X, D, Z + l(4)), tip, l(3), vinyl("#B9B2A8", 0.4))
        sphere("bowl", (X + math.sin(-a) * l(46), D, Z + math.cos(a) * l(46)), (l(8), l(5), l(11)), vinyl("#CFC9C0", 0.4)).rotation_euler = (0, a, 0)
    elif k == "rattle":
        col = c or "#9B7BEA"
        capsule("handle", (X, D, Z + l(8)), (X + l(12), D, Z + l(52)), l(5), vinyl("#E2B57A"))
        for i, rc in enumerate(["#FFC23D", "#1FB5A6", "#FF6F91"]):
            t = l(14 + i * 13); torus("ring", (X + t * 0.27, D, Z + t), l(6.5), l(2.5), rc, (0, math.radians(-15), 0))
        sphere("head", (X + l(14), D, Z + l(74)), (l(20),) * 3, vinyl(col, 0.5))
    elif k == "doll":
        col = c or "#9B7BEA"
        cyl("dress", (X, D, Z + l(25)), l(22), l(50), col, r2=l(14), rough=0.7)
        sk = vinyl("#F6D2B0", 0.55); r = l(18)
        sphere("dhead", (X, D, Z + l(66)), (r, r, r), sk)
        sphere("dhair", (X, D + r * 0.15, Z + l(70)), (r * 1.02,) * 3, vinyl("#8B5A3C", 0.7))
        for dx in (-0.33, 0.33): sphere("deye", (X + dx * r, D - r * 0.93, Z + l(66)), (r * 0.09, r * 0.05, r * 0.12), ink())
        for sx in (-1, 1): capsule("darm", (X + sx * l(14), D, Z + l(44)), (X + sx * l(24), D, Z + l(26)), l(6), vinyl(pb.dark(col, .1)))
    elif k == "dollbed":
        r = l(17)
        sphere("dhead", (X - l(44), D, Z + l(20)), (r, r, r), vinyl("#F6D2B0", 0.55))
        rbox("blanket", (X + l(13), D, Z + l(17)), (l(86), 0.7, l(34)), c or "#4C9BE8", 0.45, 0.75)
    else:
        print("no 3D model yet for", k)

def lights():
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = hexcol("#FFF6EC")
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
    def area(loc, rot, e, size, col):
        bpy.ops.object.light_add(type="AREA", location=loc, rotation=rot); l = bpy.context.object
        l.data.energy = e; l.data.size = size; l.data.color = hexcol(col)[:3]
    area((0.5, -6, 6.5), (math.radians(45), 0, math.radians(-25)), 1700, 6, "#FFF4EA")
    area((7.5, -5, 3), (math.radians(70), 0, math.radians(45)), 900, 5, "#F4F6FF")
    area((3.6, 6, 6), (math.radians(-50), 0, math.radians(180)), 1400, 4, "#FFFFFF")

def render_step(spec, area, out, size, prev=None, sprites_dir=None, last=False):
    VIEW.update(z=spec.get("zoom", 1.32), cx=spec.get("cx", 380))
    people, objs = capture(spec, area)
    s = ip3d.reset(); s.render.film_transparent = True; s.view_settings.view_transform = "Standard"; s.view_settings.look = "None"; s.view_settings.exposure = -0.75; ip3d.materials(); MATS.clear(); lights()
    order = spec.get("order", ["adult2", "peer", "child", "adult"] if spec.get("child_front") else ["adult2", "adult", "peer", "child"])
    whos = [w for w in ("adult", "child", "peer", "adult2") if w in spec]
    for who, p in zip(whos, people):
        n = order.index(who) if who in order else 0
        person3d(p, -0.55 * n)
    # where each prop goes in depth, in the order picturebook.scene draws them: scenery at the back, things on the
    # floor behind the people (the picture book draws them first), things in front and things held in front of them
    so = spec.get("objs", [])
    flags = [("back", o) for o in so if o.get("back")] + [("floor", o) for o in so if not o.get("back") and not o.get("front") and not o.get("on")]
    for o in so:
        if o.get("front"): flags.append(("front", o))
        if o.get("on"): flags.append(("on", o))
    j = 0
    for i, o in enumerate(objs):
        if o["k"] == "mirror" and i > 0 and objs[i - 1]["k"] == "mirrorfaces": continue   # drawn inside mirrorfaces
        kind = flags[j][0] if j < len(flags) else "floor"; j += 1
        dep = {"back": 1.5, "floor": 0.45, "front": -0.55 * len(whos) - 0.4, "on": -0.55 * len(whos) + 0.1}[kind]
        if o["k"] == "mat": dep = 0.4
        prop3d(o, dep)
    bpy.ops.object.camera_add(location=(pb.W / 2 / U, -30, (pb.GROUND - pb.H / 2) / U)); c = bpy.context.object
    c.rotation_euler = (math.radians(90), 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = pb.W / U
    s.camera = c
    s.render.resolution_x, s.render.resolution_y = size, int(size * pb.H / pb.W)
    tmp = out + ".3d.png"; ip3d.render(tmp, size, int(size * pb.H / pb.W))
    back, front = layers(spec, area)
    bw = size
    B = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=back.svg().encode(), output_width=bw))).convert("RGBA")
    F = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=front.svg().encode(), output_width=bw))).convert("RGBA")
    T = Image.open(tmp).convert("RGBA")
    B.alpha_composite(T); B.alpha_composite(F)
    where = pb.place_watchers(B.convert("RGB").resize((360, 270)), spec, area, prev) if not spec.get("companions") else None
    if where and sprites_dir: watchers(B, where, sprites_dir, last)
    B.convert("RGB").save(out, quality=92); os.remove(tmp)
    return where

def watchers(img, where, d, happy):
    x, base, k, ax = where
    sc = img.width / pb.W
    right = ax > x
    m = Image.open(os.path.join(d, "moss_" + ("glee" if happy else "right" if right else "left") + ".png")).convert("RGBA")
    o = Image.open(os.path.join(d, "otto_" + ("glee" if happy else "right" if right else "left") + ".png")).convert("RGBA")
    ms, os_ = int(108 * k * sc), int(112 * k * sc)
    m = m.resize((ms, ms), Image.LANCZOS); o = o.resize((os_, os_), Image.LANCZOS)
    feet_m, feet_o = 0.859, 0.891
    # Otto half a step behind, to the right (inside the free place picturebook.place_watchers found)
    ox = x + 50 * k
    img.alpha_composite(o, (int(ox * sc - os_ / 2), int((base - 8 * k) * sc - feet_o * os_)))
    img.alpha_composite(m, (int(x * sc - ms / 2), int(base * sc - feet_m * ms)))

def one(code, out):
    spec = json.load(open(pb.SCENES))[code]
    play = next(p for p in pb.C["activities"] if p["code"] == code)
    area = pb.area_of(play)
    prev = None
    steps = [int(x) - 1 for x in arg("--steps", "").split(",") if x] or range(len(spec))
    for i, st in enumerate(spec):
        if i not in steps: continue
        prev = render_step(st, area, os.path.join(out, f"{code}_{i + 1}.jpg"), arg("--size", 1440), prev, arg("--sprites", ""), i == len(spec) - 1)

if __name__ == "__main__":
    out = ARGS[0]; os.makedirs(out, exist_ok=True)
    for code in arg("--play", "A11").split(","):
        one(code, out)
