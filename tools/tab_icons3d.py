"""The tab bar's three icons, made like the characters: matte soft vinyl, rendered in Blender under the same product
light (tools/ip3d.py), so the tab bar has the same material as Moss and Otto instead of flat glyphs.

  本月  a mint sprig — the same procedural mint leaves Moss wears, with a young pair just opening at the tip
  记录  Otto's lamp — his curved rod and the bead, lit, with a soft warm halo
  我的  Moss himself, the head and the sprig

Written as colour images (rendering intent "original": the system does not tint them) at @2x and @3x of a 30-point
box. The selected tab is shown by the system's own glass highlight. Run: python3 tools/tab_icons3d.py [preview.png]
"""
import os, sys, json, math
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.argv = sys.argv[:1] + ["--samples", "64"] + sys.argv[1:]
import bpy
import ip3d
from ip3d import M, tube, sphere, sprig, build_moss, hexcol
from PIL import Image, ImageFilter, ImageDraw

CAT = os.path.join(HERE, "..", "ios", "Mossling", "Resources", "Assets.xcassets")
PT = 30
TMP = "/tmp/tabicons"

def scene():
    s = ip3d.reset(); s.render.film_transparent = True; ip3d.materials(); ip3d.sprite_lights(); return s

def cam(cx, cz, ortho):
    t = math.radians(4)
    bpy.ops.object.camera_add(location=(cx, -8 * math.cos(t), cz + 8 * math.sin(t))); c = bpy.context.object
    c.rotation_euler = (math.radians(90) - t, 0, 0); c.data.type = "ORTHO"; c.data.ortho_scale = ortho
    bpy.context.scene.camera = c

def render(name, px):
    path = os.path.join(TMP, f"{name}@{px}.png"); ip3d.render(path, px, px); return path

def month(px):
    scene()
    parts = sprig(0.0, M["mint"], M["mint"], perk=0.7)
    # a young pair just opening above, pale and small: the month just begun
    from mathutils import Euler
    n3 = (0.0, -0.02, 0.24)
    tube("bud_stem", [(0.0, -0.02, 0.16), (0.0, -0.02, 0.25)], 0.012, M["mintDeep"])
    ip3d.leaf("budL", n3, Euler((-1.05, -math.radians(70), math.radians(150))), 0.08, M["mintPale"], width=0.6)
    ip3d.leaf("budR", n3, Euler((1.05, -math.radians(70), math.radians(30))), 0.075, M["mintPale"], width=0.6)
    tube("stem_low", [(0.0, -0.02, -0.18), (0.004, -0.022, -0.05), (0.0, -0.02, 0.0)], 0.014, M["mintDeep"])
    cam(0.0, 0.07, 0.56)
    return render("TabMonth", px)

def journal(px):
    scene()
    # Otto's rod, arching over to the left, and the lit bead hanging from it
    tube("rod", [(0.16, -0.0, -0.3), (0.16, 0.0, 0.05), (0.06, 0.0, 0.25), (-0.1, 0.0, 0.24), (-0.16, 0.0, 0.14)], 0.022, M["ottoDeep"])
    M["bead"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 0.9
    sphere("bead", (-0.16, -0.0, 0.07), (0.075, 0.075, 0.075), M["bead"])
    cam(-0.02, 0.0, 0.66)
    p = render("TabJournal", px)
    # the halo: a warm glow round the bead, under the render (the lamp is always a lamp)
    im = Image.open(p).convert("RGBA"); W = im.width
    g = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    bx, by = W * (0.5 + (-0.16 + 0.02) / 0.66), W * (0.5 - 0.07 / 0.66)
    for i in range(12, 0, -1):
        r = W * 0.022 * i
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=(255, 190, 80, int(10 + 8 * (12 - i))))
    g = g.filter(ImageFilter.GaussianBlur(W * 0.025))
    out = Image.alpha_composite(g, im); out.save(p)
    return p

def me(px):
    scene()
    build_moss(lid=0.05, look=(0.1, 0.1), er=0.13, pupil=0.56, perk=0.7)
    cam(0.0, 0.55, 1.42)
    return render("TabMe", px)

def write():
    os.makedirs(TMP, exist_ok=True)
    for name, f in (("TabMonth", month), ("TabJournal", journal), ("TabMe", me)):
        d = os.path.join(CAT, name + ".imageset")
        for old in os.listdir(d) if os.path.isdir(d) else []: os.remove(os.path.join(d, old))
        os.makedirs(d, exist_ok=True)
        src = Image.open(f(PT * 3))
        imgs = []
        for sc in (2, 3):
            fn = f"{name}@{sc}x.png"; src.resize((PT * sc, PT * sc), Image.LANCZOS).save(os.path.join(d, fn))
            imgs.append({"filename": fn, "idiom": "universal", "scale": f"{sc}x"})
        json.dump({"images": [{"idiom": "universal", "scale": "1x"}] + imgs, "info": {"author": "xcode", "version": 1},
                   "properties": {"template-rendering-intent": "original"}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)

def preview(out):
    S = Image.new("RGB", (3 * 200, 220), "#F2F2F7"); D = Image.new("RGB", (3 * 200, 220), "#1C1C1E")
    for i, n in enumerate(("TabMonth", "TabJournal", "TabMe")):
        im = Image.open(os.path.join(CAT, n + ".imageset", n + "@3x.png")).convert("RGBA").resize((160, 160), Image.LANCZOS)
        S.paste(im, (20 + i * 200, 30), im); D.paste(im, (20 + i * 200, 30), im)
    P = Image.new("RGB", (600, 440)); P.paste(S, (0, 0)); P.paste(D, (0, 220)); P.save(out)

if __name__ == "__main__":
    write()
    if len(sys.argv) > 3: preview(sys.argv[3])
