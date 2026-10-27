"""The growth map's stage, in the characters' material: a soft vinyl meadow — rolling hills, a few puffy clouds, the
sun (or the moon and stars at night) — rendered in Blender as a backdrop plate the app lays behind the child and the
companions (Sky in the app is the fallback). Output: ios/Art/art/stage_day.webp, stage_night.webp.

Usage: python3 tools/plates3d.py
"""
import math, os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv = sys.argv[:1] + ["--samples", "32"] + sys.argv[1:]
import bpy
import ip3d
from ip3d import sphere, rubber, mat, hexcol
from PIL import Image

ART = os.path.join(HERE, "..", "ios", "Art", "art")
W, H = 1200, 600

def emit(name, col, s):
    return mat(name, col, rough=0.5, emit=col, emit_strength=s)

def plate(night, out):
    s = ip3d.reset(); s.view_settings.view_transform = "Standard"; s.view_settings.look = "None"; s.view_settings.exposure = -0.4 if not night else -0.2
    ip3d.materials()
    w = bpy.data.worlds.new("w"); s.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = hexcol("#1E2A52" if night else "#FFF4E2")
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    # the sky: a backdrop with a vertical gradient (an emission so the light does not change it)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 6, 1.6)); sky = bpy.context.object
    sky.scale = (16, 8, 1); sky.rotation_euler = (math.radians(90), 0, 0)
    m = bpy.data.materials.new("sky"); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out_n = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission"); ramp = nt.nodes.new("ShaderNodeValToRGB")
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Y"], ramp.inputs[0])
    top, low = ("#1A2350", "#3C3E78") if night else ("#9ED3F0", "#E8F5FB")
    ramp.color_ramp.elements[0].color = hexcol(low); ramp.color_ramp.elements[1].color = hexcol(top)
    nt.links.new(ramp.outputs[0], em.inputs["Color"]); em.inputs["Strength"].default_value = 1.0 if night else 1.25   # the exposure is lowered for the lit hills
    nt.links.new(em.outputs[0], out_n.inputs["Surface"]); sky.data.materials.append(m)
    # the hills: big soft vinyl mounds, the far ones paler
    for x, y, r, h, col in ((-4.2, 4, 3.6, 1.4, "#A9D59A"), (2.6, 4.2, 4.2, 1.6, "#B7DDA6"), (-1.2, 2.5, 4.6, 1.25, "#8CC97C"), (4.4, 2.2, 3.2, 1.1, "#93CD84"), (0, 0.9, 7, 0.75, "#7DBE6E")):
        c = col if not night else "#2E4A4A"
        o = sphere("hill", (x, y, -h * 0.35), (r, r * 0.7, h), rubber("h" + c + str(x), c, rough=0.75), seg=64)
    # little grass tufts and flowers on the front hill
    for x, col in ((-3.2, "#FF8FAA"), (-2.6, "#FFC23D"), (3.0, "#FFFFFF"), (3.7, "#9B7BEA")):
        if night: break
        sphere("fl", (x, 0.2, 0.46), (0.07, 0.07, 0.07), rubber("f" + col, col), seg=24)
    if not night:
        # the sun, top right, and three clouds
        sphere("sun", (4.3, 4.5, 3.1), (0.75, 0.75, 0.75), emit("sun", "#FFD45C", 3.0))
        for cx, cz, k in ((-3.8, 2.9, 1.0), (-0.6, 3.3, 0.75), (2.4, 2.4, 0.6)):
            for dx, dz, r in ((-0.45, 0, 0.38), (0, 0.18, 0.5), (0.48, 0.02, 0.4), (0.15, -0.12, 0.42)):
                sphere("cloud", (cx + dx * k, 4.6, cz + dz * k), (r * k, r * k * 0.7, r * k * 0.85), rubber("cloud", "#FFFFFF", rough=0.8), seg=32)
        # one soft sun from the top right, and the sky's own light
        bpy.ops.object.light_add(type="SUN", location=(0, 0, 10)); sl = bpy.context.object
        sl.data.energy = 3.2; sl.data.angle = math.radians(25); sl.data.color = hexcol("#FFF3E0")[:3]
        sl.rotation_euler = (math.radians(50), math.radians(-25), math.radians(20))
        w.node_tree.nodes["Background"].inputs["Color"].default_value = hexcol("#DCEBFF"); w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.2
    else:
        sphere("moon", (4.0, 4.5, 3.0), (0.55, 0.55, 0.55), emit("moon", "#FFE9A8", 2.0))
        sphere("moonbite", (4.25, 4.2, 3.15), (0.5, 0.5, 0.5), mat("bite", "#1A2350", rough=1.0, emit="#1A2350", emit_strength=1.0))
        import random; random.seed(3)
        for i in range(26):
            sphere("star", (random.uniform(-6, 6), 5.5, random.uniform(2.0, 4.6)), (0.04,) * 3, emit("star", "#FFF4D0", 4.0), seg=12)
        bpy.ops.object.light_add(type="AREA", location=(0, -4, 4)); l = bpy.context.object; l.data.energy = 1100; l.data.size = 8; l.data.color = hexcol("#9FB4FF")[:3]
        l.rotation_euler = (math.radians(45), 0, 0)
    bpy.ops.object.camera_add(location=(0, -12, 1.6)); c = bpy.context.object
    c.rotation_euler = (math.radians(90), 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = 12; s.camera = c
    p = f"/tmp/{out}.png"; ip3d.render(p, W, H)
    Image.open(p).convert("RGB").save(os.path.join(ART, out + ".webp"), "WEBP", quality=90, method=6)
    ipath = os.path.join(ART, "index.json"); index = json.load(open(ipath)); index["size"][out + ".webp"] = [W, H]
    json.dump(index, open(ipath, "w"), separators=(",", ":"))

def rbox(name, c, size, col, bevel=0.3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c); b = bpy.context.object; b.name = name
    b.scale = size
    m = b.modifiers.new("b", "BEVEL"); m.width = min(size) * bevel; m.segments = 5; m.limit_method = "NONE"
    for poly in b.data.polygons: poly.use_smooth = True
    b.data.materials.append(col if not isinstance(col, str) else rubber(name + col, col)); return b

def rod(name, a, b, r, col):
    return ip3d.tube(name, [a, tuple((x + y) / 2 for x, y in zip(a, b)), b], r, col if not isinstance(col, str) else rubber(name + col, col))

def room(out="stage_room"):
    """Night on the growth map: not the child under the stars but the child asleep at home — a crib under a blanket
    in a dim room, moonlight through the window. Not black: the moon lights the room in a soft blue, enough to see
    the crib, the curtains and a toy on the rug. Room is left at the bottom right for the companions (Otto's lamp,
    lit for a few seconds in the app, is drawn there by the app)."""
    s = ip3d.reset(); s.view_settings.view_transform = "Standard"; s.view_settings.look = "None"; s.view_settings.exposure = -0.55
    ip3d.materials()
    w = bpy.data.worlds.new("w"); s.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = hexcol("#4F5585")
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
    # the room: a back wall, a lower panel, the floor and a rug
    rbox("wall", (0, 3.2, 2.5), (16, 0.2, 7), "#535A88", 0.02)
    rbox("panel", (0, 3.0, 0.55), (16, 0.12, 1.1), "#474D78", 0.05)
    rbox("rail", (0, 2.92, 1.12), (16, 0.12, 0.08), "#727799", 0.3)
    rbox("floor", (0, -3, -0.1), (16, 13, 0.2), "#665670", 0.02)
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=1, depth=0.04, location=(-0.2, 0.2, 0.02)); rug = bpy.context.object
    rug.scale = (3.2, 1.4, 1); rug.data.materials.append(rubber("rug", "#8C7AAE", rough=0.9))
    # the window, upper right: a cream frame, the night sky in it with the moon and a few stars, soft curtains
    wx, wz, ww, wh = 2.7, 2.75, 1.9, 1.9
    sky = mat("winsky", "#000000", rough=1.0, emit="#24316B", emit_strength=1.0)
    rbox("pane", (wx, 3.08, wz), (ww, 0.04, wh), sky, 0.01)
    sphere("moon", (wx + 0.42, 3.0, wz + 0.5), (0.32, 0.05, 0.32), mat("moonm", "#FFE9A8", rough=0.5, emit="#FFE9A8", emit_strength=2.2))
    sphere("bite", (wx + 0.56, 2.97, wz + 0.6), (0.29, 0.05, 0.29), sky)
    import random; random.seed(5)
    for i in range(9):
        sphere("star", (wx + random.uniform(-0.85, 0.85), 3.02, wz + random.uniform(-0.95, 0.95)), (0.03, 0.02, 0.03), mat("st", "#FFF4D0", emit="#FFF4D0", emit_strength=4.0), seg=12)
    frame = "#EDE3D3"
    for dz in (-wh / 2, wh / 2): rbox("fr", (wx, 3.0, wz + dz), (ww + 0.24, 0.16, 0.14), frame)
    for dx in (-ww / 2, 0, ww / 2): rbox("fr", (wx + dx, 3.0, wz), (0.12 if dx else 0.07, 0.14, wh + 0.1), frame)
    rbox("fr", (wx, 3.0, wz), (ww, 0.12, 0.07), frame)
    rbox("sill", (wx, 2.86, wz - wh / 2 - 0.1), (ww + 0.5, 0.36, 0.1), frame)
    cur = rubber("curtain", "#C49AC4", rough=0.85)
    for side in (-1, 1):
        for k in range(3):
            bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.14, depth=wh + 0.5, location=(wx + side * (ww / 2 + 0.12 + k * 0.17), 2.82, wz + 0.1))
            c = bpy.context.object; c.scale.x = 1.0; c.data.materials.append(cur)
            for poly in c.data.polygons: poly.use_smooth = True
    rod("crod", (wx - ww / 2 - 0.8, 2.8, wz + wh / 2 + 0.32), (wx + ww / 2 + 0.8, 2.8, wz + wh / 2 + 0.32), 0.03, "#C9A27A")
    # the crib, left of centre: light wood, a white mattress, a pillow, a blanket over the sleeping child
    cx, cy = -0.6, 1.0
    wood = mat("cribwood", "#E9CDA6", rough=0.45, coat=0.25)
    L, D, top, bot = 3.0, 1.4, 1.95, 0.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.07, depth=top + 0.12, location=(cx + sx * L / 2, cy + sy * D / 2, (top + 0.12) / 2))
            o = bpy.context.object; o.data.materials.append(wood); [setattr(p, "use_smooth", True) for p in o.data.polygons]
            sphere("knob", (cx + sx * L / 2, cy + sy * D / 2, top + 0.14), (0.09, 0.09, 0.09), wood)
    for sy in (-1, 1):
        for z in (bot, top): rod("rail", (cx - L / 2, cy + sy * D / 2, z), (cx + L / 2, cy + sy * D / 2, z), 0.045, wood)
        n = 11
        for i in range(1, n):
            x = cx - L / 2 + L * i / n
            rod("bar", (x, cy + sy * D / 2, bot), (x, cy + sy * D / 2, top), 0.028, wood)
    for sx in (-1, 1):
        rbox("end", (cx + sx * L / 2, cy, (bot + top) / 2 + 0.1), (0.08, D, top - bot + 0.1), wood, 0.2)
    rbox("mattress", (cx, cy, bot + 0.16), (L - 0.1, D - 0.1, 0.3), "#F3ECE1", 0.35)
    rbox("pillow", (cx - 0.95, cy + 0.05, bot + 0.42), (0.75, 0.75, 0.2), "#FBF5EC", 0.5)
    blanket = rubber("blanket", "#F2C77A", rough=0.8)
    rbox("blanket", (cx + 0.35, cy - 0.02, bot + 0.38), (1.9, D - 0.2, 0.22), blanket, 0.5)
    sphere("body", (cx + 0.25, cy - 0.05, bot + 0.5), (0.75, 0.45, 0.2), blanket)
    for i in range(4):   # dots on the blanket
        sphere("dot", (cx - 0.3 + i * 0.45, cy - 0.66, bot + 0.42 + (i % 2) * 0.04), (0.06, 0.02, 0.06), rubber("dotc", "#FFFFFF"), seg=16)
    # the child is Moss: asleep on the pillow under the blanket, eyes shut, the mint sprig on the pillow
    ip3d.materials()
    moss = ip3d.build_moss(shut="down", perk=0.0)
    for o in list(moss.children):
        if o.name.startswith("moss_foot"): bpy.data.objects.remove(o, do_unlink=True)
    moss.scale = (0.62, 0.62, 0.62); moss.rotation_euler = (0, math.radians(-14), 0)
    moss.location = (cx - 0.95, cy - 0.12, bot + 0.36)
    # a soft toy beside the crib on the rug, and a ring stacker
    ip3d.ring_stacker((-3.2, -0.2), 1.3)
    # a mobile over the crib: a moon and two stars on threads
    for x, z, shape in ((cx - 0.5, 2.75, "moon"), (cx + 0.1, 2.95, "star"), (cx + 0.7, 2.7, "star")):
        rod("thread", (x, cy, 3.5), (x, cy, z + 0.12), 0.006, "#E9E2D6")
        sphere("mob", (x, cy, z), (0.12, 0.05, 0.12), rubber("mob" + shape, "#FFD36B" if shape == "star" else "#F3ECE1"), seg=24)
    rod("mobarm", (cx - 0.6, cy, 3.5), (cx + 0.8, cy, 3.5), 0.015, "#C9A27A")
    # light: the moon through the window (cool, soft), a little sky fill; nothing warm (the lamp is the app's)
    bpy.ops.object.light_add(type="AREA", location=(wx + 1.5, -1.0, 4.6)); l = bpy.context.object
    l.data.energy = 1500; l.data.size = 5; l.data.color = hexcol("#B9C6FF")[:3]
    l.rotation_euler = (math.radians(55), math.radians(18), math.radians(25))
    bpy.ops.object.light_add(type="AREA", location=(-3, -6, 3)); f = bpy.context.object
    f.data.energy = 500; f.data.size = 8; f.data.color = hexcol("#8E9BE0")[:3]; f.rotation_euler = (math.radians(75), 0, math.radians(-20))
    bpy.ops.object.camera_add(location=(0, -12, 3.6)); c = bpy.context.object
    c.rotation_euler = (math.radians(81), 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = 11; s.camera = c
    p = f"/tmp/{out}.png"; ip3d.render(p, W, H)
    Image.open(p).convert("RGB").save(os.path.join(ART, out + ".webp"), "WEBP", quality=90, method=6)
    ipath = os.path.join(ART, "index.json"); index = json.load(open(ipath)); index["size"][out + ".webp"] = [W, H]
    json.dump(index, open(ipath, "w"), separators=(",", ":"))

if __name__ == "__main__":
    if "--room" in sys.argv: room(); sys.exit()
    plate(False, "stage_day"); plate(True, "stage_night")
