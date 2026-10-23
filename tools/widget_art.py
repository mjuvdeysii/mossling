"""The widget's own drawings: a copy of the few pictures the widget and the Live Activity show — the companions, the
stickers of the kinds of entry, the shelf trays — so the extension does not carry the whole picture book.

Output: ios/Art/widget/ (bundled into the widget as the folder "widget"), and the companions also into ios/Art/art
for the app's own renders of the widget faces. Names match ios/Shared/WidgetFaces.swift (WidgetArt).
Usage: python3 tools/widget_art.py
"""
import os, re, shutil
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART, OUT = os.path.join(ROOT, "ios/Art/art"), os.path.join(ROOT, "ios/Art/widget")
PAIR = os.path.join(ROOT, "tools/pair.png")
# the kinds of entry, by the symbol each sticker replaces (ios/Shared/Journal.swift LogType.symbol)
src = open(os.path.join(ROOT, "ios/Shared/Journal.swift")).read()
block = src[src.index("static func symbol"):src.index("static let timed")]
names = ["ic_" + s.replace(".", "_") + ".webp" for s in re.findall(r'"([a-z0-9.]+)"', block) if s != "circle"]
shutil.rmtree(OUT, ignore_errors=True); os.makedirs(OUT)
for n in names + sorted(f for f in os.listdir(ART) if f.startswith("tray_")):
    if os.path.exists(os.path.join(ART, n)): shutil.copy(os.path.join(ART, n), OUT)
    else: print("missing", n)
for d in (OUT, ART): shutil.copy(PAIR, os.path.join(d, "pair.png"))
print(len(os.listdir(OUT)), "files")
