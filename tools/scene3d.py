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
    """The 2D layers: the backdrop with the contact shadows (under the 3D), and the marks (over it)."""
    keep = pb.Person.draw, pb.obj, pb.mark
    pb.Person.draw = lambda s, sv: None; pb.obj = lambda *a, **k: None; pb.mark = lambda *a, **k: None
    try: back = pb.scene(spec, area)
    finally: pb.Person.draw, pb.obj, pb.mark = keep
    pb.Person.draw = lambda s, sv: None; pb.obj = lambda *a, **k: None
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
            tube(f"leg{k}", [W3(p.hip, dd * 0.5 + depth * 0.5), W3(knee, dd), W3(foot, dd)], L(d["lw"]) / 2, m)
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
            tube(f"arm{k}", [W3(shp, depth + (dd - depth) * 0.6), W3(el, dd), W3(hd, dd)], L(d["aw"]) / 2, m)
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

def prop3d(o, depth):
    k, s, c = o["k"], o["s"], o["c"]
    base = W3((o["x"], o["y"]), depth)
    if k == "block":
        h = L(30 * s)
        bpy.ops.mesh.primitive_cube_add(size=2 * h, location=(base[0], depth, base[2] + h)); b = bpy.context.object
        bv = b.modifiers.new("b", "BEVEL"); bv.width = h * 0.28; bv.segments = 5
        b.rotation_euler = (0, math.radians(o.get("rot", 0)), math.radians(-24))
        b.data.materials.append(vinyl(c or "#F2554B", 0.5))
        # the carved shape on its face, as on the 2D blocks: a cream disc set into the front
        d = sphere("carve", (0, -h * 1.0, 0), (h * 0.42, h * 0.08, h * 0.42), vinyl("#FFF3E0", 0.5)); d.parent = b
    elif k == "ball":
        r = L(34 * s)
        sphere("ball", (base[0], depth, base[2] + r), (r, r, r), vinyl(c or "#F2554B", 0.55), seg=48)
        # a cloth ball's two cream panels, as bands round it
        for rz in (62, -62):
            bpy.ops.mesh.primitive_torus_add(major_radius=r * 0.985, minor_radius=r * 0.11, location=(base[0], depth, base[2] + r), rotation=(math.radians(90), 0, math.radians(rz)))
            t = bpy.context.object; t.scale = (1, 1, 0.5); t.data.materials.append(vinyl("#FFF3E0", 0.6))
            for poly in t.data.polygons: poly.use_smooth = True
    elif k == "mat":
        w = L(300 * s); t = L(20)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(base[0], depth + 0.9, base[2] - t * 0.1)); m = bpy.context.object
        m.scale = (w, 2.6, t); bv = m.modifiers.new("b", "BEVEL"); bv.width = t * 0.45; bv.segments = 4
        m.data.materials.append(vinyl(c or "#BFE3D6", 0.8))
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
    for o in objs:
        dep = 0.4 if o["k"] in ("mat",) else -0.55 * len(whos) + 0.25
        if o["k"] not in ("mat",):
            # a held thing sits with the hand that holds it; a thing on the floor between the two
            dep = -0.6
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

if __name__ == "__main__":
    out = ARGS[0]; os.makedirs(out, exist_ok=True)
    code = arg("--play", "A11")
    spec = json.load(open(pb.SCENES))[code]
    play = next(p for p in pb.C["activities"] if p["code"] == code)
    area = pb.area_of(play)
    prev = None
    for i, st in enumerate(spec):
        prev = render_step(st, area, os.path.join(out, f"{code}_{i + 1}.jpg"), arg("--size", 1440), prev, arg("--sprites", ""), i == len(spec) - 1)
