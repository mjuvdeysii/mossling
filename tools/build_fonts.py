#!/usr/bin/env python3
"""Builds res/font/noto_serif_sc_semibold.ttf: Noto Serif SC 600 (OFL), cut down to the characters the app uses
(content.json + every Kotlin source + strings.xml). Run again whenever new Chinese text is added:
    python3 native/tools/build_fonts.py
Needs: npm (registry access), pip fonttools brotli."""
import glob, os, re, subprocess, tarfile, tempfile, json
from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "app", "src", "main")
OUT = os.path.join(APP, "res", "font", "noto_serif_sc_semibold.ttf")
chars = set()
for p in [os.path.join(APP, "assets", "content.json")] + glob.glob(os.path.join(APP, "java", "**", "*.kt"), recursive=True) + glob.glob(os.path.join(APP, "res", "values*", "*.xml")):
    chars |= set(open(p, encoding="utf-8").read())
chars |= set("０１２３４５６７８９，。、；：？！（）「」『』《》—…·％")
need = {ord(c) for c in chars if ord(c) > 0x2E7F}
tmp = tempfile.mkdtemp()
subprocess.check_call(["npm", "pack", "@fontsource/noto-serif-sc@5.3.1", "--silent"], cwd=tmp, stdout=subprocess.DEVNULL)
with tarfile.open(glob.glob(os.path.join(tmp, "*.tgz"))[0]) as t: t.extractall(tmp)
parts = []
for f in sorted(glob.glob(os.path.join(tmp, "package", "files", "noto-serif-sc-*-600-normal.woff2"))):
    font = TTFont(f); cmap = font.getBestCmap() or {}
    hit = need & set(cmap)
    if not hit: continue
    opt = subset.Options(); opt.flavor = None; opt.layout_features = ["*"]; opt.name_IDs = ["*"]; opt.notdef_outline = True
    s = subset.Subsetter(opt); s.populate(unicodes=sorted(hit)); s.subset(font)
    font.flavor = None; p = os.path.join(tmp, "part%03d.ttf" % len(parts)); font.save(p); parts.append(p)
merged = Merger().merge(parts)
merged.save(OUT)
print(len(need), "CJK characters,", len(parts), "parts,", os.path.getsize(OUT), "bytes ->", OUT)
