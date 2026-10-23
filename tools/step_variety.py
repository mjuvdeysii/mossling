"""Checks that every step picture differs from the one before it in the bodies and materials, not only in its marks.

Each step is drawn again without its marks (bubbles, badges, arrows, lines of sight) and compared with the previous
step of the same activity: the mean grayscale difference on a 240-pixel-wide render. A step that only swaps a speech
bubble reads as the same picture; the body has to show the change too — leaning in to engage, sitting back with a hand
at the chin to wait, a hand by the ear to listen, an open hand to describe (ios/DESIGN.md §4).

Gate: no adjacent pair below 1.5. Prints the lowest pairs.
Usage: python3 tools/step_variety.py
"""
import sys, json, io, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); sys.argv = sys.argv[:1]
import picturebook as pb, cairosvg, numpy as np
from PIL import Image

GATE = 1.5
sc = json.load(open(pb.SCENES)); acts = {a["code"]: a for a in pb.C["activities"]}
def img(spec, area):
    sp = dict(spec); sp["marks"] = []
    png = cairosvg.svg2png(bytestring=pb.scene(sp, area).svg().encode(), output_width=240)
    return np.asarray(Image.open(io.BytesIO(png)).convert("L"), dtype=np.float32)
rows = []
for code, steps in sc.items():
    area = pb.area_of(acts[code]); ims = [img(s, area) for s in steps]
    for i in range(len(ims) - 1):
        rows.append((float(np.abs(ims[i] - ims[i + 1]).mean()), code, i + 1))
rows.sort(); v = [r[0] for r in rows]
low = [r for r in rows if r[0] < GATE]
print(json.dumps({"pairs": len(rows), "median": round(float(np.median(v)), 2), "below_gate": len(low)}))
for d_, c_, i_ in rows[:8]: print("%.2f %s %d→%d" % (d_, c_, i_, i_ + 1))
sys.exit(1 if low else 0)
