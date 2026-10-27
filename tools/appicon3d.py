"""The app icon in the characters' own material: Moss in front (round, the mint sprig up, wide awake) and Otto beside
him — never one in front of the other — his lamp lit, the bead's warm light falling on Moss. Matte soft vinyl under
the characters' product light (tools/ip3d.py), rendered on a transparent ground as the foreground layer of the Icon
Composer icon (ios/Mossling/Resources/AppIcon.icon), whose own fill gives the warm paper (light) or the night (dark).

Usage: python3 tools/appicon3d.py [preview.png]
"""
import math, os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv = sys.argv[:1] + ["--samples", "128"] + sys.argv[1:]
import bpy
import ip3d
from ip3d import build_moss, build_otto, hexcol
from PIL import Image, ImageDraw, ImageFilter

ICON = os.path.join(HERE, "..", "ios", "Mossling", "Resources", "AppIcon.icon")
PX = 1024

def scene():
    s = ip3d.reset(); s.render.film_transparent = True
    s.view_settings.view_transform = "Standard"; s.view_settings.look = "Medium High Contrast"; s.view_settings.exposure = -0.7
    ip3d.materials(); ip3d.sprite_lights()
    # Moss: the main one, a little in front of the middle; Otto at his side (centres 1.12 apart: Moss reaches 0.57,
    # Otto 0.42 at this scale, so a clear gap between them)
    m = build_moss(lid=0.0, er=0.13, pupil=0.5, perk=1.0, look=(0.55, 0.35))
    m.location = (-0.58, 0.0, 0.0); m.rotation_euler = (0, 0, math.radians(14))
    o = build_otto(lid=0.42, look=(-0.7, -0.25), slouch=0.4, droop=0.0, bags=True, glow=0.0)
    o.location = (0.74, 0.35, 0.0); o.rotation_euler = (0, 0, math.radians(-12))   # true scale: the grown-up is much taller
    bpy.context.view_layer.update()
    bead = bpy.data.objects["otto_bead"].matrix_world.translation
    # a rim of light from behind and above, so both read against the night fill as well as the day one
    bpy.ops.object.light_add(type="AREA", location=(0.3, 3.0, 2.6)); r = bpy.context.object
    r.data.energy = 260; r.data.size = 3.0; r.data.color = hexcol("#FFE2B8")[:3]
    r.rotation_euler = (math.radians(-130), 0, 0)
    return s, bead

def shoot(path):
    s, bead = scene()
    t = math.radians(6)
    bpy.ops.object.camera_add(location=(0.08, -10 * math.cos(t), 1.08 + 10 * math.sin(t))); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = 2.95; s.camera = c
    ip3d.render(path, PX, PX)
    # where the bead lands in the picture, for the glow
    from bpy_extras.object_utils import world_to_camera_view
    v = world_to_camera_view(s, c, bead)
    return (v.x * PX, (1 - v.y) * PX)

def main():
    tmp = "/tmp/appicon_fg.png"
    bx, by = shoot(tmp)
    fg = Image.open(tmp).convert("RGBA")
    # the lamp's halo: a warm glow round the bead, under the figures
    g = Image.new("RGBA", fg.size, (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    for i in range(0):   # the lamp is lit only at night: no halo on the icon
        pass
    g = g.filter(ImageFilter.GaussianBlur(28)); g.alpha_composite(fg)
    assets = os.path.join(ICON, "Assets")
    for f in os.listdir(assets): os.remove(os.path.join(assets, f))
    g.save(os.path.join(assets, "duo.png"))
    spec = {
        "fill-specializations": [
            {"value": {"linear-gradient": ["display-p3:1.00000,0.96500,0.90500,1.00000", "display-p3:0.98000,0.86500,0.72000,1.00000"]}},
            {"appearance": "dark", "value": {"linear-gradient": ["display-p3:0.16000,0.18500,0.32000,1.00000", "display-p3:0.08500,0.09500,0.18000,1.00000"]}},
        ],
        "groups": [{
            "layers": [{"image-name": "duo.png", "name": "Moss and Otto", "glass": False, "hidden": False,
                        "position": {"scale": 1, "translation-in-points": [0, 0]}}],
            "lighting": "individual", "specular": False,
            "shadow": {"kind": "neutral", "opacity": 0.3},
            "translucency": {"enabled": False, "value": 0.5},
        }],
        "supported-platforms": {"squares": ["iOS"]},
    }
    json.dump(spec, open(os.path.join(ICON, "icon.json"), "w"), indent=2)
    if len(sys.argv) > 3:
        out = sys.argv[3]; P = Image.new("RGB", (2 * 560, 560), "white")
        for i, (a, b) in enumerate((((255, 246, 231), (250, 221, 184)), ((41, 47, 82), (22, 24, 46)))):
            bg = Image.new("RGB", (PX, PX)); dd = ImageDraw.Draw(bg)
            for y in range(PX):
                t_ = y / PX; dd.line((0, y, PX, y), fill=tuple(int(a[k] + (b[k] - a[k]) * t_) for k in range(3)))
            bg.paste(g, (0, 0), g)
            m = Image.new("L", (PX, PX), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, PX, PX), radius=230, fill=255)
            P.paste(bg.resize((520, 520), Image.LANCZOS), (20 + i * 560, 20), m.resize((520, 520)))
        P.save(out)

if __name__ == "__main__":
    main()
