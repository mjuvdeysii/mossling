"""The iOS app icon as an Icon Composer document (AppIcon.icon), in the way of Apple's own icons: one subject, centred
and large, on a plain field — Moss, the mossy pebble with the mint sprout, looking up at its leaves. Three layers (body,
sprout, eyes) so the system renders it as Liquid Glass in the light, dark, tinted and clear appearances. The drawing is
the same flat print as in the app: colour over an offset deeper copy."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'ios', 'Mossling', 'Resources', 'AppIcon.icon')
MINT = json.load(open(os.path.join(HERE, 'mint.json')))
VIEW = 'viewBox="0 0 100 100" width="1024" height="1024"'
MOSS_BODY = "M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z"
TUFTS = "M24 52 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M64 44 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M70 72 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M28 72 c2 -2 5 -2 7 0 c-2 1.6 -5 1.6 -7 0Z"
G = 'transform="translate(3.5 7) scale(0.92)"'
INK = '#1C1D19'

def svg(name, body):
    open(os.path.join(OUT, 'Assets', name), 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" {VIEW}>{body}</svg>')

os.makedirs(os.path.join(OUT, 'Assets'), exist_ok=True)
for f in os.listdir(os.path.join(OUT, 'Assets')): os.remove(os.path.join(OUT, 'Assets', f))
legs = ''.join(f'<rect x="{x}" y="80" width="6.5" height="10" rx="3.2" fill="{INK}"/>' for x in (33, 59))
svg('moss.svg', f'<g {G}>{legs}<path d="{MOSS_BODY}" fill="#3D5434" transform="translate(1.4 1.2)"/><path d="{MOSS_BODY}" fill="#55704A"/>'
    f'<path d="{TUFTS}" fill="#88A06C" fill-opacity=".7"/></g>')
leaves = ''.join(f'<path d="{m[0]}" fill="{c}"/>' for m, c in zip([MINT[1], MINT[0], MINT[3], MINT[2]], ['#7FCBA0', '#4FAE7F', '#A9E0C0', '#A9E0C0']))
svg('mint.svg', f'<g {G}><path d="M49 36 C48 30 49.2 23 50 17.6" stroke="#3D5434" stroke-width="2.2" fill="none" stroke-linecap="round"/>{leaves}</g>')
svg('eyes.svg', f'<g {G}><ellipse cx="43" cy="55" rx="6.4" ry="7.4" fill="#FBF9F3"/><ellipse cx="58" cy="55" rx="6.4" ry="7.4" fill="#FBF9F3"/>'
    f'<circle cx="45.2" cy="51.6" r="4" fill="{INK}"/><circle cx="60.2" cy="51.6" r="4" fill="{INK}"/></g>')

def layer(image, name, glass=True):
    return {"image-name": image, "name": name, "glass": glass, "hidden": False, "position": {"scale": 1, "translation-in-points": [0, 0]}}

icon = {
    "fill-specializations": [
        {"value": {"linear-gradient": ["display-p3:1.00000,0.96500,0.89500,1.00000", "display-p3:0.98000,0.86500,0.74000,1.00000"]}},
        {"appearance": "dark", "value": "system-dark"},
    ],
    "groups": [
        {"layers": [layer('eyes.svg', 'eyes', glass=False), layer('mint.svg', 'mint'), layer('moss.svg', 'moss')],
         "lighting": "individual", "shadow": {"kind": "layer-color", "opacity": 0.5}, "specular": True,
         "translucency": {"enabled": True, "value": 0.2}, "blur-material": 0.1},
    ],
    "supported-platforms": {"squares": ["iOS"]},
}
json.dump(icon, open(os.path.join(OUT, 'icon.json'), 'w'), indent=2)
print('ok', OUT)
