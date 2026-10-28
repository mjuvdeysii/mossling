"""The tab bar's three icons in the 2D world: the same three things as the 3D icons (tools/tab_icons3d.py) — a sprout
in a pot, a clipboard, Moss — drawn flat in the picture book's style (tools/stickers.py), with a fine white edge so they
hold on the glass. TabX2D (not chosen: quietened) and TabX2DOn (chosen: full colour).

Usage: python3 tools/tab_icons2d.py [preview.png]
"""
import io, json, os, sys
import cairosvg
from PIL import Image, ImageEnhance, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import picturebook as pb
import stickers as st

CAT = os.path.join(HERE, "..", "ios", "Mossling", "Resources", "Assets.xcassets")
PT = 30

def month(sv):
    sv.add('<path d="M120 150 V92" stroke="#3E9B5A" stroke-width="10" stroke-linecap="round"/>')
    sv.add(f'<ellipse cx="88" cy="88" rx="38" ry="21" fill="{st.G(sv, st.GREEN)}" transform="rotate(-24 88 88)"/>')
    sv.add(f'<ellipse cx="152" cy="80" rx="38" ry="21" fill="{st.G(sv, "#6FCB86")}" transform="rotate(24 152 80)"/>')
    sv.add(f'<path d="M66 146 H174 L160 214 a10 10 0 0 1 -10 8 H90 a10 10 0 0 1 -10 -8Z" fill="{st.G(sv, "#E2875A")}"/>')
    sv.add(f'<rect x="58" y="136" width="124" height="24" rx="10" fill="{st.G(sv, "#EC9A6C")}"/>')

def journal(sv):
    st.D["list_bullet_clipboard_fill"][1](sv)

def me(sv):
    sv.add(pb.cast_icon("moss", 120, 140, 78))

def draw(fn):
    sv = pb.SVG(240, 240); fn(sv)
    png = cairosvg.svg2png(bytestring=sv.svg().encode(), output_width=360)
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    a = im.getchannel("A")
    edge = a.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(0.8))
    white = Image.new("RGBA", im.size, (255, 255, 255, 0)); white.putalpha(edge)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0)); out.alpha_composite(white); out.alpha_composite(im)
    bb = out.getbbox(); side = max(bb[2] - bb[0], bb[3] - bb[1]) + 16
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.alpha_composite(out.crop(bb), ((side - (bb[2] - bb[0])) // 2, (side - (bb[3] - bb[1])) // 2))
    return sq

def quiet(im):
    a = im.getchannel("A")
    rgb = ImageEnhance.Color(im.convert("RGB")).enhance(0.35)
    rgb = Image.blend(rgb, Image.new("RGB", im.size, (236, 232, 226)), 0.18)
    q = rgb.convert("RGBA"); q.putalpha(a); return q

def write():
    pb.CAST = True
    for name, fn in (("TabMonth2D", month), ("TabJournal2D", journal), ("TabMe2D", me)):
        src = draw(fn)
        for suffix, im in (("", quiet(src)), ("On", src)):
            n = name + suffix; d = os.path.join(CAT, n + ".imageset"); os.makedirs(d, exist_ok=True)
            for old in os.listdir(d): os.remove(os.path.join(d, old))
            imgs = []
            for sc in (2, 3):
                fn2 = f"{n}@{sc}x.png"; im.resize((PT * sc, PT * sc), Image.LANCZOS).save(os.path.join(d, fn2))
                imgs.append({"filename": fn2, "idiom": "universal", "scale": f"{sc}x"})
            json.dump({"images": [{"idiom": "universal", "scale": "1x"}] + imgs, "info": {"author": "xcode", "version": 1},
                       "properties": {"template-rendering-intent": "original"}}, open(os.path.join(d, "Contents.json"), "w"), indent=2)
            print("wrote", n)

if __name__ == "__main__":
    write()
    if sys.argv[-1].endswith(".png"):
        P = Image.new("RGB", (6 * 120, 120), "#F2F2F7")
        for i, n in enumerate(("TabMonth2DOn", "TabMonth2D", "TabJournal2DOn", "TabJournal2D", "TabMe2DOn", "TabMe2D")):
            im = Image.open(os.path.join(CAT, n + ".imageset", n + "@3x.png")).convert("RGBA")
            P.paste(im, (15 + i * 120, 15), im)
        P.save(sys.argv[-1])
