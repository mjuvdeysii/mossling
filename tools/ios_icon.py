"""The iOS app icon as an Icon Composer document (AppIcon.icon): Moss in front, Otto behind dangling the golden bead
over Moss, on a warm paper field. Each part is its own layer so the system can render it as Liquid Glass (specular
highlights, translucency, shadows) and in the light, dark, tinted and clear appearances."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'ios', 'Mossling', 'Resources', 'AppIcon.icon')
MINT = json.load(open(os.path.join(HERE, 'mint.json')))
VIEW = 'viewBox="11.5 15.5 84 84" width="1024" height="1024"'
MOSS_BODY = "M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z"
OTTO_BODY = "M30 84 C25 74 24 58 26 44 C28 28 38 16 52 16 C65 17 74 28 75 44 C76 60 74 75 70 84 C60 88 40 88 30 84Z"
OTTO_DIP = "M25.2 64 C35 68 64 68 75.4 63 C75 71 73 78 70 84 C60 88 40 88 30 84 C27.6 78 26 71 25.2 64Z"
OTTO = 'transform="translate(40.5 22) scale(0.61)"'
MOSS = 'transform="translate(8.5 33) scale(0.62)"'
INK = '#1C1D19'

def svg(name, body):
    open(os.path.join(OUT, 'Assets', name), 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" {VIEW}>{body}</svg>')

def legs(xs): return ''.join(f'<rect x="{x}" y="80" width="6.5" height="10" rx="3.2" fill="{INK}"/>' for x in xs)

os.makedirs(os.path.join(OUT, 'Assets'), exist_ok=True)
# Otto: the body, the eye on its own layer (kept crisp), the rod with the golden bead
svg('otto.svg', f'<g {OTTO}>{legs((38, 56))}<path d="{OTTO_BODY}" fill="#2D4A8C"/><path d="{OTTO_DIP}" fill="#1F3566" fill-opacity=".55"/></g>')
svg('otto-eye.svg', f'<g {OTTO}><ellipse cx="51" cy="44" rx="12.5" ry="11.5" fill="#FBF9F3"/><circle cx="44" cy="49" r="7.1" fill="{INK}"/>'
    f'<path d="M38.5 32.5 H63.5 V40.3 H38.5Z" fill="#2D4A8C" clip-path="url(#e)"/><clipPath id="e"><ellipse cx="51" cy="44" rx="12.5" ry="11.5"/></clipPath></g>')
svg('bead.svg', f'<g {OTTO}><path d="M50 16.5 C45 4 30 1 21 8" stroke="#1F3566" stroke-width="2.4" fill="none" stroke-linecap="round"/><circle cx="20" cy="11.5" r="5" fill="#D4A21C"/></g>')
# Moss: the body, the mint leaves, the eyes looking up at the bead
svg('moss.svg', f'<g {MOSS}>{legs((33, 59))}<path d="{MOSS_BODY}" fill="#55704A"/></g>')
leaves = ''.join(f'<path d="{m[0]}" fill="{c}"/>' for m, c in zip([MINT[1], MINT[0], MINT[3], MINT[2]], ['#7FCBA0', '#4FAE7F', '#A9E0C0', '#A9E0C0']))
svg('mint.svg', f'<g {MOSS}><path d="M49 36 C48 30 49.2 23 50 17.6" stroke="#3D5434" stroke-width="2.2" fill="none" stroke-linecap="round"/>{leaves}</g>')
svg('moss-eyes.svg', f'<g {MOSS}><ellipse cx="43" cy="55" rx="6.4" ry="7.4" fill="#FBF9F3"/><ellipse cx="58" cy="55" rx="6.4" ry="7.4" fill="#FBF9F3"/>'
    f'<circle cx="45.6" cy="51" r="4" fill="{INK}"/><circle cx="60.6" cy="51" r="4" fill="{INK}"/></g>')

def layer(image, name, glass=True):
    return {"image-name": image, "name": name, "glass": glass, "hidden": False, "position": {"scale": 1, "translation-in-points": [0, 0]}}

def group(layers, translucency):
    return {"layers": layers, "lighting": "individual", "shadow": {"kind": "layer-color", "opacity": 0.5},
            "specular": True, "translucency": {"enabled": True, "value": translucency}, "blur-material": 0.1}

icon = {
    "fill-specializations": [
        {"value": {"linear-gradient": ["display-p3:1.00000,0.97200,0.92500,1.00000", "display-p3:0.99000,0.90000,0.80000,1.00000"]}},
        {"appearance": "dark", "value": "system-dark"},
    ],
    # front first: Moss, then Otto behind it
    "groups": [
        group([layer('moss-eyes.svg', 'moss-eyes', glass=False), layer('mint.svg', 'mint'), layer('moss.svg', 'moss')], 0.25),
        group([layer('otto-eye.svg', 'otto-eye', glass=False), layer('bead.svg', 'bead'), layer('otto.svg', 'otto')], 0.25),
    ],
    "supported-platforms": {"squares": ["iOS"]},
}
json.dump(icon, open(os.path.join(OUT, 'icon.json'), 'w'), indent=2)
print('ok', OUT)
