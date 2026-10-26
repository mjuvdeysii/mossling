"""Moss and Otto as 3D characters, rendered with Blender Cycles (bpy), for the app's IP art.

Why: the companions drawn as flat 2D paths cannot reach the soft, tactile look of an animated feature. Here they are
modelled once — Moss a velvety moss pebble with a mint sprout, Otto a matte clay capsule with one big eye and a lamp on
a curved antenna (docs/IP.md §4) — lit like a film set (warm key, cool rim, soft fill, the lamp's own light) and
rendered with subsurface scattering, sheen, soft shadows and depth of field. Poses and expressions are parameters, so
every picture of them comes from the same model.

Usage:
  python3 tools/ip3d.py hero out.png [--w 1600 --h 1000 --samples 96]
  python3 tools/ip3d.py sheet out.png                 a sheet of expressions
"""
import math, sys, os
import bpy
from mathutils import Vector, Euler

ARGS = sys.argv[1:]
def arg(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default

def hexcol(h, a=1.0):
    h = h.lstrip("#"); r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), a)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = arg("--samples", 96)
    s.cycles.use_denoising = True
    s.view_settings.view_transform = "AgX"
    s.view_settings.look = "AgX - Punchy"
    s.render.film_transparent = "--transparent" in ARGS
    return s

# ---------- materials ----------
def mat(name, base, rough=0.5, sss=0.0, sss_rad=(0.2, 0.1, 0.05), sheen=0.0, sheen_tint=None, coat=0.0, emit=None, emit_strength=0.0, bump=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = hexcol(base)
    p.inputs["Roughness"].default_value = rough
    if sss:
        p.inputs["Subsurface Weight"].default_value = sss
        p.inputs["Subsurface Radius"].default_value = sss_rad
        p.inputs["Subsurface Scale"].default_value = 0.05
    if sheen:
        p.inputs["Sheen Weight"].default_value = sheen
        p.inputs["Sheen Roughness"].default_value = 0.4
        if sheen_tint: p.inputs["Sheen Tint"].default_value = hexcol(sheen_tint)
    if coat:
        p.inputs["Coat Weight"].default_value = coat
        p.inputs["Coat Roughness"].default_value = 0.03
    if emit:
        p.inputs["Emission Color"].default_value = hexcol(emit)
        p.inputs["Emission Strength"].default_value = emit_strength
    if bump:
        # a fine noise: moss fuzz or clay texture
        tex = nt.nodes.new("ShaderNodeTexNoise"); tex.inputs["Scale"].default_value = bump[0]; tex.inputs["Detail"].default_value = 8
        bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = bump[1]; bm.inputs["Distance"].default_value = 0.02
        nt.links.new(tex.outputs["Fac"], bm.inputs["Height"]); nt.links.new(bm.outputs["Normal"], p.inputs["Normal"])
    return m

def rubber(name, base, rough=0.6, sss=0.04, ior_level=0.35):
    """Soft matte vinyl, as designer toys are cast: an even colour, a soft broad sheen, a hint of light through the
    edges, and a fine orange-peel surface. No fur, no gloss, no painted texture."""
    m = mat(name, base, rough=rough, sss=sss, sss_rad=(0.4, 0.3, 0.25), bump=(700, 0.025))
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Specular IOR Level"].default_value = ior_level
    return m

def moss_material():
    """Velvety moss: a green that varies in lighter tufts (noise through a colour ramp), sheen for the fuzz, a little
    subsurface so the light glows through the edges, and fine bump."""
    m = mat("moss", "#55704A", rough=0.8, sss=0.1, sss_rad=(0.3, 0.5, 0.15), sheen=0.55, sheen_tint="#BFD9A0", bump=(260, 0.3))
    nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    n = nt.nodes.new("ShaderNodeTexNoise"); n.inputs["Scale"].default_value = 14; n.inputs["Detail"].default_value = 6; n.inputs["Roughness"].default_value = 0.65
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position = 0.42; r.color_ramp.elements[0].color = hexcol("#4C6A41")
    r.color_ramp.elements[1].position = 0.72; r.color_ramp.elements[1].color = hexcol("#6B8A55")
    nt.links.new(n.outputs["Fac"], r.inputs["Fac"]); nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    return m

# ---------- shapes ----------
def smooth(o, levels=3):
    mod = o.modifiers.new("sub", "SUBSURF"); mod.levels = levels; mod.render_levels = levels
    for poly in o.data.polygons: poly.use_smooth = True
    return o

def sphere(name, loc, scale, material, seg=48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=loc)
    o = bpy.context.object; o.name = name; o.scale = scale
    for poly in o.data.polygons: poly.use_smooth = True
    o.data.materials.append(material); return o

def parent(children, root):
    for c in children: c.parent = root

def leaf(name, at, rot, length, material):
    """A mint leaf: a flattened, pointed ellipsoid."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=(0, 0, 0))
    o = bpy.context.object; o.name = name
    for v in o.data.vertices:
        x, y, z = v.co
        taper = 1 - 0.55 * max(0, x)          # pointed at the tip
        v.co = Vector((x * length / 2 + length / 2, y * 0.62 * length / 2 * taper, z * 0.09 * length))
        v.co.z += 0.18 * length * (v.co.x / length) ** 2   # a gentle upward curl
    for poly in o.data.polygons: poly.use_smooth = True
    o.location = at; o.rotation_euler = rot
    o.data.materials.append(material); return o

def tube(name, points, radius, material):
    cd = bpy.data.curves.new(name, "CURVE"); cd.dimensions = "3D"; cd.bevel_depth = radius; cd.bevel_resolution = 6
    sp = cd.splines.new("BEZIER"); sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p; bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cd); bpy.context.collection.objects.link(o)
    o.data.materials.append(material); return o

M = {}
def materials():
    M["moss"] = rubber("moss", "#55704A")
    M["mint"] = rubber("mint", "#7FCBA0", rough=0.5, sss=0.2)
    M["mintPale"] = rubber("mintPale", "#A9E0C0", rough=0.5, sss=0.2)
    M["mintDeep"] = mat("mintDeep", "#3D6B44", rough=0.6)
    M["otto"] = rubber("otto", "#203872")
    M["ottoDeep"] = rubber("ottoDeep", "#1F3566")
    # painted eyes: a satin white and a glossy black, as on a vinyl figure
    M["eye"] = mat("eye", "#F6F3EA", rough=0.35, coat=0.35)
    M["pupil"] = mat("pupil", "#0E0E0D", rough=0.05, coat=1.0)
    M["iris"] = mat("iris", "#3A2A20", rough=0.2, coat=1.0)
    M["catch"] = mat("catch", "#FFFFFF", rough=0.1, emit="#FFFFFF", emit_strength=4.0)
    halo = bpy.data.materials.new("halo"); halo.use_nodes = True; nt = halo.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader"); fres = nt.nodes.new("ShaderNodeLayerWeight"); fres.inputs["Blend"].default_value = 0.25
    em.inputs["Color"].default_value = hexcol("#FFC66E"); em.inputs["Strength"].default_value = 2.5
    nt.links.new(fres.outputs["Facing"], mix.inputs["Fac"]); nt.links.new(em.outputs[0], mix.inputs[1]); nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"]); M["halo"] = halo
    M["cheek"] = mat("cheek", "#F49AB0", rough=0.6, sss=0.3)
    M["foot"] = rubber("foot", "#22231F")
    M["bead"] = mat("bead", "#D49A12", rough=0.35, emit="#FFA81E", emit_strength=0.0, coat=0.3, sss=0.3, sss_rad=(1.0, 0.6, 0.2))

def eye(name, at, r, look, scale=(1, 0.75, 1.1), lid=0.0, skin=None, pupil=0.55):
    """An eye: a glossy white, a pupil that looks where asked, a lid of the body's material when half closed."""
    w = sphere(name, at, (r * scale[0], r * scale[1], r * scale[2]), M["eye"])
    lx, lz = look
    pr = r * pupil
    px, py, pz = at[0] + lx * r * 0.42, at[1] - r * scale[1] * 0.78, at[2] + lz * r * 0.42
    p = sphere(name + "_p", (px, py - 0.002, pz), (pr, pr * 0.42, pr), M["pupil"])
    # the catchlight that makes an eye alive: a small bright spot up and to the left of the pupil
    c = sphere(name + "_c", (px - pr * 0.42, py - pr * 0.2, pz + pr * 0.42), (pr * 0.26, pr * 0.1, pr * 0.26), M["catch"])
    parts = [w, p, c]
    if lid > 0 and skin:
        # the lid: the body's skin covering the top of the eye
        l = sphere(name + "_lid", at, (r * scale[0] * 1.06, r * scale[1] * 1.1, r * scale[2] * 1.06), skin)
        bpy.ops.object.select_all(action="DESELECT"); l.select_set(True); bpy.context.view_layer.objects.active = l
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="DESELECT"); bpy.ops.object.mode_set(mode="OBJECT")
        cut = (1 - 2 * lid)
        for v in l.data.vertices: v.select = v.co.z < cut
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.delete(type="VERT"); bpy.ops.object.mode_set(mode="OBJECT")
        parts.append(l)
    return parts

def shaped_sphere(name, f, material, seg=64):
    """A sphere whose vertices are moved by f(x, y, z) -> (x, y, z) from unit coordinates."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=(0, 0, 0))
    o = bpy.context.object; o.name = name
    for v in o.data.vertices: v.co = Vector(f(*v.co))
    for poly in o.data.polygons: poly.use_smooth = True
    o.data.materials.append(material); return o

# Moss: a pebble 1.24 wide, 1.0 deep, its top at 0.74; the bottom flattened where it rests
MOSS = dict(rx=0.62, ry=0.52, rz=0.46, cz=0.27)
def moss_surface_y(x, z):
    m = MOSS; k = 1 - (x / m["rx"]) ** 2 - ((z - m["cz"]) / m["rz"]) ** 2
    return -m["ry"] * math.sqrt(max(0.0, k))

def build_moss(x=0.0, look=(0.45, 0.7), happy=False, lean=0.0, lid=0.0, er=0.105, pupil=0.62):
    m = MOSS
    root = bpy.data.objects.new("Moss", None); bpy.context.collection.objects.link(root)
    # the icon's pebble: higher on the right, the left shoulder lower and rounder, the base flattened where it rests
    def f(a, b, c):
        z = (c if c > 0 else c * 0.55) * m["rz"]
        if c > 0: z *= 1 + 0.22 * a
        return (a * m["rx"], b * m["ry"], m["cz"] + z)
    body = shaped_sphere("moss_body", f, M["moss"])
    feet = [sphere(f"moss_foot{i}", (s * 0.22, -0.12, 0.045), (0.08, 0.1, 0.055), M["foot"]) for i, s in enumerate((-1, 1))]
    top = m["cz"] + m["rz"]
    stem = tube("moss_stem", [(0, -0.02, top - 0.04), (0.01, -0.03, top + 0.07), (0.0, -0.02, top + 0.15)], 0.014, M["mintDeep"])
    # as on the icon: two big leaves and two small pale ones on a thin stem
    leaves = [leaf("moss_leafL", (0.0, -0.02, top + 0.14), Euler((0.25, -0.45, math.radians(165))), 0.27, M["mint"]),
              leaf("moss_leafR", (0.0, -0.02, top + 0.14), Euler((-0.2, -0.4, math.radians(15))), 0.31, M["mint"]),
              leaf("moss_leafS1", (0.0, -0.02, top + 0.15), Euler((0.1, -1.1, math.radians(120))), 0.13, M["mintPale"]),
              leaf("moss_leafS2", (0.0, -0.02, top + 0.15), Euler((0.0, -1.2, math.radians(60))), 0.12, M["mintPale"])]
    parts = [body, *feet, stem, *leaves]
    ez, ex = m["cz"] + 0.2, 0.125
    for s in (-1, 1):
        sy = moss_surface_y(s * ex, ez)
        if happy:
            parts.append(tube(f"moss_smile{s}", [(s * ex - 0.07, sy - 0.005, ez - 0.01), (s * ex, sy - 0.02, ez + 0.045), (s * ex + 0.07, sy - 0.005, ez - 0.01)], 0.013, M["pupil"]))
        else:
            parts += eye(f"moss_eye{s}", (s * ex, sy + 0.025, ez), er, look, scale=(0.87, 0.5, 1.0), lid=lid, skin=M["moss"], pupil=pupil)
    if happy or "--cheeks" in ARGS:
        for s in (-1, 1):
            cz = m["cz"] + 0.04; cx = s * 0.3
            parts.append(sphere(f"moss_cheek{s}", (cx, moss_surface_y(cx, cz) + 0.012, cz), (0.075, 0.015, 0.045), M["cheek"]))
    parent(parts, root)
    root.location = (x, 0, 0); root.rotation_euler = (0, math.radians(lean), 0)
    return root

# Otto: a tall dome 0.84 wide, its top at 1.26, the bottom rounded onto the table
OTTO = dict(rx=0.45, ry=0.41, cz=0.48, top=0.64, bottom=0.44)
OTTO_PROFILE = [(0.03, 0.0), (0.09, 0.41), (0.22, 0.455), (0.45, 0.45), (0.7, 0.425), (0.9, 0.37), (1.04, 0.27), (1.12, 0.14), (1.14, 0.0)]
def otto_radius(z):
    for (z0, r0), (z1, r1) in zip(OTTO_PROFILE, OTTO_PROFILE[1:]):
        if z0 <= z <= z1: return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return 0.0
def otto_surface_y(x, z):
    r = otto_radius(z) * 0.97   # the subdivided surface sits a little inside the profile
    return -0.9 * math.sqrt(max(0.0, r * r - x * x))

def build_otto(x=0.0, look=(-0.3, 0.0), lid=0.3, glow=1.0, lean=0.0, happy=False):
    o = OTTO
    root = bpy.data.objects.new("Otto", None); bpy.context.collection.objects.link(root)
    # turned like a wooden toy: a profile spun round its axis — a broad soft base, nearly straight sides that lean in a
    # little, and a round dome (the icon's silhouette), then smoothed
    prof = [(0.0, 0.03), (0.28, 0.035), (0.41, 0.09), (0.455, 0.22), (0.45, 0.45), (0.425, 0.7), (0.37, 0.9), (0.27, 1.04), (0.14, 1.12), (0.0, 1.14)]
    me = bpy.data.meshes.new("otto_profile"); me.from_pydata([(x, 0, z) for x, z in prof], [(i, i + 1) for i in range(len(prof) - 1)], [])
    body = bpy.data.objects.new("otto_body", me); bpy.context.collection.objects.link(body)
    sc = body.modifiers.new("spin", "SCREW"); sc.steps = 64; sc.render_steps = 64; sc.use_merge_vertices = True; sc.use_smooth_shade = True
    smooth(body, 2)
    body.scale = (1.0, 0.9, 1.0)
    body.data.materials.append(M["otto"])
    feet = [sphere(f"otto_foot{i}", (s * 0.17, -0.1, 0.045), (0.075, 0.095, 0.055), M["foot"]) for i, s in enumerate((-1, 1))]
    parts = [body, *feet]
    ez = 0.8
    if happy:
        sy = otto_surface_y(0, ez)
        parts.append(tube("otto_smile", [(-0.12, sy + 0.01, ez - 0.02), (0.0, sy - 0.015, ez + 0.06), (0.12, sy + 0.01, ez - 0.02)], 0.016, M["pupil"]))
        parts.append(sphere("otto_cheek", (0.24, otto_surface_y(0.24, ez - 0.14) + 0.01, ez - 0.14), (0.065, 0.015, 0.04), M["cheek"]))
    else:
        parts += eye("otto_eye", (0.0, otto_surface_y(0, ez) + 0.06, ez), 0.21, look, scale=(1.05, 0.5, 0.95), lid=lid, skin=M["otto"], pupil=0.57)
    # the antenna: from the top of the head, arching forward, the lamp bead at its end
    top = (0.0, 0.0, 1.13)
    # the icon's rod: up from the crown, arching forward and to the left, the bead hanging at its end
    bx, by, bz = -0.36, -0.22, top[2] + 0.12
    parts.append(tube("otto_antenna", [top, (-0.02, -0.03, top[2] + 0.2), (-0.2, -0.12, top[2] + 0.28), (bx, by, bz + 0.07)], 0.015, M["ottoDeep"]))
    parts.append(sphere("otto_bead", (bx, by, bz), (0.07, 0.07, 0.07), M["bead"]))
    # (the glow round the bead is added in 2D, over the render)
    M["bead"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.6 * glow
    if glow > 0:
        bpy.ops.object.light_add(type="POINT", location=(bx, by - 0.02, bz - 0.04)); lamp = bpy.context.object
        lamp.data.energy = 25 * glow; lamp.data.color = hexcol("#FFC66E")[:3]; lamp.data.shadow_soft_size = 0.07
        parts.append(lamp)
    parent(parts, root)
    root.location = (x, 0.2, 0); root.rotation_euler = (0, math.radians(lean), 0)
    return root

# ---------- set ----------
def table_and_lights(night=False):
    # a wooden table top and a soft wall behind
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0)); t = bpy.context.object
    wood = mat("wood", "#C99A62", rough=0.55, bump=(14, 0.12))
    nt = wood.node_tree; p = nt.nodes["Principled BSDF"]
    w = nt.nodes.new("ShaderNodeTexWave"); w.inputs["Scale"].default_value = 1.6; w.inputs["Distortion"].default_value = 6; w.inputs["Detail"].default_value = 3
    r = nt.nodes.new("ShaderNodeValToRGB"); r.color_ramp.elements[0].color = hexcol("#B98450"); r.color_ramp.elements[1].color = hexcol("#D9AE77")
    nt.links.new(w.outputs["Fac"], r.inputs["Fac"]); nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    t.data.materials.append(wood)
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 5.5, 3), rotation=(math.radians(90), 0, 0)); wall = bpy.context.object
    wall.data.materials.append(mat("wall", "#3A3350" if night else "#F3E6D3", rough=0.9))
    world = bpy.data.worlds.new("w"); bpy.context.scene.world = world; world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = hexcol("#2A2540" if night else "#FFF4E6")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.12 if night else 0.3
    def area(loc, rot, energy, size, color):
        bpy.ops.object.light_add(type="AREA", location=loc, rotation=rot); l = bpy.context.object
        l.data.energy = energy; l.data.size = size; l.data.color = hexcol(color)[:3]; return l
    # key: warm, high left; rim: cool, behind right; fill: soft from the front
    area((-2.4, -2.2, 3.4), (math.radians(45), 0, math.radians(-45)), 520 if not night else 60, 1.4, "#FFE1BE")
    area((2.4, 2.2, 2.4), (math.radians(-60), 0, math.radians(140)), 260 if not night else 90, 1.2, "#BFD8FF")
    area((0.4, -3.4, 1.0), (math.radians(80), 0, 0), 90 if not night else 10, 3.0, "#FFF6EA")

def studio(color="#E8E1D5"):
    """A product-photography set, as figures are shot for a catalogue: a seamless curved backdrop in one warm grey, one
    big soft key from the front left, a fill, a rim from behind, and a soft contact shadow under each figure."""
    import math as m
    prof = [(-6.0, 0.0)] + [(2.0 + 1.5 * m.sin(t * m.pi / 2), 1.5 - 1.5 * m.cos(t * m.pi / 2)) for t in [i / 12 for i in range(13)]] + [(3.5, 6.0)]
    verts, faces = [], []
    for x in (-8.0, 8.0):
        for (y, z) in prof: verts.append((x, y, z))
    n = len(prof)
    for i in range(n - 1): faces.append((i, i + 1, n + i + 1, n + i))
    me = bpy.data.meshes.new("cyc"); me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("cyc", me); bpy.context.collection.objects.link(o)
    for poly in me.polygons: poly.use_smooth = True
    o.data.materials.append(mat("cyc", color, rough=0.95))
    world = bpy.data.worlds.new("w"); bpy.context.scene.world = world; world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = hexcol("#FFF6EC")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
    def area(loc, rot, energy, size, color):
        bpy.ops.object.light_add(type="AREA", location=loc, rotation=rot); l = bpy.context.object
        l.data.energy = energy; l.data.size = size; l.data.color = hexcol(color)[:3]; return l
    area((-2.2, -3.0, 3.0), (math.radians(55), 0, math.radians(-35)), 520, 3.2, "#FFF1E0")   # key: a big softbox
    area((2.8, -2.4, 1.4), (math.radians(75), 0, math.radians(50)), 160, 3.0, "#F4F6FF")      # fill
    area((1.5, 2.8, 2.8), (math.radians(-55), 0, math.radians(150)), 380, 1.5, "#FFFFFF")     # rim

def board3d(out):
    """Gate 1 again, in matte vinyl: one Otto, three Moss personalities, the same set and light."""
    from PIL import Image
    variants = [("v1", dict(look=(0.45, 0.7), lid=0.0)), ("v2", dict(look=(0.9, 0.0), lid=0.28, lean=5)), ("v3", dict(look=(0.0, 0.15), lid=0.42, pupil=0.5))]
    tiles = []
    for name, kw in variants:
        reset(); materials(); studio()
        build_moss(x=-0.58, **kw)
        build_otto(x=0.62, look=(-0.7, -0.15), lid=0.34, glow=0.6, lean=-2)
        camera(target=(0.05, 0, 0.62), dist=5.9, height=1.0, lens=70, fstop=5.6)
        path = out.replace(".png", f"_{name}.png")
        render(path, arg("--w", 900), arg("--h", 560)); tiles.append(path)
    ims = [Image.open(t).convert("RGB") for t in tiles]
    w, h = ims[0].size
    sheet = Image.new("RGB", (w, h * len(ims) + 10 * (len(ims) - 1)), "#FFFFFF")
    for i, im in enumerate(ims): sheet.paste(im, (0, i * (h + 10)))
    sheet.save(out)

def ring_stacker(loc, k=1.0):
    """The Montessori ring stacker, in wood and lacquer: a base, a rod and three rings."""
    wood = mat("toywood", "#E3C08C", rough=0.45, coat=0.3)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2 * k, depth=0.06 * k, location=(loc[0], loc[1], 0.03 * k)); b = bpy.context.object; b.data.materials.append(wood); smooth(b, 2)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.025 * k, depth=0.55 * k, location=(loc[0], loc[1], 0.3 * k)); r = bpy.context.object; r.data.materials.append(wood)
    z = 0.1 * k
    for rr, c in [(0.19, "#4FA3A0"), (0.155, "#F2C14E"), (0.12, "#E0644B")]:
        bpy.ops.mesh.primitive_torus_add(major_radius=rr * k * 0.62, minor_radius=rr * k * 0.38, location=(loc[0], loc[1], z)); t = bpy.context.object
        t.scale.z = 0.8; t.data.materials.append(mat("ring" + c, c, rough=0.3, coat=0.7)); smooth(t, 1)
        z += rr * k * 0.62
    sphere("toyknob", (loc[0], loc[1], 0.6 * k), (0.045 * k, 0.045 * k, 0.045 * k), wood)

def bloom():
    s = bpy.context.scene; s.use_nodes = True
    tree = s.compositing_node_group if hasattr(s, "compositing_node_group") and s.compositing_node_group else None
    try:
        nt = s.node_tree
        rl = nt.nodes.get("Render Layers") or nt.nodes.new("CompositorNodeRLayers")
        comp = nt.nodes.get("Composite") or nt.nodes.new("CompositorNodeComposite")
        g = nt.nodes.new("CompositorNodeGlare"); g.glare_type = "FOG_GLOW"; g.threshold = 0.9; g.size = 7
        nt.links.new(rl.outputs["Image"], g.inputs["Image"]); nt.links.new(g.outputs["Image"], comp.inputs["Image"])
    except Exception as e:
        print("no bloom:", e)

def camera(target=(0.05, 0, 0.58), dist=4.4, height=0.82, lens=50, fstop=2.4):
    bpy.ops.object.camera_add(location=(0.15, -dist, height)); c = bpy.context.object
    d = Vector(target) - c.location; c.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    c.data.lens = lens; c.data.dof.use_dof = True; c.data.dof.focus_distance = d.length; c.data.dof.aperture_fstop = fstop
    bpy.context.scene.camera = c

def render(path, w, h):
    s = bpy.context.scene; s.render.resolution_x = w; s.render.resolution_y = h; s.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)

def hero(path):
    reset(); materials(); table_and_lights(night="--night" in ARGS)
    build_moss(x=-0.62, look=(0.7, 0.1), lean=4)
    build_otto(x=0.62, look=(-0.7, -0.2), lid=0.32, glow=1.0, lean=-2)
    ring_stacker((0.05, 0.9, 0), 0.9)
    bloom()
    camera()
    render(path, arg("--w", 1600), arg("--h", 1000))

if __name__ == "__main__":
    what, out = ARGS[0], ARGS[1]
    {"hero": hero, "board": board3d}[what](out)
