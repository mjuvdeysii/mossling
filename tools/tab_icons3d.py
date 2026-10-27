"""The tab bar's three icons, in the same matte soft vinyl and the same calibrated product light as the app's icons
(tools/icons3d.py), so the bar reads as one family with the stickers on the pages. Each is a single plump object with
a clear silhouette at 30 points, a fine white edge (like Moss and Otto's sprites) so it holds on the glass in light and
dark, and a soft contact shadow.

  本月  a sprout of two round leaves in a little clay pot — this month's growing
  记录  a clipboard with three coloured entries — the notes
  我的  Moss, the head and the sprig

Each is written twice: TabX (not selected: the colour quietened, so the chosen tab leads) and TabXOn (selected: full
colour). Rendering intent "original". Run: python3 tools/tab_icons3d.py [preview.png]
"""
import os, sys, json, math
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv = sys.argv[:1] + ["--samples", "64"] + sys.argv[1:]
import bpy
import ip3d
import icons3d as I
from PIL import Image, ImageFilter, ImageEnhance, ImageChops

CAT = os.path.join(HERE, "..", "ios", "Mossling", "Resources", "Assets.xcassets")
PT = 30
TMP = "/tmp/tabicons"
PX = 360

def scene():
    s = ip3d.reset(); s.render.film_transparent = True
    s.view_settings.view_transform = "Standard"; s.view_settings.look = "None"
    ip3d.materials(); I.MATS.clear(); I.icon_lights()
    return s

def shoot(s, name, cz, ortho, tilt=14):
    for m in bpy.data.materials:
        if m.use_nodes and "Principled BSDF" in m.node_tree.nodes:
            p = m.node_tree.nodes["Principled BSDF"]
            if p.inputs["Emission Strength"].default_value == 0 and p.inputs["Coat Weight"].default_value < 0.3:
                p.inputs["Specular IOR Level"].default_value = 0.08
    s.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.26
    s.view_settings.exposure = -1.1
    t = math.radians(tilt)
    bpy.ops.object.camera_add(location=(0, -8 * math.cos(t), cz + 8 * math.sin(t))); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = ortho; s.camera = c
    p = os.path.join(TMP, name + ".png"); ip3d.render(p, PX, PX); return p

def month():
    s = scene()
    I.cyl((0, 0, 0.17), 0.3, 0.34, "#E2875A", r2=0.24, bevel=0.3, verts=64)        # the pot, a little tapered
    I.cyl((0, 0, 0.36), 0.33, 0.08, "#EC9A6C", bevel=0.45, verts=64)              # its rim
    I.cyl((0, 0, 0.395), 0.28, 0.02, "#6B4A35", verts=48)                          # the soil
    I.cap((0, 0, 0.38), (0.0, 0, 0.78), 0.035, "#3E9B5A")                          # the stem
    for sx in (-1, 1):                                                             # two round leaves
        l = I.sph((sx * 0.2, 0, 0.8 + (0.03 if sx > 0 else 0)), (0.22, 0.07, 0.13), "#4DB86A" if sx < 0 else "#6FCB86")
        l.rotation_euler = (0, math.radians(-24 * sx), 0)
    I.sph((0, -0.02, 0.86), (0.05, 0.04, 0.07), "#8EDBA4")                         # the new bud between them
    return shoot(s, "TabMonth", 0.5, 1.24)

def journal():
    s = scene()
    I.rbox((0, 0, 0.55), (0.78, 0.1, 1.0), "#C9894E", 0.25)                        # the board
    I.rbox((0, -0.06, 0.5), (0.62, 0.02, 0.8), "#FFF6E6", 0.15)                    # the paper
    I.rbox((0, -0.08, 1.04), (0.34, 0.08, 0.14), "#9A9289", 0.4)                   # the clip
    for i, col in enumerate(("#FF6F91", "#4C9BE8", "#FFC23D")):                    # three entries
        z = 0.76 - i * 0.22
        I.sph((-0.17, -0.09, z), (0.055, 0.03, 0.055), col)
        I.rbox((0.08, -0.08, z), (0.3 - i * 0.05, 0.015, 0.035), "#C9C0B4", 0.4)
    # turned a little toward the light and leaning back, so it reads as an object, not a flat card
    root = bpy.data.objects.new("root", None); bpy.context.collection.objects.link(root)
    for o in list(bpy.context.scene.objects):
        if o.type in ("MESH", "CURVE"): o.parent = root
    root.rotation_euler = (math.radians(-10), 0, math.radians(-16))
    return shoot(s, "TabJournal", 0.55, 1.36)

def me():
    s = scene()
    ip3d.build_moss(lid=0.05, look=(0.1, 0.1), er=0.13, pupil=0.56, perk=0.7)
    return shoot(s, "TabMe", 0.5, 1.68)

def finish(path, quiet):
    """The fine white edge and a soft contact shadow (as the sprites have), on a square with room for both; the
    unselected version quietened (less colour, a touch lighter)."""
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A")
    if quiet:
        rgb = ImageEnhance.Color(im.convert("RGB")).enhance(0.35)
        rgb = Image.blend(rgb, Image.new("RGB", im.size, (236, 232, 226)), 0.18)
        im = rgb.convert("RGBA"); im.putalpha(a)
    k = max(3, int(PX * 0.018)) | 1
    edge = a.filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.GaussianBlur(0.8))
    white = Image.new("RGBA", im.size, (255, 255, 255, 0)); white.putalpha(edge)
    sh = Image.new("RGBA", im.size, (60, 40, 25, 0)); sh.putalpha(edge.point(lambda v: int(v * 0.22)))
    sh = ImageChops.offset(sh, 0, int(PX * 0.02)).filter(ImageFilter.GaussianBlur(PX * 0.02))
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.alpha_composite(sh); out.alpha_composite(white); out.alpha_composite(im)
    return out

def write():
    os.makedirs(TMP, exist_ok=True)
    for name, f in (("TabMonth", month), ("TabJournal", journal), ("TabMe", me)):
        src = f()
        for suffix, quiet in (("", True), ("On", False)):
            n = name + suffix
            d = os.path.join(CAT, n + ".imageset")
            for old in os.listdir(d) if os.path.isdir(d) else []: os.remove(os.path.join(d, old))
            os.makedirs(d, exist_ok=True)
            im = finish(src, quiet)
            imgs = []
            for sc in (2, 3):
                fn = f"{n}@{sc}x.png"; im.resize((PT * sc, PT * sc), Image.LANCZOS).save(os.path.join(d, fn))
                imgs.append({"filename": fn, "idiom": "universal", "scale": f"{sc}x"})
            json.dump({"images": [{"idiom": "universal", "scale": "1x"}] + imgs, "info": {"author": "xcode", "version": 1},
                       "properties": {"template-rendering-intent": "original"}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)
            print("wrote", n, flush=True)

def preview(out):
    rows = []
    for bg in ("#F2F2F7", "#1C1C1E"):
        R = Image.new("RGB", (6 * 130, 140), bg)
        for i, n in enumerate(("TabMonthOn", "TabMonth", "TabJournalOn", "TabJournal", "TabMeOn", "TabMe")):
            im = Image.open(os.path.join(CAT, n + ".imageset", n + "@3x.png")).convert("RGBA")
            R.paste(im, (20 + i * 130, 25), im)
        rows.append(R)
    P = Image.new("RGB", (780, 280)); P.paste(rows[0], (0, 0)); P.paste(rows[1], (0, 140)); P.save(out)

if __name__ == "__main__":
    write()
    if sys.argv[-1].endswith(".png"): preview(sys.argv[-1])
