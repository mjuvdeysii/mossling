"""App Store creative assets for 摸索台灯: the product page header (3840×1646, 21:9) and the search results asset
(3840×2560, 3:2), as flat sRGB JPEGs without transparency (App Store Connect rejects alpha).

python3 tools/store_assets.py <out dir> [<dir with ios_store_*.jpg>]
"""
import sys, os, glob
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ART = os.path.join(os.path.dirname(__file__), "..", "ios", "Art", "art")
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
FONT_M = "/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc"
SC = 2   # Simplified Chinese face inside the collection
INK = (38, 38, 44)
SOFT = (77, 78, 85)     # the app's secondary text
ACCENT = (8, 103, 95)   # the app's accent

def font(path, size): return ImageFont.truetype(path, size, index=SC)

def scene(cover, W, H, x):
    """A month cover scaled to the full height; its background and ground carried out to both edges row by row."""
    c = Image.open(os.path.join(ART, cover)).convert("RGB")
    s = H / c.height
    c = c.resize((round(c.width * s), H), Image.LANCZOS)
    out = Image.new("RGB", (W, H))
    left = c.crop((0, 0, 1, H)).resize((max(1, x), H))
    right_w = W - x - c.width
    out.paste(left, (0, 0))
    if right_w > 0: out.paste(c.crop((c.width - 1, 0, c.width, H)).resize((right_w, H)), (x + c.width, 0))
    out.paste(c, (x, 0))
    return out

def header(out_dir):
    W, H = 3840, 1646
    img = scene("cover_03.webp", W, H, 1450)
    d = ImageDraw.Draw(img)
    x = 220
    d.text((x, 470), "摸索台灯", font=font(FONT, 250), fill=INK)
    d.text((x + 8, 800), "孩子摸索，大人点灯", font=font(FONT_M, 104), fill=SOFT)
    d.text((x + 8, 960), "陪 0–3 岁宝宝玩，记下每一步成长", font=font(FONT_M, 72), fill=ACCENT)
    img.save(os.path.join(out_dir, "header_3840x1646.png"))   # PNG: App Store Connect refused .jpg here

def phone(path, height):
    """A screenshot as a phone-shaped card: rounded corners and a soft shadow, on the canvas's own colour."""
    s = Image.open(path).convert("RGB")
    w = round(s.width * height / s.height)
    s = s.resize((w, height), Image.LANCZOS)
    r = round(w * 0.12)
    mask = Image.new("L", (w, height), 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, height - 1), r, fill=255)
    return s, mask

def search(out_dir, shots):
    W, H = 3840, 2560
    bg = (251, 248, 240)
    img = Image.new("RGB", (W, H), bg)
    # the scene across the bottom third, as the ground the phones stand on
    band = scene("cover_09.webp", W, 1100, 1450).crop((0, 0, W, 1100))
    img.paste(band, (0, H - 1100))
    d = ImageDraw.Draw(img)
    d.text((W // 2, 150), "摸索台灯", font=font(FONT, 190), fill=INK, anchor="mt")
    d.text((W // 2, 400), "孩子摸索，大人点灯", font=font(FONT_M, 92), fill=SOFT, anchor="mt")
    names = ["ios_store_1_home.jpg", "ios_store_2_play.jpg", "ios_store_5_timer.jpg"]
    ph = 1880
    cards = [phone(os.path.join(shots, n), ph) for n in names]
    gap = 140
    total = sum(c[0].width for c in cards) + gap * (len(cards) - 1)
    x = (W - total) // 2
    for s, m in cards:
        sh = Image.new("L", (s.width + 160, ph + 160), 0)
        ImageDraw.Draw(sh).rounded_rectangle((80, 100, 80 + s.width, 100 + ph), round(s.width * 0.12), fill=90)
        sh = sh.filter(ImageFilter.GaussianBlur(40))
        img.paste((120, 100, 80), (x - 80, 600 - 80), sh)
        img.paste(s, (x, 600), m)
        x += s.width + gap
    img.save(os.path.join(out_dir, "search_3840x2560.png"))

if __name__ == "__main__":
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    header(out)
    if len(sys.argv) > 2: search(out, sys.argv[2])
