#!/usr/bin/env python3
"""Night check: finds dark text drawn on the lamp's dark blue in the lamp screenshots.

The lamp's surfaces are deep blue (page #0E1430, card #19213F). Anything drawn there in near-black — text or a
system control left in its light appearance — has a contrast near 1:1. This counts near-black pixels (all channels
below 16, i.e. darker and less blue than any lamp surface) in each screenshot whose name contains "lamp", and fails
when they cover more than a small share of the screen. Calibrated on the device screenshot of the build-156 bug
(black date pickers and labels in a sheet: 0.57%) against the good lamp screens (0.00%).

    python3 tools/night_check.py <dir with ios_*.png>
"""
import sys, glob, os
from PIL import Image

LIMIT = 0.001   # share of the screen: good lamp screens measure 0.00%, the device screenshot of the bug 0.57%

def check(path):
    im = Image.open(path).convert("RGB")
    small = im.resize((im.width // 3, im.height // 3))
    px = list(small.get_flattened_data()) if hasattr(small, "get_flattened_data") else list(small.getdata())
    dark = sum(1 for r, g, b in px if r < 16 and g < 16 and b < 16)
    return dark / len(px)

def main():
    d = sys.argv[1] if len(sys.argv) > 1 else "."
    bad = []
    for p in sorted(glob.glob(os.path.join(d, "ios_*lamp*.png"))):
        share = check(p)
        flag = share > LIMIT
        print(f"{'FAIL' if flag else 'ok  '} {share * 100:5.2f}%  {os.path.basename(p)}")
        if flag: bad.append(p)
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
