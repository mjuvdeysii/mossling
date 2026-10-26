"""Moss and Otto — character design sheets, built from the canonical shapes (the app icon, tools/ios_icon.py).

The upgrade keeps the design DNA: the same silhouettes, proportions, colours, eye placement and flat shape language.
What changes is craft: cleaner construction, a consistent light rule, expressions, and a finish. Three finish
directions are explored side by side with the original, as a review board (gate 1 of docs/IP_PIPELINE.md).

Usage:
  python3 tools/ipdesign.py board out.png
"""
import io, json, math, os, sys
import cairosvg
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
MINT = json.load(open(os.path.join(HERE, "mint.json")))
INK = "#1C1D19"
MOSS_BODY = "M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z"
MOSS_UNDER = "M14 68 C30 76 70 76 88 66 C88 76 80 84 70 86 C56 88 33 89 22 82 C17 78 14 74 14 68Z"
OTTO_BODY = "M30 84 C25 74 24 58 26 44 C28 28 38 16 52 16 C65 17 74 28 75 44 C76 60 74 75 70 84 C60 88 40 88 30 84Z"
OTTO_DIP = "M25.2 64 C35 68 64 68 75.4 63 C75 71 73 78 70 84 C60 88 40 88 30 84 C27.6 78 26 71 25.2 64Z"
C = dict(moss="#55704A", mossDeep="#3D5434", mossLight="#7E9B62", otto="#2D4A8C", ottoDeep="#1F3566", ottoLight="#4A68A8",
         bead="#D4A21C", beadLight="#F2CF6A", paper="#FBF9F3", cheek="#F49AB0", mint=["#7FCBA0", "#4FAE7F", "#A9E0C0", "#A9E0C0"])

FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"

def font(size):
    try: return ImageFont.truetype(FONT, size)
    except Exception: return ImageFont.load_default()

# ---------- parts ----------
def legs(xs, style):
    r = 3.2
    return "".join(f'<rect x="{x}" y="80" width="6.5" height="10" rx="{r}" fill="{INK}"/>' for x in xs)

def eye(cx, cy, rx, ry, look, lid, skin, face, pr_k=0.62, style="A"):
    """The canonical eye: a paper-white oval, an ink pupil that looks, a lid of the body colour from the top."""
    if face in ("happy", "sleep"):
        up = face == "happy"
        d = f"M{cx - rx * .85:.1f},{cy + (1 if up else -1):.1f} Q{cx:.1f},{cy - ry * (.95 if up else -.8):.1f} {cx + rx * .85:.1f},{cy + (1 if up else -1):.1f}"
        return f'<path d="{d}" stroke="{INK}" stroke-width="{max(1.8, ry * .32):.2f}" fill="none" stroke-linecap="round"/>'
    pr = min(rx, ry) * (0.48 if face == "wow" else pr_k)
    lx, ly = look
    px, py = cx + lx * (rx - pr - .4), cy + ly * (ry - pr - .4)
    cid = f"e{int(cx * 10)}{int(cy * 10)}"
    s = f'<clipPath id="{cid}"><ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}"/></clipPath>'
    s += f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{C["paper"]}"/>'
    s += f'<g clip-path="url(#{cid})"><circle cx="{px:.2f}" cy="{py:.2f}" r="{pr:.2f}" fill="{INK}"/>'
    if style != "O":
        # the catchlight: one small spot, up and to the left — the eye reads alive at any size
        s += f'<circle cx="{px - pr * .38:.2f}" cy="{py - pr * .4:.2f}" r="{pr * .3:.2f}" fill="#FFFFFF"/>'
    if lid > 0 and face != "wow":
        s += f'<rect x="{cx - rx - 1}" y="{cy - ry - 1}" width="{rx * 2 + 2}" height="{(ry * 2 + 2) * lid:.2f}" fill="{skin}"/>'
        if style != "O":
            # the lid's lower edge, a hair darker: the lid reads as a lid, not a cut
            s += f'<rect x="{cx - rx - 1}" y="{cy - ry - 1 + (ry * 2 + 2) * lid - .9:.2f}" width="{rx * 2 + 2}" height="0.9" fill="#000" fill-opacity=".18"/>'
    s += "</g>"
    return s

def finish_defs(style, key):
    """The light rule of each direction, as gradients and shapes in the 100-unit box.
    O original: flat colour + flat darker underside.
    A refined flat: + one flat light shape on the upper left (two tones and a highlight, as in cel animation).
    B soft volume: the light as a soft radial falloff from the upper left, a soft core shadow, a warm bounce at the base.
    C painted: B's light, finished afterwards with a gouache grain (applied in raster)."""
    return ""

def body(path, under, fill, deep, light, style, uid):
    s = ""
    if style == "O":
        return f'<path d="{path}" fill="{fill}"/><clipPath id="c{uid}"><path d="{path}"/></clipPath><path d="{under}" fill="{deep}" fill-opacity=".55" clip-path="url(#c{uid})"/>'
    s += f'<clipPath id="c{uid}"><path d="{path}"/></clipPath>'
    if style == "A":
        s += f'<path d="{path}" fill="{fill}"/>'
        s += f'<g clip-path="url(#c{uid})">'
        s += f'<path d="{under}" fill="{deep}" fill-opacity=".62"/>'
        # one flat highlight shape, following the form, upper left
        s += f'<ellipse cx="38" cy="44" rx="18" ry="9" transform="rotate(-18 38 44)" fill="{light}" fill-opacity=".55"/>'
        s += "</g>"
        return s
    # B and C: soft volume
    s += (f'<radialGradient id="g{uid}" cx="0.34" cy="0.28" r="0.85"><stop offset="0" stop-color="{light}"/>'
          f'<stop offset="0.55" stop-color="{fill}"/><stop offset="1" stop-color="{deep}"/></radialGradient>')
    s += (f'<linearGradient id="b{uid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0.75" stop-color="#FFD9A0" stop-opacity="0"/>'
          f'<stop offset="1" stop-color="#FFD9A0" stop-opacity=".22"/></linearGradient>')
    s += f'<path d="{path}" fill="url(#g{uid})"/>'
    s += f'<g clip-path="url(#c{uid})"><path d="{under}" fill="{deep}" fill-opacity=".35"/><path d="{path}" fill="url(#b{uid})"/></g>'
    return s

def shadow(cx, rx, style):
    if style == "O": return ""
    return (f'<radialGradient id="sh{int(cx)}"><stop offset="0" stop-color="#3A2A18" stop-opacity=".28"/><stop offset="1" stop-color="#3A2A18" stop-opacity="0"/></radialGradient>'
            f'<ellipse cx="{cx}" cy="90.5" rx="{rx}" ry="{rx * .2:.1f}" fill="url(#sh{int(cx)})"/>')

def moss(style="A", face="open", look=(.65, -.55), lid=0.0):
    s = shadow(51, 34, style)
    s += f'<path d="M49 36 C48 30 49.2 23 50 17.6" stroke="{C["mossDeep"]}" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
    s += "".join(f'<path d="{m[0]}" fill="{c}"/>' for m, c in zip([MINT[1], MINT[0], MINT[3], MINT[2]], C["mint"]))
    if style != "O":
        # the leaves' midrib, as on a real mint leaf
        s += "".join(f'<path d="{m[1]}" stroke="#3E8F63" stroke-width=".4" fill="none" stroke-linecap="round" opacity=".55"/>' for m in MINT[:2] if len(m) > 1)
    s += legs((33, 59), style)
    s += body(MOSS_BODY, MOSS_UNDER, C["moss"], C["mossDeep"], C["mossLight"], style, "m")
    if face in ("happy", "wow") and style != "O":
        s += "".join(f'<ellipse cx="{x}" cy="64" rx="4.2" ry="2.5" fill="{C["cheek"]}" fill-opacity=".8"/>' for x in (35, 66))
    s += eye(43, 55, 6.4, 7.4, look, lid, C["moss"], face, style=style) + eye(58, 55, 6.4, 7.4, look, lid, C["moss"], face, style=style)
    if face == "happy" and style != "O":
        s += f'<path d="M46.5 67 Q50.5 71 54.5 67" stroke="{INK}" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
    if face == "wow" and style != "O":
        s += f'<ellipse cx="50.5" cy="68" rx="2.2" ry="2.8" fill="{INK}"/>'
    return s

def otto(style="A", face="open", look=(-.55, .45), lid=0.34, glow=False):
    s = shadow(51, 26, style)
    if glow and style != "O":
        s += ('<radialGradient id="glow"><stop offset="0" stop-color="#FFC24A" stop-opacity=".55"/><stop offset="1" stop-color="#FFC24A" stop-opacity="0"/></radialGradient>'
              '<circle cx="20" cy="11.5" r="14" fill="url(#glow)"/>')
    s += f'<path d="M50 16.5 C45 4 30 1 21 8 L20 11.5" stroke="{C["ottoDeep"]}" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
    if style == "O":
        s += f'<circle cx="20" cy="11.5" r="5" fill="{C["bead"]}"/>'
    else:
        s += (f'<radialGradient id="bd" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="{C["beadLight"]}"/><stop offset="1" stop-color="{C["bead"]}"/></radialGradient>'
              f'<circle cx="20" cy="11.5" r="5" fill="url(#bd)"/><circle cx="18.4" cy="9.9" r="1.3" fill="#FFF6D8"/>')
    s += legs((38, 56), style)
    s += body(OTTO_BODY, OTTO_DIP, C["otto"], C["ottoDeep"], C["ottoLight"], style, "o")
    if face in ("happy", "wow") and style != "O":
        s += f'<ellipse cx="66" cy="58" rx="4.2" ry="2.5" fill="{C["cheek"]}" fill-opacity=".75"/>'
    s += eye(51, 44, 12.5, 11.5, look, lid, C["otto"], face, style=style)
    if face == "happy" and style != "O":
        s += f'<path d="M46 63 Q51 67.5 56 63" stroke="{INK}" stroke-width="1.8" fill="none" stroke-linecap="round"/>'
    if face == "wow" and style != "O":
        s += f'<ellipse cx="51" cy="64" rx="2.2" ry="2.8" fill="{INK}"/>'
    return s

def render(inner, px):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="{px}" height="{px}">{inner}</svg>'
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=px, output_height=px))).convert("RGBA")

def gouache(im, seed=1):
    """Direction C's finish: a painted grain inside the shapes — pigment pooling (low-frequency value drift) and paper
    tooth (fine noise) — and a slightly softened edge, as gouache on cold-press paper."""
    rng = np.random.default_rng(seed)
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    low = Image.fromarray((rng.random((h // 24 + 1, w // 24 + 1)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(w / 60))
    low = (np.asarray(low).astype(np.float32) / 255 - .5) * 0.16
    tooth = (rng.random((h, w)).astype(np.float32) - .5) * 0.07
    tooth = np.asarray(Image.fromarray(((tooth + .5) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255 - .5
    k = 1 + low[..., None] + tooth[..., None] * 0.6
    rgb = np.clip(a[..., :3] * k, 0, 255)
    out = np.dstack([rgb, a[..., 3]]).astype(np.uint8)
    o = Image.fromarray(out, "RGBA")
    alpha = o.split()[3].filter(ImageFilter.GaussianBlur(0.6))
    o.putalpha(alpha)
    return o

def character(kind, style, face="open", px=420, **kw):
    inner = moss(style, face, **kw) if kind == "moss" else otto(style, face, **kw)
    im = render(inner, px)
    return gouache(im) if style == "C" else im

def board(out):
    styles = [("O", "原设计（应用图标）", "平涂 + 一块平涂暗部"),
              ("A", "方向 A · 精修平涂", "造型不变；两色平涂 + 一块高光，眼神光、眼睑边，表情增加腮红与嘴"),
              ("B", "方向 B · 绘本柔光", "造型不变；左上来光的柔和体积、底部暖色反光、柔和投影，与应用的绘本插画同一套光"),
              ("C", "方向 C · 水粉质感", "方向 B 的光，再加水粉颜料的颗粒与纸纹，像手绘绘本原画")]
    faces = [("open", "平静"), ("happy", "开心"), ("wow", "惊奇"), ("sleep", "睡着")]
    W, row_h, big = 2400, 560, 420
    im = Image.new("RGB", (W, 140 + row_h * len(styles)), "#F6F1E8")
    d = ImageDraw.Draw(im)
    d.text((60, 40), "Moss & Otto · 角色升级 · 评审一：完成方向（造型、比例、配色保持原设计）", fill="#2B241C", font=font(44))
    for r, (st, title, note) in enumerate(styles):
        y0 = 140 + r * row_h
        d.rounded_rectangle((40, y0, W - 40, y0 + row_h - 30), 28, fill="#FFFFFF" if st != "O" else "#EFE8DC")
        d.text((80, y0 + 24), title, fill="#2B241C", font=font(36))
        d.text((80, y0 + 74), note, fill="#6B5E4E", font=font(24))
        # the pair, large
        m = character("moss", st, px=big); o = character("otto", st, px=int(big * .95), glow=True)
        im.paste(o, (300, y0 + 110), o); im.paste(m, (80, y0 + 120), m)
        # expressions, small
        x = 820
        for f, label in faces:
            mm = character("moss", st, f, px=240, look=(0, 0) if f != "open" else (.65, -.55))
            oo = character("otto", st, f, px=230, look=(0, 0.1) if f != "open" else (-.55, .45), lid=0 if f == "wow" else .34)
            im.paste(oo, (x + 120, y0 + 150), oo); im.paste(mm, (x, y0 + 170), mm)
            d.text((x + 120, y0 + 430), label, fill="#6B5E4E", font=font(26))
            x += 390
    im.save(out)

if __name__ == "__main__":
    {"board": board}[sys.argv[1]](sys.argv[2])
