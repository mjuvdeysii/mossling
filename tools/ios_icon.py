"""The iOS app icon as an Icon Composer document (AppIcon.icon): the two painted wooden companions under a small
rainbow — Moss in front looking up, Otto beside and behind looking down at Moss. Each part is its own layer so the
system renders it as Liquid Glass (specular highlights, translucency, shadows) in the light, dark, tinted and clear
appearances."""
import json, os, math
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'ios', 'Mossling', 'Resources', 'AppIcon.icon')
VIEW = 'viewBox="0 0 100 100" width="1024" height="1024"'
MOSS_BODY = "M50 30 C70 30 84 48 84 66 C84 80 72 88 50 88 C28 88 16 80 16 66 C16 48 30 30 50 30Z"
OTTO_BODY = "M30 36 C30 24 39 16 50 16 C61 16 70 24 70 36 L70 80 C70 85 66 88 61 88 L39 88 C34 88 30 85 30 80Z"
MOSS = 'transform="translate(9 31) scale(0.6)"'
OTTO = 'transform="translate(39 27) scale(0.6)"'
INK = '#2B2420'

def svg(name, body):
    open(os.path.join(OUT, 'Assets', name), 'w').write(f'<svg xmlns="http://www.w3.org/2000/svg" {VIEW}>{body}</svg>')

def leaf(x, y, ang, l, w, fill):
    p = f"M0 0 C{l*.25:.2f} {-w*1.15:.2f} {l*.72:.2f} {-w*.9:.2f} {l:.2f} 0 C{l*.72:.2f} {w*.9:.2f} {l*.25:.2f} {w*1.15:.2f} 0 0Z"
    return f'<path d="{p}" fill="{fill}" transform="translate({x} {y}) rotate({ang})"/>'

def painted(path, light, base, deep, foot, gid):
    return (f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{light}"/><stop offset=".55" stop-color="{base}"/>'
            f'<stop offset="1" stop-color="{deep}"/></linearGradient><clipPath id="{gid}c"><path d="{path}"/></clipPath></defs>'
            f'<path d="{path}" fill="url(#{gid})"/><g clip-path="url(#{gid}c)"><rect x="0" y="{foot}" width="100" height="20" fill="#E8C795"/></g>')

os.makedirs(os.path.join(OUT, 'Assets'), exist_ok=True)
for f in os.listdir(os.path.join(OUT, 'Assets')):
    os.remove(os.path.join(OUT, 'Assets', f))

# the rainbow behind them
cols = ['#EF5B4C', '#F58A1F', '#F2B526', '#4DAF4E', '#3E9BE0', '#8E6FDB']
arcs = ''
for i, c in enumerate(cols):
    r = 38 - i * 4.2
    arcs += f'<path d="M{50 - r} 74 A{r} {r} 0 0 1 {50 + r} 74" stroke="{c}" stroke-width="4.4" fill="none"/>'
svg('rainbow.svg', arcs)
# Moss: body, sprout, face looking up at Otto
svg('moss.svg', f'<g {MOSS}>{painted(MOSS_BODY, "#A3D47F", "#6FAE52", "#3F7A34", 80, "m")}</g>')
svg('mint.svg', f'<g {MOSS}><path d="M50 31 C49.5 27 49.8 23.5 50.6 20.5" stroke="#3F9A6E" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
    + leaf(50.6, 21, -150, 14, 5, '#4FC08D') + leaf(50.6, 21, -30, 15.5, 5.4, '#7DD6AC') + '</g>')
svg('moss-face.svg', f'<g {MOSS}><ellipse cx="41.5" cy="55" rx="4.2" ry="5.4" fill="{INK}"/><ellipse cx="61.5" cy="55" rx="4.2" ry="5.4" fill="{INK}"/>'
    f'<circle cx="40.2" cy="52.6" r="1.5" fill="#fff"/><circle cx="60.2" cy="52.6" r="1.5" fill="#fff"/>'
    f'<ellipse cx="30" cy="66" rx="6" ry="3.6" fill="#FF8E8E" fill-opacity=".55"/><ellipse cx="70" cy="66" rx="6" ry="3.6" fill="#FF8E8E" fill-opacity=".55"/>'
    f'<path d="M47 66 Q50 69.5 53 66" stroke="{INK}" stroke-width="1.5" fill="none" stroke-linecap="round"/></g>')
# Otto: body, golden beads, the big eye looking down at Moss
beads = ''.join(f'<circle cx="{34.5 + 31 * t / 4:.2f}" cy="{63 + 5 * math.sin(t / 4 * math.pi):.2f}" r="3.6" fill="#F0B83A"/>' for t in range(5))
svg('otto.svg', f'<g {OTTO}>{painted(OTTO_BODY, "#86AEEF", "#4479D2", "#2A54A3", 81, "o")}</g>')
svg('beads.svg', f'<g {OTTO}><circle cx="50" cy="10.5" r="5.4" fill="#F0B83A"/>{beads}</g>')
svg('otto-face.svg', f'<g {OTTO}><circle cx="50" cy="39" r="11" fill="#FBF7F0"/><circle cx="44.5" cy="43" r="5.6" fill="{INK}"/><circle cx="43" cy="41" r="1.8" fill="#fff"/>'
    f'<ellipse cx="36" cy="53" rx="4.6" ry="2.8" fill="#FF8E8E" fill-opacity=".55"/><ellipse cx="64" cy="53" rx="4.6" ry="2.8" fill="#FF8E8E" fill-opacity=".55"/>'
    f'<path d="M47.5 55 Q50 57.6 52.5 55" stroke="{INK}" stroke-width="1.3" fill="none" stroke-linecap="round"/></g>')

def layer(image, name, glass=True):
    return {"image-name": image, "name": name, "glass": glass, "hidden": False, "position": {"scale": 1, "translation-in-points": [0, 0]}}

def group(layers, translucency):
    return {"layers": layers, "lighting": "individual", "shadow": {"kind": "layer-color", "opacity": 0.5},
            "specular": True, "translucency": {"enabled": True, "value": translucency}, "blur-material": 0.1}

icon = {
    "fill-specializations": [
        {"value": {"linear-gradient": ["display-p3:1.00000,0.97000,0.91000,1.00000", "display-p3:1.00000,0.88500,0.79000,1.00000"]}},
        {"appearance": "dark", "value": "system-dark"},
    ],
    # front first: Moss, then Otto, then the rainbow
    "groups": [
        group([layer('moss-face.svg', 'moss-face', glass=False), layer('mint.svg', 'mint'), layer('moss.svg', 'moss')], 0.2),
        group([layer('otto-face.svg', 'otto-face', glass=False), layer('beads.svg', 'beads'), layer('otto.svg', 'otto')], 0.2),
        group([layer('rainbow.svg', 'rainbow')], 0.3),
    ],
    "supported-platforms": {"squares": ["iOS"]},
}
json.dump(icon, open(os.path.join(OUT, 'icon.json'), 'w'), indent=2)
print('ok', OUT)
