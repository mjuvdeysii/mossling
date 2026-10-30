"""Re-measure each contrast issue in an accessibility audit list against the screenshot of that screen.

Usage: python3 tools/a11y_contrast_check.py <dir with ios_a11y_*.txt and .png> <tag: default|dark|xxxl> [width in points]
Needs Pillow (pip install pillow).
For every contrast line that names an element frame, it crops that frame from the screenshot of the screen where it was
seen and takes the contrast between the darkest and lightest pixel (WCAG relative luminance). This is an upper bound:
under the WCAG minimum here is very likely a real failure (antialiased edges can lighten the darkest pixel of very
small text, so check those by eye); above it, the text itself can still be thin, so the line is marked "pixels pass"
rather than cleared.
"""
import re, sys, os
from PIL import Image

def lum(c):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = c[:3]
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

d, tag = sys.argv[1], sys.argv[2]
POINTS = float(sys.argv[3]) if len(sys.argv) > 3 else 402   # the simulator's width in points (iPhone 17 Pro: 402)
lines = open(os.path.join(d, f"ios_a11y_{tag}.txt"), encoding="utf-8").read().splitlines()[2:]
pat = re.compile(r"“(.*?)” id=\S* (-?\d+),(-?\d+) (\d+)×(\d+).*@ (.*)$")
real, ok, blind = [], [], []
for l in lines:
    if not l.startswith("contrast"):
        continue
    m = pat.search(l)
    if not m:
        blind.append(l[:120]); continue
    label, x, y, w, h, places = m.group(1), *map(int, m.groups()[1:5]), m.group(6)
    place = places.split(",")[0].strip().replace(" ↓", "_down")
    shot = os.path.join(d, f"ios_a11y_{'default_dark' if tag == 'dark' else tag}_{place}.png")
    if not os.path.exists(shot):
        blind.append(l[:120]); continue
    im = Image.open(shot).convert("RGB")
    s = im.size[0] / POINTS
    l, t, r, b = int(x * s), int(y * s), int((x + w) * s), int((y + h) * s)
    if l < 0 or t < 0 or r > im.size[0] or b > im.size[1]:
        blind.append(f"off screen: “{label}”"); continue
    box = im.crop((l, t, r, b))
    L = [lum(p) for p in box.getdata()]
    if not L:
        blind.append(l[:120]); continue
    ratio = (max(L) + 0.05) / (min(L) + 0.05)
    need = 3.0 if h >= 24 else 4.5   # large text (about 18 pt and up, with its line height) needs 3:1
    (real if ratio < need else ok).append(f"{ratio:4.1f}:1  “{label}” @ {places}")
print(f"{tag}: {len(real)} fail by pixels, {len(ok)} pass by pixels, {len(blind)} without a frame")
for r in real: print("  FAIL", r)
for r in ok: print("  pass", r)
for r in blind: print("  ?   ", r)
