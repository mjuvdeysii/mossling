"""The pictures' stage, in 3D: the same soft vinyl as the figures, lit by the same lights, seen a little from above so
the floor is a real surface. One plate per area colour, rendered once and laid behind every picture of that area
(tools/scene3d.py), in place of the flat disc and ellipse the picture book drew.

  the room   a warm paper-coloured cyclorama (floor curving up into the wall), so the page has light and depth
  the stage  a thick round vinyl dais in the area's floor tint, its top exactly where the picture book's floor ellipse
             was (centre 360, GROUND + 18; 330 × 56 page px), so the figures' feet land on it
  the arch   a thick round vinyl disc standing behind the stage in the area's pale tint, where the picture book's disc
             was (centre 360, GROUND − 150; r 210), casting a soft shadow on the stage and the wall

The camera is orthographic, tilted down by the angle at which a circle of radius 330 looks 56 tall (≈ 9.8°), and set
so that the floor line of the figures' front view (GROUND) is the line on the stage at depth 0. Output:
ios/Art/stages/stage_<area>.png (1200 × 900), read by scene3d.

Usage: python3 tools/stage3d.py [--only A,B] [--size 1200]
"""
import math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv = sys.argv[:1] + ["--samples", "160"] + sys.argv[1:]
import bpy
import ip3d
from ip3d import rubber, hexcol
import picturebook as pb

OUT = os.path.join(HERE, "stages")
U = 100.0
T = math.asin(56 / 330)            # the tilt: a circle of radius 330 seen 56 tall

def arg(k, d):
    a = sys.argv
    return type(d)(a[a.index(k) + 1]) if k in a else d

def v_of(page_y): return (pb.GROUND - page_y) / U          # screen height above the floor line, in units

def disc(name, loc, r, h, mat, rot=(0, 0, 0), bevel=0.35):
    bpy.ops.mesh.primitive_cylinder_add(vertices=160, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object
    m = o.modifiers.new("b", "BEVEL"); m.width = min(r, h) * bevel; m.segments = 8; m.limit_method = "NONE"
    for p in o.data.polygons: p.use_smooth = True
    o.data.materials.append(mat); return o

def cyclorama(mat):
    """A floor that curves up into a wall: a wide plane bent with a smooth radius, far behind and below."""
    bpy.ops.mesh.primitive_plane_add(size=1, location=(3.6, 0, -0.30))
    o = bpy.context.object; o.scale = (40, 30, 1)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.subdivide(number_cuts=60); bpy.ops.object.mode_set(mode="OBJECT")
    # bend: beyond depth 4 the floor rises into a wall with a radius of 3
    for v in o.data.vertices:
        y = v.co.y
        if y > 4.0:
            a = min((y - 4.0) / 3.0, math.pi / 2)
            v.co.y = 4.0 + 3.0 * math.sin(a) if a < math.pi / 2 else 4.0 + 3.0
            v.co.z = -0.30 + 3.0 * (1 - math.cos(a)) + max(0, (y - 4.0) - 3.0 * math.pi / 2)
    for p in o.data.polygons: p.use_smooth = True
    o.data.materials.append(mat); return o

def lights(k=0.42):
    # the figures' own studio (scene3d.lights): a warm key from the upper left, a cool fill from the right, a back light
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = hexcol("#FFF6EC")
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    def area(loc, rot, e, size, col):
        bpy.ops.object.light_add(type="AREA", location=loc, rotation=rot); l = bpy.context.object
        l.data.energy = e * k; l.data.size = size; l.data.color = hexcol(col)[:3]
    area((0.5, -6, 6.5), (math.radians(45), 0, math.radians(-25)), 1700, 6, "#FFF4EA")
    area((7.5, -5, 3), (math.radians(70), 0, math.radians(45)), 900, 5, "#F4F6FF")
    area((3.6, 6, 6), (math.radians(-50), 0, math.radians(180)), 1400, 4, "#FFFFFF")

def plate(area, size):
    ground, back = pb.AREA[area]
    s = ip3d.reset()
    s.view_settings.view_transform = "Standard"; s.view_settings.look = "Medium High Contrast"; s.view_settings.exposure = -0.95
    ip3d.materials(); lights()
    cyclorama(rubber("room", "#F6EFE4", rough=0.9, sss=0.0))
    # the stage: top surface at z = 0; its centre at the depth whose line on screen is GROUND + 18
    yc = v_of(pb.GROUND + 18) / math.sin(T)
    disc("stage", (3.6, yc, -0.15), 3.3, 0.30, rubber("stage", ground, rough=0.7))
    # the arch: a thick upright disc behind the stage, centred where the picture book's disc was on screen
    yb = 2.9
    zc = (v_of(pb.GROUND - 150) - yb * math.sin(T)) / math.cos(T)
    disc("arch", (3.6, yb, zc), 2.1, 0.34, rubber("arch", pb.light(back, .35), rough=0.75), rot=(math.radians(90), 0, 0), bevel=0.4)
    # the camera: looking at the point whose screen position is the page centre
    vc = v_of(pb.H / 2)
    tgt = (pb.W / 2 / U, vc * math.sin(T), vc * math.cos(T))
    f = (0, math.cos(T), -math.sin(T))
    bpy.ops.object.camera_add(location=(tgt[0] - 30 * f[0], tgt[1] - 30 * f[1], tgt[2] - 30 * f[2]))
    c = bpy.context.object; c.rotation_euler = (math.radians(90) - T, 0, 0)
    c.data.type = "ORTHO"; c.data.ortho_scale = pb.W / U; c.data.clip_end = 100; s.camera = c
    os.makedirs(OUT, exist_ok=True)
    ip3d.render(os.path.join(OUT, f"stage_{area}.png"), size, int(size * pb.H / pb.W))

if __name__ == "__main__":
    only = arg("--only", "").split(",") if "--only" in sys.argv else list(pb.AREA)
    for a in only:
        if a: plate(a, arg("--size", 1200)); print("wrote stage", a, flush=True)
