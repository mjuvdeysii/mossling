"""The tab bar's three icons, drawn for this app instead of generic SF Symbols, as template images (one colour; the
system tints them, selected or not, light or dark):

  本月  a mint sprig — two serrated mint leaves on a stem, and a tender bud just opening at the tip
  记录  Otto's lamp — the curved rod and the bead, with a soft halo of short rays round the light
  我的  Moss — the pebble with its two eyes and a small mint sprout, the same hand as the other two

Each is an SVG in a 28-point box (the size of a regular tab bar glyph), solid shapes only, so it stays crisp from the
compact tab bar to the large one. Run: python3 tools/tab_icons.py  (writes the asset catalog entries and a preview).
"""
import json, math, os, io
HERE = os.path.dirname(os.path.abspath(__file__))
CAT = os.path.join(HERE, "..", "ios", "Mossling", "Resources", "Assets.xcassets")

def mint_leaf(cx, cy, length, width, angle, teeth=6):
    """A mint leaf outline: ovate, pointed tip, a short stalk, a serrated edge; base at (cx, cy), pointing at `angle`."""
    pts_l, pts_r = [], []
    n = teeth * 4
    for i in range(n + 1):
        t = i / n
        w = width / 2 * math.sin(math.pi * min(1.0, t ** 0.8)) * (1 - 0.2 * t)
        if t < 0.08: w = width * 0.06
        saw = (t * teeth) % 1.0
        w *= 1 + (0.16 * saw if 0.12 < t < 0.92 else 0) - 0.06
        pts_l.append((t * length, -w)); pts_r.append((t * length, w))
    pts = pts_l + pts_r[::-1]
    a = math.radians(angle)
    tr = [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in tr) + "Z"

def vein(cx, cy, length, angle, w=0.9):
    """The midrib, cut out of the leaf (drawn as a thin line in the background colour via even-odd: a narrow sliver)."""
    a = math.radians(angle); p = []
    for t in (0.12, 0.85):
        p.append((cx + t * length * math.cos(a), cy + t * length * math.sin(a)))
    nx, ny = -math.sin(a) * w / 2, math.cos(a) * w / 2
    (x1, y1), (x2, y2) = p
    return f"M{x1 + nx:.2f} {y1 + ny:.2f} L{x2:.2f} {y2:.2f} L{x1 - nx:.2f} {y1 - ny:.2f}Z"

def month():
    # stem rising from the bottom, two leaves at a node, a bud at the tip
    stem = '<path d="M14 26.5 C13.6 22 14.2 17 14 11.5" stroke="#000" stroke-width="1.9" fill="none" stroke-linecap="round"/>'
    L = mint_leaf(13.6, 16.2, 11.5, 7.4, 205); R = mint_leaf(14.4, 15.2, 12.0, 7.6, -28)
    veins = vein(13.6, 16.2, 11.5, 205) + vein(14.4, 15.2, 12.0, -28)
    bud = mint_leaf(14.0, 11.8, 6.0, 3.6, -112, teeth=3) + mint_leaf(14.0, 11.8, 5.2, 3.2, -64, teeth=3)
    return stem + f'<path fill-rule="evenodd" d="{L} {veins.split("Z")[0]}Z"/>' \
                  f'<path fill-rule="evenodd" d="{R} {veins.split("Z")[1]}Z"/>' + f'<path d="{bud}"/>'

def journal():
    # Otto's lamp: the rod comes up from the lower right and arches over to the left; the bead hangs at its end, lit
    rod = '<path d="M22.5 26.5 C23.5 18 22 9.5 15.5 7.2 C12.5 6.2 10.2 7.6 9.6 10.2" stroke="#000" stroke-width="1.9" fill="none" stroke-linecap="round"/>'
    bead = '<circle cx="9.4" cy="14.3" r="3.6"/>'
    hang = '<path d="M9.6 10.2 L9.5 11" stroke="#000" stroke-width="1.6" stroke-linecap="round"/>'
    rays = ""
    for k, ang in enumerate((150, 190, 230, 270, 310, 350, 30)):
        a = math.radians(ang)
        r0, r1 = 6.0, 8.4 if k % 2 == 0 else 7.6
        x0, y0 = 9.4 + r0 * math.cos(a), 14.3 + r0 * math.sin(a)
        x1, y1 = 9.4 + r1 * math.cos(a), 14.3 + r1 * math.sin(a)
        rays += f'<path d="M{x0:.2f} {y0:.2f} L{x1:.2f} {y1:.2f}" stroke="#000" stroke-width="1.5" stroke-linecap="round"/>'
    return rod + hang + bead + rays

def me():
    # Moss: the pebble (higher on the right, as on the icon), two eyes cut out, a little mint sprout on top
    body = "M5.2 23.6 C3.2 22.2 2.6 19 3.6 16.2 C4.6 13 7.4 10.6 11.2 10.1 C14.8 9.6 17.9 9.9 20.6 11.3 C23.6 13 25.4 16.1 25.2 19.6 C25 22.3 23.3 24.4 20.4 24.9 C16.4 25.6 8.5 25.8 5.2 23.6Z"
    eyes = "M10.3 17.6 a1.6 1.9 0 1 0 3.2 0 a1.6 1.9 0 1 0 -3.2 0Z M15.1 17.6 a1.6 1.9 0 1 0 3.2 0 a1.6 1.9 0 1 0 -3.2 0Z"
    feet = '<rect x="8" y="24.2" width="2.4" height="3" rx="1.2"/><rect x="17.6" y="24.2" width="2.4" height="3" rx="1.2"/>'
    sprout = '<path d="M14.6 10.2 C14.4 8.4 14.6 6.8 14.9 5.6" stroke="#000" stroke-width="1.4" fill="none" stroke-linecap="round"/>'
    leaves = mint_leaf(14.9, 6.2, 5.6, 3.6, 200, teeth=3) + mint_leaf(14.9, 5.8, 6.0, 3.8, -20, teeth=3)
    return f'<path fill-rule="evenodd" d="{body} {eyes}"/>' + feet + sprout + f'<path d="{leaves}"/>'

ICONS = {"TabMonth": month, "TabJournal": journal, "TabMe": me}

def svg(inner):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28">{inner}</svg>'

def write():
    for name, f in ICONS.items():
        d = os.path.join(CAT, name + ".imageset"); os.makedirs(d, exist_ok=True)
        open(os.path.join(d, name + ".svg"), "w").write(svg(f()))
        json.dump({"images": [{"filename": name + ".svg", "idiom": "universal"}], "info": {"author": "xcode", "version": 1},
                   "properties": {"template-rendering-intent": "template", "preserves-vector-representation": True}},
                  open(os.path.join(d, "Contents.json"), "w"), indent=2)

def preview(out):
    import cairosvg
    from PIL import Image, ImageDraw
    sheet = Image.new("RGB", (3 * 220, 260), "white"); d = ImageDraw.Draw(sheet)
    for i, (name, f) in enumerate(ICONS.items()):
        for j, (bg, fg, size) in enumerate([("#FFFFFF", "#2E6B4A", 168), ("#1C1C1E", "#8FD3A8", 56)]):
            s = svg(f'<g fill="{fg}">' + f().replace("#000", fg) + "</g>")
            png = cairosvg.svg2png(bytestring=s.encode(), output_width=size, output_height=size, background_color=bg)
            im = Image.open(io.BytesIO(png))
            sheet.paste(im, (i * 220 + 26 if j == 0 else i * 220 + 140, 20 if j == 0 else 200))
    sheet.save(out)

if __name__ == "__main__":
    import sys
    write()
    if len(sys.argv) > 1: preview(sys.argv[1])
