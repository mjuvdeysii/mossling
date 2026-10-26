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

if __name__ == "__main__":
    plate(False, "stage_day"); plate(True, "stage_night")
