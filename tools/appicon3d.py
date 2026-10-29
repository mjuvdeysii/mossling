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
FILL = 0.84   # the pair's larger side as a share of the icon (Apple's grid keeps the subject inside about 0.8)

def scene():
    s = ip3d.reset(); s.render.film_transparent = True
    s.view_settings.view_transform = "Standard"; s.view_settings.look = "Medium High Contrast"; s.view_settings.exposure = -0.7
    ip3d.materials(); ip3d.sprite_lights()
    # Moss: the main one, a little in front of the middle; Otto at his side (centres 1.12 apart: Moss reaches 0.57,
    # Otto 0.42 at this scale, so a clear gap between them)
    m = build_moss(lid=0.0, er=0.13, pupil=0.5, perk=1.0, look=(0.55, 0.35))
    m.location = (-0.5, 0.0, 0.0); m.rotation_euler = (0, 0, math.radians(14))
    o = build_otto(lid=0.42, look=(-0.7, -0.25), slouch=0.4, droop=0.0, bags=True, glow=0.0)
    # Otto leans toward Moss, as he always does (10–15°, the character bible), the lamp reaching over him
    o.location = (0.74, 0.35, 0.0); o.rotation_euler = (0, math.radians(-9), math.radians(-12))   # true scale: the grown-up is much taller
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
    ip3d.render(path, 2 * PX, 2 * PX)
    # where the bead lands in the picture, for the glow
    from bpy_extras.object_utils import world_to_camera_view
    v = world_to_camera_view(s, c, bead)
    return (v.x * 2 * PX, (1 - v.y) * 2 * PX)

def main():
    tmp = "/tmp/appicon_fg.png"
    bx, by = shoot(tmp)
    fg = Image.open(tmp).convert("RGBA")
    # fitted, not framed by the camera: the pair (bead and rod included) fills a fixed share of the square, centred a
    # touch below the middle (the eye weighs the heavier bodies low), so it reads at home-screen size (60 pt)
    box = fg.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    fg = fg.crop(box)
    k = FILL * PX / max(fg.width, fg.height)
    fg = fg.resize((round(fg.width * k), round(fg.height * k)), Image.LANCZOS)
    c = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
    c.alpha_composite(fg, ((PX - fg.width) // 2, (PX - fg.height) // 2 + round(PX * 0.02)))
    fg = c
    # the lamp's halo: a warm glow round the bead, under the figures
    g = Image.new("RGBA", fg.size, (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    for i in range(0):   # the lamp is lit only at night: no halo on the icon
        pass
    g = g.filter(ImageFilter.GaussianBlur(28)); g.alpha_composite(fg)
    assets = os.path.join(ICON, "Assets")
    for f in os.listdir(assets): os.remove(os.path.join(assets, f))
    g.save(os.path.join(assets, "duo.png"))
    finish()
    preview(g)

def finish():
    """The layers made from the rendered pair, and the icon's description. By night (the dark icon) Otto's lamp is lit:
    a warm glow round the bead, under the pair. Tinted (the system's one-colour icons), the pair in light tones: the
    system tints by lightness, and the dark blue Otto disappeared into the tinted dark."""
    from PIL import ImageOps, ImageChops
    import numpy as np
    assets = os.path.join(ICON, "Assets")
    g = Image.open(os.path.join(assets, "duo.png")).convert("RGBA")
    a = np.asarray(g).astype(int)
    bead = (a[..., 3] > 200) & (a[..., 0] > 200) & (a[..., 1] > 120) & (a[..., 1] < 200) & (a[..., 2] < 80)
    ys, xs = np.nonzero(bead); bx, by = float(xs.mean()), float(ys.mean())
    # the lamp's glow: a soft warm light round the bead and a pool falling below it
    # (drawn as a mask and blurred alone, then given the lamp's colour: blurring coloured shapes on a clear ground pulls
    # the clear ground's black into the soft edge and dims the light to brown)
    glow = Image.new("L", g.size, 0); d = ImageDraw.Draw(glow)
    for r, al in ((210, 40), (140, 70), (80, 120), (40, 190)):
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=al)
    # and the circle of light it throws over Moss (the bright state: the light holds Moss), on the table round his feet
    green = (a[..., 3] > 200) & (a[..., 1] > a[..., 0] + 12) & (a[..., 1] > a[..., 2] + 12)
    gy, gx = np.nonzero(green)
    mx, mw, mb = float(gx.mean()), float(gx.max() - gx.min()), float(np.percentile(gy, 99.5))
    for k, al in ((1.0, 55), (0.7, 70)):
        rx, ry = mw * 0.85 * k, mw * 0.16 * k
        d.ellipse((mx - rx, mb - ry, mx + rx, mb + ry), fill=al)
    mask = glow.filter(ImageFilter.GaussianBlur(46))
    glow = Image.new("RGBA", g.size, (255, 194, 108, 255)); glow.putalpha(mask)
    glow.save(os.path.join(assets, "glow.png"))
    # the low table they stand on (their world): a soft warm band of shade along the feet line, by day and by night
    feet = float(np.percentile(np.nonzero(a[..., 3] > 200)[0], 99.6))
    tm = Image.new("L", g.size, 0); dt = ImageDraw.Draw(tm)
    dt.ellipse((g.width * 0.04, feet - g.height * 0.05, g.width * 0.96, feet + g.height * 0.07), fill=46)
    table = Image.new("RGBA", g.size, (122, 82, 48, 255)); table.putalpha(tm.filter(ImageFilter.GaussianBlur(26)))
    table.save(os.path.join(assets, "table.png"))
    # by day (the light icon): the window's light falling from the upper left onto Moss, behind the pair — day is Moss's
    # time as night is Otto's, so the light that holds him by night with the lamp holds him by day from the window
    # (drawn as a mask and blurred alone, so the light stays the light's colour at its soft edge, never greyed)
    mask = Image.new("L", g.size, 0); dd = ImageDraw.Draw(mask)
    top = float(np.percentile(gy, 1))
    for k, al in ((1.0, 80), (0.6, 120)):
        rx, ry = mw * 0.9 * k, (mb - top) * 0.8 * k
        cx, cy = mx - mw * 0.08, top + (mb - top) * 0.5
        dd.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=al)
    mask = mask.filter(ImageFilter.GaussianBlur(70))
    day = Image.new("RGBA", g.size, (255, 251, 240, 255)); day.putalpha(mask)
    day.save(os.path.join(assets, "day.png"))
    # the pair for tinting: its own shading kept, lifted into the light half
    lum = ImageOps.grayscale(g.convert("RGB"))
    lum = lum.point(lambda v: int(60 + 195 * (v / 255) ** 0.35))   # bodies light (the tinted dark dims them), eyes still darker
    tint = Image.merge("RGBA", (lum, lum, lum, g.getchannel("A")))
    tint.save(os.path.join(assets, "duo_tint.png"))
    pos = {"scale": 1, "translation-in-points": [0, 0]}
    spec = {
        "fill-specializations": [
            {"value": {"linear-gradient": ["display-p3:1.00000,0.96500,0.90500,1.00000", "display-p3:0.98000,0.86500,0.72000,1.00000"]}},
            {"appearance": "dark", "value": {"linear-gradient": ["display-p3:0.29000,0.20500,0.14500,1.00000", "display-p3:0.13000,0.09000,0.06000,1.00000"]}},
        ],
        "groups": [{
            # first is front: the pair (or its tinting version), then the lamp's glow behind it at night
            "layers": [
                {"image-name": "duo.png", "name": "Moss and Otto", "glass": False, "position": pos,
                 "hidden-specializations": [{"value": False}, {"appearance": "tinted", "value": True}]},
                {"image-name": "duo_tint.png", "name": "Moss and Otto (tinted)", "glass": False, "position": pos,
                 "hidden-specializations": [{"value": True}, {"appearance": "tinted", "value": False}]},
                {"image-name": "glow.png", "name": "The lamp lit", "glass": False, "position": pos,
                 "hidden-specializations": [{"value": True}, {"appearance": "dark", "value": False}]},
                {"image-name": "day.png", "name": "The window light", "glass": False, "position": pos,
                 "hidden-specializations": [{"value": False}, {"appearance": "dark", "value": True}, {"appearance": "tinted", "value": True}]},
                {"image-name": "table.png", "name": "The table", "glass": False, "position": pos,
                 "hidden-specializations": [{"value": False}, {"appearance": "tinted", "value": True}]},
            ],
            "lighting": "individual", "specular": False,
            "shadow": {"kind": "layer-color", "opacity": 0.4},   # a shadow in the figures' own colour, softer and warmer than grey
            "translucency": {"enabled": False, "value": 0.5},
        }],
        "supported-platforms": {"squares": ["iOS"]},
    }
    json.dump(spec, open(os.path.join(ICON, "icon.json"), "w"), indent=2)

def preview(g):
    if len(sys.argv) > 3:
        out = sys.argv[3]; P = Image.new("RGB", (2 * 560, 560), "white")
        for i, (a, b) in enumerate((((255, 246, 231), (250, 221, 184)), ((74, 52, 37), (33, 23, 15)))):
            bg = Image.new("RGB", (PX, PX)); dd = ImageDraw.Draw(bg)
            for y in range(PX):
                t_ = y / PX; dd.line((0, y, PX, y), fill=tuple(int(a[k] + (b[k] - a[k]) * t_) for k in range(3)))
            bg.paste(g, (0, 0), g)
            m = Image.new("L", (PX, PX), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, PX, PX), radius=230, fill=255)
            P.paste(bg.resize((520, 520), Image.LANCZOS), (20 + i * 560, 20), m.resize((520, 520)))
        # and as it is met: on the home screen (60 pt at 2x and 3x), and in Settings and Spotlight (29 pt / 40 pt)
        Q = Image.new("RGB", (P.width, P.height + 220), "white"); Q.paste(P, (0, 0))
        x = 20
        for i in range(2):
            big = P.crop((20 + i * 560, 20, 540 + i * 560, 540))
            for sz in (180, 120, 80, 58):
                Q.paste(big.resize((sz, sz), Image.LANCZOS), (x, P.height + (200 - sz) // 2)); x += sz + 16
        Q.save(out)

if __name__ == "__main__":
    finish() if "--finish" in sys.argv else main()
