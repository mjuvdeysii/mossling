"""The growth map's night stage in the 2D world: the child's room at night — Moss asleep in the crib under a blanket,
a moonlit window with curtains, a mobile, a ring stacker on the rug — drawn flat in the picture book's style, the same
room as the 3D plate (tools/plates3d.py --room). Output: ios/Art/art/2d_stage_room.webp.
"""
import io, json, os, sys
import cairosvg
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import picturebook as pb

W, H = 1200, 600
def main():
    sv = pb.SVG(W, H)
    A = sv.add
    A(f'<rect width="{W}" height="{H}" fill="#4E5584"/>')
    A(f'<rect y="300" width="{W}" height="140" fill="#474D78"/><rect y="296" width="{W}" height="10" fill="#727799"/>')
    A(f'<rect y="440" width="{W}" height="160" fill="#665670"/>')
    A(f'<ellipse cx="560" cy="470" rx="330" ry="34" fill="#8C7AAE"/>')
    # the window, upper right, the moon and stars in it, curtains either side
    A('<rect x="780" y="30" width="220" height="210" rx="8" fill="#EDE3D3"/><rect x="794" y="44" width="192" height="182" fill="#24316B"/>')
    A('<circle cx="930" cy="96" r="30" fill="#FFE9A8"/><circle cx="944" cy="86" r="27" fill="#24316B"/>')
    for x, y in ((820, 90), (860, 160), (950, 190), (840, 120), (900, 70)): A(f'<circle cx="{x}" cy="{y}" r="3" fill="#FFF4D0"/>')
    A('<rect x="886" y="44" width="8" height="182" fill="#EDE3D3"/><rect x="794" y="131" width="192" height="8" fill="#EDE3D3"/>')
    A('<rect x="770" y="236" width="240" height="14" rx="5" fill="#EDE3D3"/>')
    for x in (740, 1004): A(f'<path d="M{x} 20 h56 v240 q-28 10 -56 0z" fill="#C49AC4"/>')
    A('<path d="M720 20 H1080" stroke="#C9A27A" stroke-width="6" stroke-linecap="round"/>')
    # the mobile
    A('<path d="M430 80 H610" stroke="#C9A27A" stroke-width="5" stroke-linecap="round"/>')
    for x, y, c in ((450, 150, "#F3ECE1"), (520, 130, "#FFD36B"), (590, 160, "#FFD36B")):
        A(f'<path d="M{x} 80 V{y}" stroke="#E9E2D6" stroke-width="2"/><circle cx="{x}" cy="{y + 10}" r="12" fill="{c}"/>')
    # the crib: legs, mattress, Moss asleep on the pillow under the blanket, then the bars in front
    wood = "#E9CDA6"
    for x in (330, 690): A(f'<rect x="{x - 8}" y="220" width="16" height="250" rx="7" fill="{wood}"/><circle cx="{x}" cy="216" r="11" fill="{wood}"/>')
    A('<rect x="336" y="378" width="348" height="36" rx="14" fill="#F3ECE1"/>')
    A('<rect x="350" y="356" width="84" height="30" rx="14" fill="#FBF5EC"/>')
    A(pb.cast_icon("moss", 400, 344, 34, asleep=True))
    A('<path d="M420 384 Q440 330 560 336 Q672 338 676 384 Z" fill="#F2C77A"/>')
    for x in (470, 530, 590, 640): A(f'<circle cx="{x}" cy="{368 if x % 60 else 362}" r="5" fill="#FFFFFF"/>')
    for y in (232, 414): A(f'<rect x="322" y="{y}" width="376" height="12" rx="6" fill="{wood}"/>')
    for i in range(1, 12): A(f'<rect x="{330 + i * 30 - 4}" y="236" width="8" height="182" rx="4" fill="{wood}"/>')
    # a ring stacker on the rug
    A('<ellipse cx="250" cy="468" rx="34" ry="8" fill="#E3C08C"/><rect x="246" y="390" width="8" height="78" rx="4" fill="#E3C08C"/>')
    for i, (w, c) in enumerate(((60, "#4FA3A0"), (48, "#F2C14E"), (36, "#E0644B"))):
        A(f'<rect x="{250 - w / 2}" y="{448 - i * 18}" width="{w}" height="18" rx="9" fill="{c}"/>')
    png = cairosvg.svg2png(bytestring=sv.svg().encode(), output_width=W)
    out = os.path.join(pb.OUT, "2d_stage_room.webp")
    Image.open(io.BytesIO(png)).convert("RGB").save(out, "WEBP", quality=90, method=6)
    ipath = os.path.join(pb.OUT, "index.json"); index = json.load(open(ipath)); index["size"]["2d_stage_room.webp"] = [W, H]
    json.dump(index, open(ipath, "w"), separators=(",", ":"))
    print("wrote 2d_stage_room.webp")

if __name__ == "__main__":
    main()
