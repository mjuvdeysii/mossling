"""Checks the activity pictures.

cropped: pictures with something cut off at the top or side edges — this is the gate (must be empty).

The pixel statistics below are kept for information only. They turned out not to measure whether a step can be
understood: the picture book keeps the camera, background and people fixed and changes only the action, so steps
that read clearly apart still differ in few pixels (ios/DESIGN.md §6). Comprehension is tested blind instead.

within: mean pixel difference between the steps of one activity
between: mean difference between the first pictures of different activities (higher = activities tell apart)
Both on 96x72 grayscale thumbnails, 0-255 scale; also the share of step pairs below a 'looks the same' threshold.
Usage: python3 tools/art_check.py <art dir>
"""
import sys, os, json, itertools
from PIL import Image
import numpy as np

d = sys.argv[1]
files = sorted(f for f in os.listdir(d) if f.startswith("play_") and f.endswith(".webp"))
def load(f): return np.asarray(Image.open(os.path.join(d, f)).convert("L").resize((96, 72)), dtype=np.float32)
groups = {}
for f in files:
    code = f.split("_")[1]; groups.setdefault(code, []).append(f)
same = 12.0
within, pairs_same, pairs = [], 0, 0
for code, fs in groups.items():
    ims = [load(f) for f in sorted(fs)]
    for a, b in itertools.combinations(ims, 2):
        v = float(np.abs(a - b).mean()); within.append(v); pairs += 1; pairs_same += v < same
firsts = [load(sorted(fs)[0]) for fs in groups.values()]
between = [float(np.abs(a - b).mean()) for a, b in itertools.combinations(firsts, 2)]
# cropping: anything other than the paper or the backdrop in the outermost 3 px rows/columns (top, left, right)
cropped = []
for f in files:
    im = np.asarray(Image.open(os.path.join(d, f)).convert("RGB").resize((720, 540)), dtype=np.int16)
    edges = np.concatenate([im[:3].reshape(-1, 3), im[:, :3].reshape(-1, 3), im[:, -3:].reshape(-1, 3)])
    ref = im[1, 1]
    # the floor and the outdoor sky may touch the sides; count only strongly different pixels on the top edge,
    # and on the sides above the floor
    top = im[:3].reshape(-1, 3); sides = np.concatenate([im[:380, :3].reshape(-1, 3), im[:380, -3:].reshape(-1, 3)])
    bad = (np.abs(top - ref).sum(1) > 60).mean() + (np.abs(sides - ref).sum(1) > 60).mean()
    if bad > 0.01: cropped.append(f)
print(json.dumps({"cropped": cropped}))
print(json.dumps({"activities": len(groups), "step_pairs": pairs,
                  "within_mean": round(np.mean(within), 1), "within_min": round(min(within), 1),
                  "step_pairs_looking_same": f"{pairs_same}/{pairs}",
                  "between_mean": round(np.mean(between), 1), "between_p10": round(float(np.percentile(between, 10)), 1)}))
