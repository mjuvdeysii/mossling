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
from ip3d import hexcol, rubber, mat, sphere, tube, smooth, M, build_moss, build_otto
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

pb.companions = lambda *a, **k: None   # the 2D companions are replaced by the 3D ones

_mark = pb.mark
def mark3d(sv, m, ppl):
    """A line of sight starts and ends at the edge of a head, not across the face (in 3D the faces turn toward us)."""
    if m["k"] == "look" and isinstance(m.get("a"), str) and isinstance(m.get("b"), str):
        def end(v, other):
            who, part = (v.split(".") + ["head"])[:2]
            p = ppl.get(who)
            if not p or part != "head": return None
            c = p.head(); r = p.d["head"] * 1.25
            dx, dy = other[0] - c[0], other[1] - c[1]; d = max(1e-3, math.hypot(dx, dy))
            return (c[0] + dx / d * r, c[1] + dy / d * r)
        ca = ppl[m["a"].split(".")[0]].head() if m["a"].split(".")[0] in ppl else None
        cb = ppl[m["b"].split(".")[0]].head() if m["b"].split(".")[0] in ppl else None
        if ca and cb:
            a, b = end(m["a"], cb), end(m["b"], ca)
            if a and b:
                sv.add(f'<path d="M{a[0]:.1f} {a[1]:.1f} L{b[0]:.1f} {b[1]:.1f}" stroke="{m.get("c", "#4C9BE8")}" stroke-width="5" stroke-dasharray="1 13" stroke-linecap="round" fill="none"/>')
                return
    _mark(sv, m, ppl)
pb.mark = mark3d

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
    # pure white melts into the paper: white things (cloths, cards, paper) are a warm porcelain instead
    if isinstance(hexc, str) and hexc.upper() in ("#FFFFFF", "#FFF", "WHITE"): hexc = "#F2EADD"
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
    skin = vinyl(p.skin, 0.55); leg = vinyl(p.leg)
    top = vinyl("#9A7BE8" if p.top == pb.GIRL_TOP else p.top)   # the girl's lilac, a step deeper so the light does not wash it out
    sp = 0.16 * (1.0 if p.kind == "adult" else 0.7)          # half the body's depth: near limbs in front, far behind
    if p.pose == "bundle":
        c = W3(p.bundle_c, depth); Lb = L(d["torso"] * 1.9); w = L(d["tw"] * 1.25)
        # a swaddled baby: a soft blanket roll in a clear blue, a fold across it
        o = sphere("bundle", c, (Lb / 2, w * 0.62, w * 0.52), vinyl("#7FB9DA", 0.8)); o.rotation_euler = (0, -math.radians(p.bundle_a), 0)
        fo = sphere("fold", (c[0] - Lb * 0.05, c[1] - w * 0.1, c[2]), (Lb * 0.1, w * 0.58, w * 0.5), vinyl("#A8D3EA", 0.8)); fo.rotation_euler = o.rotation_euler
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
    if getattr(p, "girl", False) and p.kind == "child":
        # two little pigtails at the back, each with a bow, as in the picture book
        hc = pb.HAIR["child"]
        for k2, (dx, dz) in enumerate(((-0.95, 0.35), (-0.55, 0.8))):
            pt = (c[0] + f * r * dx, c[1] - r * 0.05, c[2] + r * dz)
            sphere(f"tail{k2}", pt, (r * 0.22, r * 0.22, r * 0.3), vinyl(hc, 0.7))
            for sx in (-1, 1):
                sphere(f"bow{k2}{sx}", (pt[0] + sx * r * 0.13, pt[1] - r * 0.12, pt[2] + r * 0.12), (r * 0.13, r * 0.06, r * 0.09), vinyl(pb.BOW, 0.5))
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
    """Soft indoor light, never a sun: a large warm window light from the upper left, a broad cool fill from the right,
    a gentle back light for the outline and a generous ambient so no side goes dark — the shading models the forms
    without hot spots or burnt highlights."""
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = hexcol("#FFF3E6")
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    def area(loc, rot, e, size, col):
        bpy.ops.object.light_add(type="AREA", location=loc, rotation=rot); l = bpy.context.object
        l.data.energy = e; l.data.size = size; l.data.color = hexcol(col)[:3]
    area((0.5, -6, 6.5), (math.radians(45), 0, math.radians(-25)), 1150, 9, "#FFF1E4")
    area((7.5, -5, 3), (math.radians(70), 0, math.radians(45)), 800, 7, "#EEF2FF")
    area((3.6, 6, 6), (math.radians(-50), 0, math.radians(180)), 650, 6, "#FFF8F0")

def step_ctx(spec, area, people, objs, front, step, nsteps):
    """What the two need to know about a step to find their place: what happens (interplay), the step as the picture
    book draws it (people, things, marks — where something is, they are not; a play mat, a road are floor: they may
    sit on them), and the marks and flat things as a strict mask (not one pixel under them)."""
    play = interplay(spec, people, objs, step, nsteps)
    keep_obj, keep_sh = pb.obj, pb.SVG.shadow
    pb.obj = lambda sv, k, *a_, **kw: None if k in ("mat", "road", "kerb") else _obj(sv, k, *a_, **kw)
    pb.SVG.shadow = lambda *a_, **kw: None      # soft floor shadows are not things
    try: occupied = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=pb.scene(spec, area).svg().encode(), output_width=pb.W))).convert("RGB")
    finally: pb.obj, pb.SVG.shadow = keep_obj, keep_sh
    marks = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=front.svg().encode(), output_width=pb.W))).getchannel("A")
    return play, occupied, marks

KS = (0.86, 0.76, 0.66, 0.58, 0.52)
PLACES = ((pb.GROUND + 30, -2.2), (pb.GROUND + 16, -2.2), (pb.GROUND + 44, -2.2), (pb.GROUND + 58, -2.2), (pb.GROUND - 14, 0.95), (pb.GROUND - 30, 0.95))

def free_at(play, occupied, area, marks, x, base, k, os_, depth):
    """Whether the two fit at this place in this step: inside the picture, off furniture, not under a mark, and on
    clear paper or floor with a margin all round."""
    b = companion_box(x, base, k, os_)
    if b[0] < 24 or b[2] > pb.W - 36 or b[1] < 50 or b[3] > pb.H - 2: return False
    if any(b[0] - 10 < q[2] and b[2] + 10 > q[0] and b[1] < q[3] and b[3] > q[1] for q in play.get("furniture", [])): return False
    if marks is not None:
        m = marks.crop((int(max(0, b[0] - 10)), int(max(0, b[1] - 10)), int(min(pb.W, b[2] + 10)), int(min(pb.H, b[3] + 4))))
        if m.getbbox() and sum(m.histogram()[24:]) > 0: return False
    return pb.busy(occupied, (b[0] - 22, b[1] - 12, b[2] + 22, b[3]), area) < 0.015

def plan(spec, area):
    """One place for the whole play: the largest size and the nearest spot that is free in every step, so the two
    never jump about, change size, or drop out of a step. When the room is too full for them in some step, the whole
    play steps back a little (every step zoomed out by the same amount, so nobody changes size between steps) until
    one place fits all. Returns ("fixed", where, zoom factor), or None (each step then finds its own)."""
    for f in (1.0, 0.92, 0.85, 0.78, 0.72):
        steps = [dict(st, zoom=st.get("zoom", 1.32) * f) for st in spec]
        ctxs = []
        for i, st in enumerate(steps):
            VIEW.update(z=st["zoom"], cx=st.get("cx", 380))
            people, objs = capture(st, area)
            _, front = layers(st, area)
            ctxs.append(step_ctx(st, area, people, objs, front, i, len(spec)))
        for k in KS:
            best = None
            for base, depth in PLACES:
                for x in range(40, pb.W - 40, 6):
                    t = 1 if ctxs[0][0]["focus"][0] > x else -1
                    for os_ in (-t, t):
                        if not all(free_at(pl, oc, area, mk, x, base, k, os_, depth) for pl, oc, mk in ctxs): continue
                        score = sum(abs(x - pl["child"][0]) for pl, _, _ in ctxs) / len(ctxs) + (0 if os_ == -t else 25) + abs(pb.GROUND + 30 - base) * 0.4
                        if best is None or score < best[0]: best = (score, (x, base, k, os_, depth))
            if best: return ("fixed", best[1], f)
    return None

STAGE = False   # the 3D dais made the people look as if they floated above it: the floor stays the picture's own
TILT = math.asin(56 / 330)   # the stage camera's tilt (tools/stage3d.py)

def contact_pass(out, size):
    """The shadows the people and things cast on the 3D stage, seen by the stage's own camera (tilted down a little),
    so they lie on the floor under the figures' feet. Everything is flattened onto the floor line's depth (the front
    view stands every figure on GROUND, whatever its depth), made invisible to the camera, and lit by one soft sun from
    the upper left and front, like the key light; a shadow catcher on the floor keeps only the shadows."""
    sc = bpy.context.scene
    objs = [o for o in sc.objects if o.type not in ("CAMERA", "LIGHT")]
    root = bpy.data.objects.new("flat", None); sc.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            mw = o.matrix_world.copy(); o.parent = root; o.matrix_world = mw
    root.scale = (1, 0.001, 1)
    for o in objs: o.visible_camera = False
    for o in [o for o in sc.objects if o.type == "LIGHT"]: bpy.data.objects.remove(o)
    sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 10)); sun = bpy.context.object
    sun.data.energy = 4.0; sun.data.angle = math.radians(14)
    sun.rotation_euler = (math.radians(38), math.radians(-14), math.radians(-18))
    bpy.ops.mesh.primitive_plane_add(size=60, location=(pb.W / 2 / U, 0, 0)); fl = bpy.context.object; fl.is_shadow_catcher = True
    cam = sc.camera
    v = (pb.GROUND - pb.H / 2) / U
    f = (0, math.cos(TILT), -math.sin(TILT))
    tgt = (pb.W / 2 / U, v * math.sin(TILT), v * math.cos(TILT))
    cam.location = (tgt[0] - 30 * f[0], tgt[1] - 30 * f[1], tgt[2] - 30 * f[2]); cam.rotation_euler = (math.radians(90) - TILT, 0, 0)
    cam.data.clip_end = 100
    keep = sc.cycles.samples; sc.cycles.samples = 48
    tmp = out + ".shadow.png"; ip3d.render(tmp, size, int(size * pb.H / pb.W)); sc.cycles.samples = keep
    im = Image.open(tmp).convert("RGBA"); os.remove(tmp)
    # warm the shadow (a shadow on warm vinyl is a deeper warm, not grey) and keep it soft
    a = im.getchannel("A").point(lambda x: int(x * 0.85))
    sh = Image.new("RGBA", im.size, (92, 56, 30, 0)); sh.putalpha(a)
    return sh

def finish3d(T, size):
    """What keeps the figures and things from dissolving into the light page: a gentle contrast and colour lift, and a
    fine warm contour round every silhouette (as a printed picture book would have), drawn under the figure."""
    from PIL import ImageEnhance, ImageFilter
    a = T.getchannel("A")
    rgb = ImageEnhance.Color(ImageEnhance.Contrast(T.convert("RGB")).enhance(1.08)).enhance(1.10)
    body = rgb.convert("RGBA"); body.putalpha(a)
    k = max(3, int(size / 1200 * 5) | 1)
    rim = Image.new("RGBA", T.size, (84, 54, 30, 0)); rim.putalpha(a.filter(ImageFilter.MaxFilter(k)).point(lambda v: int(v * 0.30)))
    out = Image.new("RGBA", T.size, (0, 0, 0, 0)); out.alpha_composite(rim); out.alpha_composite(body)
    return out

def render_step(spec, area, out, size, prev=None, step=0, nsteps=1):
    VIEW.update(z=spec.get("zoom", 1.32), cx=spec.get("cx", 380))
    people, objs = capture(spec, area)
    s = ip3d.reset(); s.render.film_transparent = True; s.view_settings.view_transform = "Standard"; s.view_settings.look = "Medium Contrast"; s.view_settings.exposure = -0.85; ip3d.materials(); MATS.clear(); lights()
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
    where = None; bead = None
    # indoors, the stage is the 3D plate of the area (tools/stage3d.py): the 2D paper, disc and floor are left out
    sp = os.path.join(HERE, "stages", f"stage_{area}.png")
    stage = Image.open(sp) if STAGE and spec.get("set", "floor") == "floor" and os.path.exists(sp) and spec.get("disc", 360) == 360 else None
    pb.BACKDROP = stage is None
    try: back, front = layers(spec, area)
    finally: pb.BACKDROP = True
    if COMPANIONS:   # off: the pictures show the people and the play only; Moss and Otto act around the picture in the app
        play, occupied, marks = step_ctx(spec, area, people, objs, front, step, nsteps)
        # a place chosen for the whole play (plan) is kept as it is: the same place and size in every step
        where = prev[1] if isinstance(prev, tuple) and prev and prev[0] == "fixed" else stand(play, prev, occupied, area, marks)
        # the layout pass: a step can set its own staging for the two (scenes.json "duo": x, base, k, oside, depth, act)
        o = spec.get("duo")
        if o == "off": where = None
        elif o:
            w = list(where or (play["child"][0], pb.GROUND + 30, 0.9, -1, -2.2))
            for i, key in enumerate(("x", "base", "k", "oside", "depth")):
                if key in o: w[i] = o[key]
            where = tuple(w)
            if "act" in o: play["act"] = o["act"]
        bead = companions3d(where, play) if where else None
    bpy.ops.object.camera_add(location=(pb.W / 2 / U, -30, (pb.GROUND - pb.H / 2) / U)); c = bpy.context.object
    c.rotation_euler = (math.radians(90), 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = pb.W / U
    s.camera = c
    s.render.resolution_x, s.render.resolution_y = size, int(size * pb.H / pb.W)
    tmp = out + ".3d.png"; ip3d.render(tmp, size, int(size * pb.H / pb.W))
    shadows = contact_pass(out, size) if stage is not None else None
    if where:
        x, base, k, oside, _ = where
        back.shadow(x, base + 3, 58 * k, 10 * k, .2); back.shadow(x + GAP * k * oside, base - 7 * k, 34 * k, 7 * k, .16)
    bw = size
    B = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=back.svg().encode(), output_width=bw))).convert("RGBA")
    if stage is not None:
        # the 3D stage behind everything; the 2D back layer (contact shadows, scenery) over it
        P = stage.resize(B.size, Image.LANCZOS).convert("RGBA"); P.alpha_composite(B)
        if shadows is not None: P.alpha_composite(shadows.resize(B.size, Image.LANCZOS))
        B = P
    F = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=front.svg().encode(), output_width=bw))).convert("RGBA")
    T = finish3d(Image.open(tmp).convert("RGBA"), size)
    B.alpha_composite(T)
    if where and bead: lamplight(B, bead, play["focus"], where[1] + 4 if where[4] == 0.9 else None)
    B.alpha_composite(F)
    if out.endswith(".webp"): B.convert("RGB").save(out, "WEBP", quality=88, method=6)
    else: B.convert("RGB").save(out, quality=92)
    os.remove(tmp)
    return where

# ---------- Moss and Otto in the scene ----------
# They are in the room, not pasted beside it: real figures on the same floor under the same light. Otto turns his lamp
# toward what the child is doing and it lights it (a real light at the bead); Moss does the step with the child —
# balances a little copy of what the child holds, follows the arrow with a hop, turns wide-eyed to whoever speaks.
# They never do it for the child (docs/IP.md §4).
def page(pt):
    """A rig point to where it lands on the page (the scene's zoom applied)."""
    z, cx = VIEW["z"], VIEW["cx"]
    return (cx + (pt[0] - cx) * z, pb.GROUND + (pt[1] - pb.GROUND) * z)
def P3(px, py, depth): return (px / U, depth, (pb.GROUND - py) / U)

COMPANIONS = False
GAP = 104   # centre to centre, page px at k = 1: never one in front of the other

def companion_box(x, base, k, oside=-1):
    """Moss at x; Otto half a step behind him, `oside` × GAP·k to the side — always fully beside him: Moss is 49k
    wide each side of his centre and Otto (lamp rod included) up to 47k, so GAP leaves a clear space between them."""
    reach = (abs(oside) * GAP + 50) * k
    return (x - reach, base - 120 * k, x + 50 * k, base + 6) if oside < 0 else (x - 50 * k, base - 120 * k, x + reach, base + 6)

def place(img, spec, area, prev, focus, keep=()):
    """Where the two stand: right up beside the action, as near the focus as possible. They may stand in front of
    bodies and furniture (they are nearer the camera), but never over the focus itself or anyone's face; a place is
    also scored by how much it covers, so an open floor wins when it is as near. Within a play they keep their place
    while it still works."""
    tw = lambda x: 1 if focus[0] > x else -1
    def ok(x, base, k):
        b = companion_box(x, base, k, tw(x))
        if b[0] < 4 or b[2] > pb.W - 4: return None
        for (px, py) in [focus, *keep]:
            if b[0] - 10 < px < b[2] + 10 and b[1] - 10 < py < b[3]: return None
        return pb.busy(img, b, area)
    if prev:
        c = ok(*prev)
        if c is not None and c < 0.35: return prev
    best = None
    for k in (1.05, 0.92):
        for base in (pb.GROUND + 26, pb.GROUND + 42):
            for x in range(40, pb.W - 40, 8):
                c = ok(x, base, k)
                if c is None: continue
                score = abs(x - focus[0]) * 1.0 + c * 260 + (base - pb.GROUND) * 0.8 + (1.05 - k) * 120
                if best is None or score < best[0]: best = (score, x, base, k)
    return best[1:] if best else None

def bbox(p):
    """A person's box on the page: head, hands, feet."""
    if p.pose == "bundle": pts = [p.bundle_c, p.headc]
    else: pts = [p.hip, p.sh, p.headc, *[q for l in p.legs for q in l], *[q for a in p.arms for q in a[1:]]]
    pp = [page(q) for q in pts]; r = p.d["head"] * VIEW["z"]
    return (min(x for x, _ in pp) - r * 0.6, min(y for _, y in pp) - r, max(x for x, _ in pp) + r * 0.6, max(y for _, y in pp) + 8)

def furn(o):
    s = o["s"]; h = 124 if o["k"] == "table" else 82 * s; w = (110 if o["k"] == "table" else 40) * s
    l, t = page((o["x"] - w, o["y"] - h)); r, b = page((o["x"] + w, o["y"]))
    return (l, t, r, b)

def interplay(spec, people, objs, i, n):
    """What the two do in this step, and where: read from the step itself. The focus is the thing being played with —
    what the child holds, else the material nearest the child, else the child's hands."""
    whos = [w for w in ("adult", "child", "peer", "adult2") if w in spec]
    child = next((p for w, p in zip(whos, people) if w == "child"), None)
    adult = next((p for w, p in zip(whos, people) if w == "adult"), None)
    held = [o for o in spec.get("objs", []) if str(o.get("on", "")).startswith("child.hand")]
    floor = [o for o in objs if o["k"] not in ("mat", "table", "stool", "road", "kerb", "tree", "sun", "cloud") and o["k"] not in SCENERY]
    if child and held: focus = page(child.hand(0)); thing = None
    elif child and floor:
        c = page(child.hand(0)); near = min(floor, key=lambda o: abs(page((o["x"], o["y"]))[0] - c[0]))
        focus = page((near["x"], near["y"] - 30 * near["s"])); thing = near
    elif child: focus = page(child.hand(0)); thing = None
    else: focus = (360, pb.GROUND - 120); thing = None
    marks = spec.get("marks", [])
    arrow = next((m for m in marks if m["k"] == "arrow"), None)
    speaks = next((m for m in marks if m["k"] in ("say", "sound")), None)
    if i == n - 1: act = "glee"
    elif held and held[0]["k"] not in FLAT: act = "balance"
    elif arrow: act = "follow"
    elif speaks: act = "listen"
    else: act = "watch"
    table = next((o for o in objs if o["k"] == "table"), None)
    tb = None
    if table:
        l, t = page((table["x"] - 110 * table["s"], table["y"] - 124)); r, _ = page((table["x"] + 110 * table["s"], table["y"] - 124))
        tb = (l, r, t)
    return dict(act=act, focus=focus, held=held[0] if held else None, arrow=arrow, thing=thing, table=tb,
                child=page(child.head()) if child else focus,
                speaker=page(adult.head()) if adult else focus,
                bodies=[bbox(p) for p in people],
                furniture=[furn(o) for o in objs if o["k"] in ("stool", "table")],
                avoid=[page(p.head()) for p in people] + ([page(child.hand(0)), page(child.hand(1))] if child else []))

def stand(play, prev, occupied, area, marks=None):
    """Where the two are in one step: like family sitting with them — close to the child, on the floor in front,
    turned to the play, always whole. Nothing of theirs covers anyone, the thing being played with or a mark, and
    nothing covers them. The size of the step before is kept while it fits, so they don't change size."""
    cx = play["child"][0]; fx = play["focus"][0]
    if prev and len(prev) == 5 and free_at(play, occupied, area, marks, *prev[:4], prev[4]): return prev
    ks = KS[KS.index(prev[2]):] if prev and len(prev) == 5 and prev[2] in KS else KS
    for k in ks:
        best = None
        for base, depth in PLACES:
            for x in range(40, pb.W - 40, 6):
                t = 1 if fx > x else -1
                for os_ in (-t, t):
                    if not free_at(play, occupied, area, marks, x, base, k, os_, depth): continue
                    score = abs(x - cx) + (0 if os_ == -t else 25) + abs(pb.GROUND + 30 - base) * 0.4
                    if best is None or score < best[0]: best = (score, (x, base, k, os_, depth))
        if best: return best[1]
    return None

def companions3d(where, play):
    x, base, k, oside, depth = where
    fx, fy = play["focus"]
    toward = 1 if fx > x else -1
    sc = 0.86 * k
    ox = x + GAP * k * oside              # Otto beside Moss, the lamp held out toward the play
    look_x = 0.9 * toward
    act = play["act"]
    # Moss
    mk = dict(lid=0.05, er=0.12, pupil=0.54, perk=0.8, look=(look_x, 0.25))
    if act == "glee": mk = dict(shut="up", perk=1.0)
    elif act == "listen":
        sx, sy = play["speaker"]; mk = dict(lid=0.0, er=0.135, pupil=0.44, perk=1.0, look=(0.95 if sx > x else -0.95, 0.4))
    elif act == "follow": mk.update(perk=1.0, lean=-10 * toward)
    elif act == "lean": mk.update(lid=0.0, er=0.13, pupil=0.48, perk=1.0, lean=-14 * toward, look=(0.95 * toward, -0.2))
    elif act == "balance": mk.update(look=(0.25 * toward, 0.95), perk=0.4)
    m = build_moss(**mk)
    hop = 0.16 if act in ("follow", "glee") else 0.0
    if act == "lean": x = x + 8 * k * toward   # a little closer, the body pressed toward the thing
    m.location = P3(x, base, depth); m.location.z += hop * sc
    m.scale = (sc * (1 - hop * 0.3), sc * (1 - hop * 0.3), sc * (1 + hop * 0.6))
    m.rotation_euler = (0, math.radians(mk.get("lean", 0)), math.radians(-18 * toward))
    if act == "balance":
        # the same thing as the child holds, small, balanced on the leaves
        o = dict(play["held"]); o["s"] = o.get("s", 1) * 0.5; o.setdefault("c", None)
        top_px = base - 1.12 * sc * U
        rx = VIEW["cx"] + (x - VIEW["cx"]) / VIEW["z"]; ry = pb.GROUND + (top_px - pb.GROUND) / VIEW["z"]
        o["x"], o["y"] = rx, ry; prop3d(o, depth)
    # Otto: tired, but the lamp goes where the child is looking
    ot = dict(lid=0.45, look=(0.6 * toward, 0.0), slouch=0.6, droop=0.2, bags=True, glow=1.0)
    if act == "glee": ot = dict(lid=0.5, smirk=True, slouch=0.6, droop=0.3, bags=True, glow=1.0)
    o = build_otto(**ot)
    o.location = P3(ox, base - (8 if abs(oside) == 1 else 14) * k, depth + (0.5 if abs(oside) == 1 else 0.8))
    # the rod arches to his left: turn him round when the action is on his right, so the lamp leans over it
    o.scale = (sc * (-1 if fx > ox else 1), sc, sc)
    o.rotation_euler = (0, math.radians(6 * toward), 0)
    bpy.context.view_layer.update()
    bead = bpy.data.objects["otto_bead"].matrix_world.translation
    bpy.ops.object.light_add(type="POINT", location=bead); l = bpy.context.object
    l.data.energy = 140 * k; l.data.color = hexcol("#FFB65C")[:3]; l.data.shadow_soft_size = 0.08
    # and a soft spot from the bead onto the child's hands
    tgt = P3(fx, fy, -0.6)
    bpy.ops.object.light_add(type="SPOT", location=bead); sp = bpy.context.object
    sp.data.energy = 1600 * k; sp.data.color = hexcol("#FFC774")[:3]; sp.data.spot_size = math.radians(42); sp.data.spot_blend = 0.85
    from mathutils import Vector
    sp.rotation_euler = (Vector(tgt) - bead).to_track_quat("-Z", "Y").to_euler()
    return (bead.x * U, pb.GROUND - bead.z * U)

def lamplight(img, bead, focus, land=None):
    """What Otto's lamp does, drawn the way light looks on paper: a soft cone from the bead to the child's hands and a
    warm pool on the floor there — the adult holding the light (孩子摸索，大人点灯)."""
    from PIL import ImageDraw, ImageFilter
    sc = img.width / pb.W
    g = Image.new("RGBA", img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    bx, by = bead[0] * sc, bead[1] * sc; fx, fy = focus[0] * sc, focus[1] * sc
    floor = (land if land else pb.GROUND + 10) * sc
    w = 70 * sc
    d.polygon([(bx - 3 * sc, by), (bx + 3 * sc, by), (fx + w, floor), (fx - w, floor)], fill=(255, 226, 150, 46))
    d.ellipse((fx - w * 1.2, floor - 18 * sc, fx + w * 1.2, floor + 18 * sc), fill=(255, 244, 205, 110))
    g = g.filter(ImageFilter.GaussianBlur(14 * sc))
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0)); h = ImageDraw.Draw(halo)
    for i in range(10, 0, -1):
        r = 5 * sc * i; h.ellipse((bx - r, by - r, bx + r, by + r), fill=(255, 196, 96, 14 + 12 * (10 - i)))
    halo = halo.filter(ImageFilter.GaussianBlur(6 * sc))
    # on paper, light shows as warm colour: a soft amber wash, strongest where it lands
    img.alpha_composite(g); img.alpha_composite(halo)

def export(codes, size):
    """Into the app: the steps (and with --covers the 37 month covers) as WebP in ios/Art/art under the names the app
    already uses, and their sizes in art/index.json."""
    art = os.path.join(HERE, "..", "ios", "Art", "art"); ipath = os.path.join(art, "index.json")
    index = json.load(open(ipath)); scenes = json.load(open(pb.SCENES))
    for code in codes:
        play = next(p for p in pb.C["activities"] if p["code"] == code); area = pb.area_of(play)
        spec = scenes[code]; prev = plan(spec, area) if COMPANIONS else None
        if prev: spec = [dict(st, zoom=st.get("zoom", 1.32) * prev[2]) for st in spec]
        print(code, f"placed for the whole play (zoom ×{prev[2]})" if prev else "placed step by step", flush=True)
        for i, st in enumerate(spec):
            n = f"play_{code.lower()}_{i + 1}{pb.SUFFIX}.webp"
            got = render_step(st, area, os.path.join(art, n), size, prev, i, len(spec))
            if not (isinstance(prev, tuple) and prev and prev[0] == "fixed"): prev = got
            index["size"][n] = [size, int(size * pb.H / pb.W)]
            print("wrote", n, flush=True)
        json.dump(index, open(ipath, "w"), separators=(",", ":"))
    if "--covers" in ARGS:
        for mo in pb.C["months"]:
            spec, area = pb.cover_spec(mo["month"], mo, scenes)
            n = "cover_%02d%s.webp" % (mo["month"], pb.SUFFIX)
            render_step(spec, area, os.path.join(art, n), size, None, 1, 1)
            index["size"][n] = [size, int(size * pb.H / pb.W)]; print("wrote", n, flush=True)
        json.dump(index, open(ipath, "w"), separators=(",", ":"))

def figures():
    """The growing child on its own (the growth map, the hug, the welcome): the picture book's seven stages, now as
    the same vinyl figure as in the pictures. Square, transparent, a soft shadow under it."""
    art = os.path.join(HERE, "..", "ios", "Art", "art"); ipath = os.path.join(art, "index.json"); index = json.load(open(ipath))
    from PIL import ImageDraw, ImageFilter
    for i, (pose, age, x, k) in enumerate(pb.FIGURES):
        VIEW.update(z=k, cx=150)
        c = pb.Person("child", pose, x, face=-1, age=age, expr="wow" if pose == "lieback" else "smile", at=(x, pb.GROUND),
                      hands=[(x - 60, pb.GROUND - 86), None] if pose in ("stand", "walk") else [None, None], girl=pb.GIRL)
        sc = ip3d.reset(); sc.render.film_transparent = True; sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "Medium Contrast"; sc.view_settings.exposure = -0.85
        ip3d.materials(); MATS.clear(); lights()
        person3d(c, 0.0)
        bpy.ops.object.camera_add(location=(150 / U, -30, (pb.GROUND - (pb.GROUND - 136)) / U)); cam = bpy.context.object
        cam.rotation_euler = (math.radians(90), 0, 0); cam.data.type = "ORTHO"; cam.data.ortho_scale = 300 / U; sc.camera = cam
        tmp = f"/tmp/fig{i}.png"; ip3d.render(tmp, 600, 600)
        im = Image.open(tmp).convert("RGBA")
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(sh)
        lying = pose in ("prone", "lieback")
        hx = (150 + ((c.hip[0] - (c.d["torso"] * .45 * c.f if lying else 0)) - 150) * k) * 2
        d.ellipse((hx - 120, 2 * 290 - 14, hx + 120, 2 * 290 + 14), fill=(90, 58, 32, 50))
        sh = sh.filter(ImageFilter.GaussianBlur(10)); sh.alpha_composite(im)
        n = f"child_{i}{pb.SUFFIX}.webp"; sh.save(os.path.join(art, n), "WEBP", quality=90, method=6)
        index["size"][n] = [600, 600]; print("wrote", n, flush=True)
    json.dump(index, open(ipath, "w"), separators=(",", ":"))

def trays():
    """The shelf's trays (本周的架子): a wooden Montessori tray with a felt mat in the play's area colour and its
    materials on it — the same vinyl things as in the pictures, seen a little from above. Flat things (cards, books)
    are the picture book's own, set where the 3D tray puts them."""
    sys.path.insert(0, HERE)
    import stickers
    from bpy_extras.object_utils import world_to_camera_view
    art = os.path.join(HERE, "..", "ios", "Art", "art"); ipath = os.path.join(art, "index.json"); index = json.load(open(ipath))
    only = arg("--only", "").split(",") if "--only" in ARGS else None
    for p in pb.C["activities"]:
        code = p["code"]
        if only and code not in only: continue
        area = pb.area_of(p)
        sc = ip3d.reset(); sc.render.film_transparent = True; sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "Medium Contrast"; sc.view_settings.exposure = -0.85
        ip3d.materials(); MATS.clear(); lights()
        VIEW.update(z=1.0, cx=0)
        # the tray: a base, four rounded rails, the felt
        rbox("tray", (2.0, 0.0, 0.03), (3.3, 1.5, 0.06), "#D9AE76", 0.4, 0.55)
        for (cx, cy, w, d) in ((2.0, -0.72, 3.3, 0.08), (2.0, 0.72, 3.3, 0.08), (0.37, 0, 0.08, 1.5), (3.63, 0, 0.08, 1.5)):
            rbox("rail", (cx, cy, 0.1), (w, d, 0.16), "#C99258", 0.45, 0.55)
        rbox("felt", (2.0, 0.0, 0.065), (3.1, 1.3, 0.012), pb.AREA[area][0], 0.4, 0.9)
        flat = []
        for (k, dx, s_, c, r) in stickers.TRAYS.get(code, []):
            x = 200 + dx * 1.25
            o = dict(k=k, x=x, y=pb.GROUND - 7, s=s_ * 1.7, c=c, rot=r)
            if k in FLAT or k in SCENERY: flat.append(o)
            else: prop3d(o, 0.0)
        bpy.ops.object.camera_add(location=(2.0, -9 * math.cos(math.radians(24)), 0.55 + 9 * math.sin(math.radians(24)))); cam = bpy.context.object
        cam.rotation_euler = (math.radians(90 - 24), 0, 0); cam.data.type = "ORTHO"; cam.data.ortho_scale = 4.0; sc.camera = cam
        sc.render.resolution_x, sc.render.resolution_y = 800, 600
        bpy.context.view_layer.update()
        tmp = f"/tmp/tray_{code}.png"; ip3d.render(tmp, 800, 600)
        im = Image.open(tmp).convert("RGBA")
        from PIL import ImageDraw, ImageFilter
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).ellipse((70, 470, 730, 545), fill=(90, 58, 32, 46))
        sh = sh.filter(ImageFilter.GaussianBlur(14)); sh.alpha_composite(im); im = sh
        if flat:
            sv = pb.SVG(400, 300)
            for o in flat:
                from mathutils import Vector
                q = world_to_camera_view(sc, cam, Vector((o["x"] / U, 0.0, 0.075)))
                pb.obj = _obj
                _obj(sv, o["k"], q.x * 400, (1 - q.y) * 300, o["s"] * 0.9, o["c"], o["rot"])
            F = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=sv.svg().encode(), output_width=800))).convert("RGBA")
            im.alpha_composite(F)
        n = f"tray_{code.lower()}.webp"; im.save(os.path.join(art, n), "WEBP", quality=90, method=6)
        index["size"][n] = [800, 600]; print("wrote", n, flush=True)
    json.dump(index, open(ipath, "w"), separators=(",", ":"))

def one(code, out):
    spec = json.load(open(pb.SCENES))[code]
    play = next(p for p in pb.C["activities"] if p["code"] == code)
    area = pb.area_of(play)
    prev = plan(spec, area) if COMPANIONS else None; print(code, f"placed for the whole play (zoom ×{prev[2]})" if prev else "placed step by step", flush=True)
    if prev: spec = [dict(st, zoom=st.get("zoom", 1.32) * prev[2]) for st in spec]
    fixed = prev is not None
    steps = [int(x) - 1 for x in arg("--steps", "").split(",") if x] or range(len(spec))
    for i, st in enumerate(spec):
        if i not in steps: continue
        got = render_step(st, area, os.path.join(out, f"{code}_{i + 1}.jpg"), arg("--size", 1440), prev, i, len(spec))
        if not fixed: prev = got

if __name__ == "__main__":
    if ARGS[0] == "figures": figures(); sys.exit()
    if ARGS[0] == "trays": trays(); sys.exit()
    if ARGS[0] == "export":
        codes = arg("--play", "").split(",") if "--play" in ARGS else [a["code"] for a in pb.C["activities"] if a["code"] in json.load(open(pb.SCENES))]
        export([c for c in codes if c], arg("--size", 1440)); sys.exit()
    out = ARGS[0]; os.makedirs(out, exist_ok=True)
    for code in arg("--play", "A11").split(","):
        one(code, out)
