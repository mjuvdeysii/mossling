"""Draws every illustration in the app from one visual language, so the pictures and the interface read as one thing.

The language: Material 3 Expressive (bold tonal colour fields, the expressive shape set — cookie, clover, pill, arch,
burst, flower — and generous rounding) carried by Montessori material: wooden peg people instead of cartoon
characters, real objects on a work mat, natural wood, the pink tower's pink, the rods' red and blue, the beads' gold.
Faces are left out on purpose: posture, gaze lines and hands say what happens.

Output: app/src/main/assets/art/play_<code>_<n>.webp (one per step), cover_<mm>.webp (one per month), index.json.
Usage: python3 tools/illustrate.py [--sheet out.png]
"""
import io, json, math, os, re, sys
import cairosvg
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app/src/main/assets/art")
C = json.load(open(os.path.join(ROOT, "app/src/main/assets/content.json")))
W, H = 720, 540

# ---------- palette (the app's own) ----------
P = dict(chalk="#F4F2EC", paper="#FBF9F3", linen="#EAE6DC", stone="#D9D4C7", ink="#1C1D19", ink2="#4A4C43",
         moss="#55704A", mossD="#3D5434", sprout="#9DB26F", rod="#2D4A8C", rodL="#4D69AA", bead="#D4A21C", beadL="#EDCB6A",
         wood="#C99B63", woodD="#A77B47", red="#B8382B", pink="#E9AEB8", pinkL="#F6D9DD", sky="#BFD3D6", water="#8FB3BD")
FIELD = {  # family → (tint, deeper tint, expressive shape)
    "Words": ("#DCE3F2", "#C3CFEA", "cookie"), "Hands": ("#E3EBD2", "#CFDDB6", "pill"), "Mind": ("#F6E7B8", "#EFD68A", "clover"),
    "Together": ("#F6DCE0", "#EDC2C9", "flower"), "Senses": ("#D6E7E8", "#BCD7D9", "burst"), "Life": ("#EFE0CB", "#E3CBA9", "arch"),
}

def family(domains):
    d = "、".join(domains)
    if any(k in d for k in ["精细", "手部", "运动", "大运动"]): return "Hands"
    if any(k in d for k in ["因果", "认知", "问题", "记忆", "计划"]): return "Mind"
    if any(k in d for k in ["感知", "视觉"]): return "Senses"
    if any(k in d for k in ["自理", "自主", "生活", "安全", "规则", "调节", "照护"]): return "Life"
    if any(k in d for k in ["语言", "表达", "共读"]): return "Words"
    return "Together"

# ---------- expressive shapes ----------
def polar(cx, cy, r, n, amp, k=180, phase=0.0):
    pts = []
    for i in range(k):
        a = 2 * math.pi * i / k + phase
        rr = r * (1 + amp * math.cos(n * a))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + "Z"

def shape(kind, cx, cy, r):
    if kind == "cookie": return polar(cx, cy, r, 9, 0.055)
    if kind == "clover": return polar(cx, cy, r, 4, 0.14, phase=math.pi / 4)
    if kind == "flower": return polar(cx, cy, r, 6, 0.10)
    if kind == "burst": return polar(cx, cy, r, 12, 0.045)
    if kind == "pill":
        w, h = r * 2.1, r * 1.25; return f"M{cx - w/2 + h/2},{cy - h/2} H{cx + w/2 - h/2} A{h/2},{h/2} 0 0 1 {cx + w/2 - h/2},{cy + h/2} H{cx - w/2 + h/2} A{h/2},{h/2} 0 0 1 {cx - w/2 + h/2},{cy - h/2}Z"
    if kind == "arch":
        w = r * 1.8; return f"M{cx - w/2},{cy + r} V{cy} A{w/2},{w/2} 0 0 1 {cx + w/2},{cy} V{cy + r}Z"
    return polar(cx, cy, r, 0, 0)

# ---------- drawing primitives ----------
class S:
    def __init__(self): self.parts = []
    def add(self, s): self.parts.append(s); return self
    def svg(self, w=W, h=H): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">' + "".join(self.parts) + "</svg>"

def peg(s, x, base, h, body, head="#E8C9A0", lean=0.0, r=None, sit=False):
    """A wooden peg person standing on y=base: rounded body, round head, no face. Returns head centre and shoulder."""
    r = r or max(14, h * 0.15)
    bw = r * 2.3 if not sit else r * 2.6
    top = base - h + r * 2
    t = f'transform="rotate({lean:.1f} {x} {base})"'
    s.add(f'<g {t}>')
    s.add(f'<ellipse cx="{x}" cy="{base + 3}" rx="{bw * 0.7:.1f}" ry="6" fill="{P["ink"]}" opacity=".10"/>')
    s.add(f'<path d="M{x - bw/2},{base} C{x - bw/2},{top + r * 1.2} {x - r * 0.72},{top + r * 0.6} {x - r * 0.62},{top} H{x + r * 0.62} C{x + r * 0.72},{top + r * 0.6} {x + bw/2},{top + r * 1.2} {x + bw/2},{base}Z" fill="{body}"/>')
    s.add(f'<path d="M{x - bw/2 + 4},{base - h * 0.28} H{x + bw/2 - 4}" stroke="#000" stroke-opacity=".08" stroke-width="5" stroke-linecap="round"/>')
    s.add(f'<circle cx="{x}" cy="{top - r * 0.9:.1f}" r="{r:.1f}" fill="{head}"/>')
    s.add(f'<circle cx="{x - r * 0.35:.1f}" cy="{top - r * 1.25:.1f}" r="{r * 0.28:.1f}" fill="#fff" opacity=".35"/>')
    s.add('</g>')
    a = math.radians(lean)
    def rot(px, py): return (x + (px - x) * math.cos(a) - (py - base) * math.sin(a), base + (px - x) * math.sin(a) + (py - base) * math.cos(a))
    return rot(x, top - r * 0.9), rot(x, top + r * 0.7), r

def arm(s, shoulder, hand, color, w=13):
    (x1, y1), (x2, y2) = shoulder, hand
    mx, my = (x1 + x2) / 2, min(y1, y2) - 18
    s.add(f'<path d="M{x1:.1f},{y1:.1f} Q{mx:.1f},{my:.1f} {x2:.1f},{y2:.1f}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round"/>')
    s.add(f'<circle cx="{x2:.1f}" cy="{y2:.1f}" r="{w * 0.75:.1f}" fill="#E8C9A0"/>')

def baby(s, pose, x, base, body, hand_to=None, lean=0):
    """The child, by stage: lie, prone, sit, crawl, stand, walk. Returns (head, shoulder)."""
    head = "#EDD3AE"
    if pose == "lie":
        s.add(f'<ellipse cx="{x}" cy="{base + 2}" rx="78" ry="7" fill="{P["ink"]}" opacity=".10"/>')
        s.add(f'<rect x="{x - 40}" y="{base - 34}" width="104" height="34" rx="17" fill="{body}"/>')
        s.add(f'<circle cx="{x - 58}" cy="{base - 20}" r="22" fill="{head}"/>')
        sh = (x - 20, base - 30)
        if hand_to: arm(s, sh, hand_to, body, 10)
        return (x - 58, base - 20), sh
    if pose == "prone":
        s.add(f'<ellipse cx="{x}" cy="{base + 2}" rx="80" ry="7" fill="{P["ink"]}" opacity=".10"/>')
        s.add(f'<rect x="{x - 30}" y="{base - 30}" width="104" height="30" rx="15" fill="{body}"/>')
        s.add(f'<path d="M{x - 28},{base - 12} L{x - 50},{base}" stroke="{body}" stroke-width="12" stroke-linecap="round"/>')
        s.add(f'<circle cx="{x - 48}" cy="{base - 44}" r="22" fill="{head}"/>')
        return (x - 48, base - 44), (x - 26, base - 22)
    if pose == "crawl":
        s.add(f'<ellipse cx="{x}" cy="{base + 2}" rx="70" ry="7" fill="{P["ink"]}" opacity=".10"/>')
        s.add(f'<path d="M{x - 30},{base - 44} L{x - 40},{base - 4}" stroke="{body}" stroke-width="13" stroke-linecap="round"/>')
        s.add(f'<path d="M{x + 30},{base - 40} L{x + 52},{base - 6} L{x + 72},{base - 6}" fill="none" stroke="{body}" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>')
        s.add(f'<ellipse cx="{x}" cy="{base - 50}" rx="48" ry="21" fill="{body}" transform="rotate(-8 {x} {base - 50})"/>')
        s.add(f'<circle cx="{x - 56}" cy="{base - 70}" r="22" fill="{head}"/>')
        return (x - 56, base - 70), (x - 30, base - 52)
    h = {"sit": 112, "stand": 150, "walk": 150}[pose]
    hd, sh, r = peg(s, x, base, h, body, head, lean=(lean or (-6 if pose == "walk" else 0)), r=21, sit=(pose == "sit"))
    if pose == "walk": s.add(f'<path d="M{x + 10},{base - 6} l18,6" stroke="{body}" stroke-width="12" stroke-linecap="round"/>')
    if hand_to: arm(s, sh, hand_to, body, 11)
    return hd, sh

def adult(s, pose, x, base, body, hand_to=None, lean=0.0, second=None):
    h = {"stand": 300, "kneel": 220, "sit": 205, "hold": 240}[pose]
    if pose in ("kneel", "sit"):
        s.add(f'<rect x="{x - 20}" y="{base - 34}" width="{96 if pose == "kneel" else 110}" height="34" rx="17" fill="{body}"/>')
        s.add(f'<rect x="{x - 20}" y="{base - 34}" width="{96 if pose == "kneel" else 110}" height="12" rx="6" fill="#000" opacity=".06"/>')
    hd, sh, r = peg(s, x, base, h, body, lean=lean, r=30)
    if hand_to: arm(s, sh, hand_to, body, 15)
    if second: arm(s, (sh[0] + 6, sh[1] + 10), second, body, 15)
    return hd, sh

# ---------- objects ----------
def obj(s, kind, x, y, k=1.0, color=None):
    """y is the resting line (bottom) of the object; k scales."""
    g = lambda body: s.add(f'<g transform="translate({x},{y}) scale({k})">{body}</g>')
    c = color
    if kind == "ball": g(f'<ellipse cx="0" cy="3" rx="26" ry="5" fill="#000" opacity=".1"/><circle cx="0" cy="-24" r="24" fill="{c or P["red"]}"/><path d="M-24,-24 A24,24 0 0 0 24,-24" fill="none" stroke="#fff" stroke-opacity=".35" stroke-width="5"/>')
    elif kind == "rattle": g(f'<rect x="-5" y="-30" width="10" height="30" rx="5" fill="{P["wood"]}"/><circle cx="0" cy="-44" r="18" fill="{c or P["bead"]}"/><circle cx="-6" cy="-50" r="5" fill="#fff" opacity=".4"/>')
    elif kind == "book": g(f'<path d="M-62,0 L-62,-56 Q-31,-66 0,-56 Q31,-66 62,-56 L62,0 Q31,-10 0,0 Q-31,-10 -62,0Z" fill="{P["paper"]}" stroke="{P["woodD"]}" stroke-width="3"/><path d="M0,-56 V0" stroke="{P["woodD"]}" stroke-width="3"/><circle cx="-31" cy="-30" r="13" fill="{c or P["rodL"]}"/><rect x="16" y="-42" width="30" height="24" rx="6" fill="{P["bead"]}"/>')
    elif kind == "card": g(f'<rect x="-34" y="-62" width="68" height="62" rx="10" fill="{P["paper"]}" stroke="{P["stone"]}" stroke-width="3"/><circle cx="0" cy="-31" r="16" fill="{c or P["red"]}"/>')
    elif kind == "mirror": g(f'<rect x="-40" y="-8" width="80" height="10" rx="4" fill="{P["woodD"]}"/><circle cx="0" cy="-58" r="50" fill="{P["wood"]}"/><circle cx="0" cy="-58" r="41" fill="{P["sky"]}"/><path d="M-22,-74 L-6,-90 M-20,-58 L4,-82" stroke="#fff" stroke-opacity=".6" stroke-width="5" stroke-linecap="round"/>')
    elif kind == "blocks": g(f'<rect x="-46" y="-36" width="44" height="36" rx="6" fill="{P["red"]}"/><rect x="2" y="-36" width="44" height="36" rx="6" fill="{P["rod"]}"/><rect x="-22" y="-72" width="44" height="36" rx="6" fill="{c or P["bead"]}"/>')
    elif kind == "block": g(f'<rect x="-22" y="-40" width="44" height="40" rx="7" fill="{c or P["rod"]}"/>')
    elif kind == "tower": g("".join(f'<rect x="{-50 + i * 8}" y="{-(i + 1) * 18}" width="{100 - i * 16}" height="18" rx="4" fill="{P["pink"]}" stroke="{P["pinkL"]}" stroke-width="2"/>' for i in range(5)))
    elif kind == "basket": g(f'<path d="M-62,-40 H62 Q58,0 30,0 H-30 Q-58,0 -62,-40Z" fill="#CDAE7A"/><rect x="-66" y="-46" width="132" height="10" rx="5" fill="{P["woodD"]}"/>' + "".join(f'<path d="M{-50 + i * 4},{-28 + i * 9} H{50 - i * 4}" stroke="{P["woodD"]}" stroke-opacity=".35" stroke-width="2"/>' for i in range(3)))
    elif kind == "basketfull": obj(s, "ball", x - 22, y - 34, 0.6 * k); obj(s, "block", x + 24, y - 34, 0.6 * k, P["bead"]); obj(s, "basket", x, y, k)
    elif kind == "cup": g(f'<path d="M-24,-52 H24 L18,0 H-18Z" fill="{c or P["rodL"]}"/><path d="M24,-40 q18,4 0,24" fill="none" stroke="{c or P["rodL"]}" stroke-width="6"/>')
    elif kind == "bowl": g(f'<path d="M-44,-34 H44 Q40,0 0,0 Q-40,0 -44,-34Z" fill="{c or P["paper"]}" stroke="{P["woodD"]}" stroke-width="3"/><rect x="-4" y="-78" width="8" height="40" rx="4" fill="{P["wood"]}" transform="rotate(24)"/>')
    elif kind == "cloth": g(f'<path d="M-50,0 L-40,-22 H46 L54,0Z" fill="{c or P["sprout"]}"/><path d="M-36,-11 H48" stroke="#fff" stroke-opacity=".4" stroke-width="3"/>')
    elif kind == "crayon": g(f'<rect x="-90" y="-14" width="140" height="10" rx="2" fill="{P["paper"]}" stroke="{P["stone"]}" stroke-width="2" transform="skewX(-20)"/><path d="M-60,-40 q30,-30 60,0 t50,-10" fill="none" stroke="{P["red"]}" stroke-width="7" stroke-linecap="round"/><path d="M-40,-24 q24,-16 48,0" fill="none" stroke="{P["rodL"]}" stroke-width="7" stroke-linecap="round"/>')
    elif kind == "paper": g(f'<rect x="-80" y="-12" width="160" height="12" rx="3" fill="{P["paper"]}" stroke="{P["stone"]}" stroke-width="2"/>')
    elif kind == "doll": hd, sh, r = peg(s, x, y, 70 * k, c or P["red"], r=13 * k)
    elif kind == "blanket": g(f'<path d="M-46,-6 Q0,-30 46,-6 L46,0 H-46Z" fill="{P["pinkL"]}"/>')
    elif kind == "pot": g(f'<rect x="-40" y="-44" width="80" height="44" rx="12" fill="{c or P["red"]}"/><rect x="-46" y="-50" width="92" height="10" rx="5" fill="{P["woodD"]}"/><rect x="-6" y="-60" width="12" height="10" rx="4" fill="{P["woodD"]}"/>')
    elif kind == "car": g(f'<rect x="-46" y="-36" width="92" height="26" rx="10" fill="{c or P["rod"]}"/><rect x="-24" y="-56" width="46" height="24" rx="8" fill="{c or P["rod"]}"/><rect x="-16" y="-50" width="30" height="14" rx="4" fill="{P["sky"]}"/><circle cx="-26" cy="-8" r="10" fill="{P["ink"]}"/><circle cx="26" cy="-8" r="10" fill="{P["ink"]}"/>')
    elif kind == "tree": g(f'<rect x="-8" y="-70" width="16" height="70" rx="6" fill="{P["woodD"]}"/><path d="{shape("cookie", 0, -110, 58)}" fill="{P["moss"]}"/><circle cx="-18" cy="-126" r="12" fill="{P["sprout"]}"/>')
    elif kind == "leaf": g(f'<path d="M0,0 C-30,-20 -26,-60 0,-74 C26,-60 30,-20 0,0Z" fill="{c or P["sprout"]}"/><path d="M0,0 V-66" stroke="{P["mossD"]}" stroke-width="3"/>')
    elif kind == "bird": g(f'<path d="M-20,-20 q10,-14 20,0 q10,-14 20,0" fill="none" stroke="{P["ink"]}" stroke-width="5" stroke-linecap="round"/>')
    elif kind == "sun": g(f'<path d="{shape("burst", 0, 0, 34)}" fill="{P["beadL"]}"/><circle cx="0" cy="0" r="22" fill="{P["bead"]}"/>')
    elif kind == "frame": g(f'<rect x="-46" y="-80" width="92" height="80" rx="10" fill="{P["wood"]}"/><rect x="-36" y="-70" width="72" height="60" rx="6" fill="{P["paper"]}"/>' + f'<circle cx="-12" cy="-44" r="9" fill="{P["moss"]}"/><rect x="-21" y="-34" width="18" height="18" rx="7" fill="{P["moss"]}"/><circle cx="12" cy="-46" r="9" fill="{P["red"]}"/><rect x="3" y="-36" width="18" height="20" rx="7" fill="{P["red"]}"/>')
    elif kind == "socks": g(f'<path d="M-40,-60 V-20 Q-40,0 -16,0 H-6 V-16 H-22 V-60Z" fill="{P["red"]}"/><path d="M10,-60 V-20 Q10,0 34,0 H44 V-16 H28 V-60Z" fill="{P["rodL"]}"/>')
    elif kind == "box": g(f'<rect x="-56" y="-44" width="112" height="44" rx="8" fill="{P["wood"]}"/><rect x="-56" y="-44" width="112" height="10" rx="5" fill="{P["woodD"]}"/>')
    elif kind == "notebook": g(f'<rect x="-44" y="-58" width="88" height="58" rx="6" fill="{P["paper"]}" stroke="{P["stone"]}" stroke-width="3"/>' + "".join(f'<path d="M-32,{-44 + i * 12} H{24 - i * 6}" stroke="{P["ink2"]}" stroke-opacity=".4" stroke-width="3" stroke-linecap="round"/>' for i in range(4)) + f'<rect x="40" y="-70" width="8" height="56" rx="3" fill="{P["bead"]}" transform="rotate(20 44 -42)"/>')
    elif kind == "drum": g(f'<rect x="-36" y="-40" width="72" height="40" rx="8" fill="{c or P["red"]}"/><ellipse cx="0" cy="-40" rx="36" ry="9" fill="{P["paper"]}"/><path d="M-30,-70 L-6,-46" stroke="{P["wood"]}" stroke-width="8" stroke-linecap="round"/>')
    elif kind == "cushion": g(f'<rect x="-60" y="-26" width="120" height="26" rx="13" fill="{c or P["sprout"]}"/>')
    elif kind == "cards3": [obj(s, "card", x + dx, y, k * 0.8, cc) for dx, cc in ((-70, P["red"]), (0, P["rodL"]), (70, P["bead"]))]
    elif kind == "clothes": g(f'<path d="M-30,-60 L-50,-44 L-40,-30 L-30,-36 V0 H30 V-36 L40,-30 L50,-44 L30,-60 Q0,-48 -30,-60Z" fill="{c or P["rodL"]}"/>')
    elif kind == "fork": g(f'<path d="M-26,0 L26,0" stroke="{P["stone"]}" stroke-width="4"/>')

def mark(s, kind, a, b=None, color=None):
    """Action marks: speech arcs, sound, a gaze line, motion, a pause, done."""
    col = color or P["ink2"]
    x, y = a
    if kind == "talk":
        for i, rr in enumerate((18, 32, 46)): s.add(f'<path d="M{x + rr * .7:.1f},{y - rr * .7:.1f} A{rr},{rr} 0 0 1 {x + rr * .7:.1f},{y + rr * .7:.1f}" fill="none" stroke="{col}" stroke-opacity="{.75 - i * .2}" stroke-width="5" stroke-linecap="round"/>')
    elif kind == "talkL":
        for i, rr in enumerate((18, 32, 46)): s.add(f'<path d="M{x - rr * .7:.1f},{y - rr * .7:.1f} A{rr},{rr} 0 0 0 {x - rr * .7:.1f},{y + rr * .7:.1f}" fill="none" stroke="{col}" stroke-opacity="{.75 - i * .2}" stroke-width="5" stroke-linecap="round"/>')
    elif kind == "note":
        s.add(f'<g transform="translate({x},{y})"><path d="M0,0 V-34 L22,-40 V-8" fill="none" stroke="{col}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/><circle cx="-6" cy="0" r="7" fill="{col}"/><circle cx="16" cy="-6" r="7" fill="{col}"/></g>')
    elif kind == "look" and b:
        s.add(f'<path d="M{x:.1f},{y:.1f} L{b[0]:.1f},{b[1]:.1f}" stroke="{col}" stroke-opacity=".55" stroke-width="4" stroke-dasharray="2 12" stroke-linecap="round"/>')
    elif kind == "move" and b:
        mx, my = (x + b[0]) / 2, min(y, b[1]) - 46
        s.add(f'<path d="M{x:.1f},{y:.1f} Q{mx:.1f},{my:.1f} {b[0]:.1f},{b[1]:.1f}" fill="none" stroke="{col}" stroke-width="5" stroke-dasharray="12 10" stroke-linecap="round"/>')
        ang = math.atan2(b[1] - my, b[0] - mx)
        for d in (2.5, -2.5): s.add(f'<path d="M{b[0]:.1f},{b[1]:.1f} l{-16 * math.cos(ang + d / 6):.1f},{-16 * math.sin(ang + d / 6):.1f}" stroke="{col}" stroke-width="5" stroke-linecap="round"/>')
    elif kind == "pause":
        for i in range(3): s.add(f'<circle cx="{x + i * 18}" cy="{y}" r="6" fill="{P["bead"]}" opacity="{1 - i * .25}"/>')
    elif kind == "sound":
        for i, rr in enumerate((14, 26, 38)): s.add(f'<path d="M{x - rr:.1f},{y - rr * .3:.1f} Q{x:.1f},{y - rr * 1.2:.1f} {x + rr:.1f},{y - rr * .3:.1f}" fill="none" stroke="{col}" stroke-opacity="{.8 - i * .22}" stroke-width="5" stroke-linecap="round"/>')
    elif kind == "done":
        s.add(f'<g transform="translate({x},{y})"><path d="{shape("cookie", 0, 0, 30)}" fill="{P["moss"]}"/><path d="M-13,0 L-3,10 L15,-10" fill="none" stroke="#fff" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/></g>')
    elif kind == "heart":
        s.add(f'<path transform="translate({x},{y})" d="M0,12 C-26,-6 -16,-30 0,-16 C16,-30 26,-6 0,12Z" fill="{P["pink"]}"/>')
    elif kind == "rest":
        s.add(f'<g transform="translate({x},{y})"><path d="{shape("cookie", 0, 0, 26)}" fill="{P["rodL"]}" opacity=".9"/><path d="M8,-12 A14,14 0 1 0 8,12 A10,10 0 1 1 8,-12Z" fill="{P["paper"]}"/></g>')
    elif kind == "hands":
        s.add(f'<g transform="translate({x},{y})"><circle cx="-12" cy="0" r="14" fill="#E8C9A0"/><circle cx="12" cy="0" r="14" fill="#E8C9A0"/></g>')
    elif kind == "choose" and b:
        s.add(f'<path d="M{x:.1f},{y:.1f} l-30,-30 M{x:.1f},{y:.1f} l30,-30" stroke="{col}" stroke-width="5" stroke-linecap="round" stroke-dasharray="10 8"/>')

# ---------- scene ----------
def ground(s, kind):
    if kind == "mat":
        s.add(f'<rect x="60" y="420" width="600" height="56" rx="20" fill="{P["linen"]}"/><path d="M88,436 H632" stroke="{P["stone"]}" stroke-width="3" stroke-dasharray="1 12" stroke-linecap="round"/>')
        return 446
    if kind == "table":
        s.add(f'<rect x="40" y="470" width="640" height="10" rx="5" fill="{P["stone"]}"/>')
        return 470
    if kind == "outdoor":
        s.add(f'<path d="M0,430 Q180,380 360,420 T720,410 V540 H0Z" fill="#D9E3C4"/>')
        return 470
    if kind == "floor":
        s.add(f'<rect x="40" y="466" width="640" height="10" rx="5" fill="{P["stone"]}"/>')
        return 470
    return 470

def backdrop(s, setting, base, fam):
    """The prepared room behind the work: a low shelf with a few materials, a plant; outdoors, hills and sky."""
    if setting == "outdoor":
        s.add(f'<path d="M0,{base - 70} Q200,{base - 140} 420,{base - 80} T720,{base - 96} V{base} H0Z" fill="#E3EBD2"/>')
        return
    sx = 596 if setting != "table" else 40
    s.add(f'<g opacity=".95" transform="translate({sx} {base}) scale(.82) translate({-sx} {-base})"><rect x="{sx}" y="{base - 120}" width="130" height="10" rx="5" fill="{P["wood"]}"/><rect x="{sx}" y="{base - 60}" width="130" height="10" rx="5" fill="{P["wood"]}"/>'
          f'<rect x="{sx + 4}" y="{base - 120}" width="10" height="120" rx="4" fill="{P["woodD"]}"/><rect x="{sx + 116}" y="{base - 120}" width="10" height="120" rx="4" fill="{P["woodD"]}"/>'
          f'<circle cx="{sx + 40}" cy="{base - 132}" r="12" fill="{P["red"]}"/><rect x="{sx + 66}" y="{base - 146}" width="34" height="26" rx="6" fill="{P["rodL"]}"/>'
          + "".join(f'<rect x="{sx + 26 + k * 6}" y="{base - 72 - k * 0}" width="{60 - k * 12}" height="10" rx="3" fill="{P["pink"]}" transform="translate(0 {-k * 10})"/>' for k in range(4)) + '</g>')
    px = 40 if setting != "table" else 650
    s.add(f'<rect x="{px}" y="{base - 52}" width="44" height="52" rx="10" fill="{P["woodD"]}"/><path d="{shape("clover", px + 22, base - 92, 34)}" fill="{P["moss"]}"/><circle cx="{px + 12}" cy="{base - 104}" r="9" fill="{P["sprout"]}"/>')

def frame(fam, step_index, seed=0):
    tint, deep, kind = FIELD[fam]
    s = S()
    s.add(f'<rect width="{W}" height="{H}" fill="{P["chalk"]}"/>')
    # the expressive field, placed differently on each step so a sequence feels alive but never noisy
    spots = [(420, 250, 250), (300, 240, 240), (380, 230, 265), (460, 260, 240), (340, 250, 250)]
    cx, cy, r = spots[(step_index + seed) % len(spots)]
    s.add(f'<path d="{shape(kind, cx, cy, r)}" fill="{tint}"/>')
    s.add(f'<path d="{shape(kind, cx + r * .72, cy - r * .74, r * .2)}" fill="{deep}"/>')
    return s

ADULT = P["moss"]; ADULT2 = P["rod"]; CHILD = P["bead"]; CHILD2 = P["red"]

def stage_pose(age_from):
    if age_from < 3: return "lie"
    if age_from < 6: return "prone"
    if age_from < 9: return "sit"
    if age_from < 12: return "crawl"
    if age_from < 18: return "stand"
    return "walk"

def action_of(text):
    t = text
    if any(k in t for k in ["结束", "离开", "停止", "疲倦", "累"]): return "rest"
    if any(k in t for k in ["等待", "停顿", "等候", "暂停"]): return "wait"
    if any(k in t for k in ["示范", "演示", "先说明", "成人先"]): return "demo"
    if any(k in t for k in ["自由", "自主", "尝试", "自己", "选择", "愿意", "允许", "让孩子", "孩子"]): return "child"
    if any(k in t for k in ["观察", "看向", "注意", "根据"]): return "look"
    if any(k in t for k in ["说", "描述", "命名", "呼唤", "讲", "念", "唱", "提问", "回应", "介绍", "称呼", "对话"]): return "talk"
    if any(k in t for k in ["记录", "讨论"]): return "note"
    return "together"

# per play: (setting, main object, how the child is placed, extra) — the rest follows from each step's words
PLAY = {
    "N01": ("mat", None, "lie", "talk"), "N02": ("mat", None, "lie", "face"), "N03": ("floor", None, "held", "calm"),
    "N04": ("mat", None, "prone", "lift"), "N05": ("floor", "book", "held", "talk"), "N06": ("table", "notebook", "lie", "note"),
    "A01": ("mat", None, "lie", "talk"), "A02": ("mat", "cloth", "lie", "talk"), "A03": ("mat", None, "prone", "face"),
    "A04": ("mat", "rattle", "lie", "reach"), "A05": ("mat", "rattle", "lie", "sound"), "A06": ("mat", "book", "sit", "point"),
    "A07": ("mat", None, "sit", "song"), "A08": ("mat", "cloth", "sit", "touch"), "A09": ("mat", "mirror", "sit", "mirror"),
    "A10": ("outdoor", "tree", "held", "listen"), "A11": ("mat", "block", "sit", "pass"), "A12": ("mat", None, "sit", "peek"),
    "A13": ("mat", "drum", "sit", "sound"), "A14": ("mat", "basketfull", "sit", "inout"), "A15": ("mat", "ball", "crawl", "explore"),
    "A16": ("floor", "cup", "stand", "point"), "A17": ("floor", None, "stand", "wave"), "A18": ("mat", "ball", "sit", "roll"),
    "A19": ("mat", "blocks", "sit", "stack"), "A20": ("table", "cloth", "stand", "wipe"), "A21": ("floor", "clothes", "stand", "choose"),
    "A22": ("table", "cards3", "stand", "match"), "A23": ("mat", "book", "sit", "point"), "A24": ("table", "crayon", "stand", "draw"),
    "A25": ("mat", "doll", "sit", "care"), "A26": ("floor", None, "stand", "feel"), "A27": ("mat", "basket", "sit", "sort"),
    "A28": ("table", "pot", "stand", "cook"), "A29": ("floor", "cushion", "walk", "path"), "A30": ("floor", None, "walk", "song"),
    "A31": ("floor", None, "stand", "talk"), "A32": ("mat", "blocks", "sit", "peer"), "A33": ("mat", "blocks", "sit", "build"),
    "A34": ("outdoor", "leaf", "walk", "nature"), "A35": ("floor", "socks", "sit", "dress"), "A36": ("table", "cards3", "stand", "order"),
    "A37": ("floor", "book", "stand", "talk"), "A38": ("floor", "frame", "stand", "point"), "A39": ("outdoor", "car", "walk", "road"),
    "A40": ("floor", "frame", "stand", "talk"),
}

def draw_step(play, i, text):
    fam = family(play["domains"])
    setting, thing, child_pose, theme = PLAY.get(play["code"], ("mat", None, stage_pose(play.get("from", 0)), "talk"))
    act = action_of(text)
    s = frame(fam, i, seed=sum(map(ord, play["code"])))
    base = ground(s, setting)
    backdrop(s, setting, base, fam)
    k = {"table": 1.25, "outdoor": 1.3}.get(setting, 1.5)
    s.add(f'<g transform="translate(360 {base}) scale({k}) translate(-360 {-base})">')
    if setting == "table":
        # a low child-height table between the adult and the child, in the same space as the people
        s.add(f'<rect x="270" y="{base - 118}" width="200" height="20" rx="8" fill="{P["wood"]}"/><rect x="288" y="{base - 100}" width="16" height="100" rx="6" fill="{P["woodD"]}"/><rect x="436" y="{base - 100}" width="16" height="100" rx="6" fill="{P["woodD"]}"/>')
    ax, cxp = 250, 468
    # who reaches for what in this step
    obj_at = (340, base)
    child_hand = None; adult_hand = None
    if thing and act in ("child", "together", "look"): child_hand = (obj_at[0] + 20, base - 40)
    if thing and act == "demo": adult_hand = (obj_at[0] - 10, base - 50)
    if theme in ("pass",) and i == 0: adult_hand = (cxp - 60, base - 90)
    if setting == "table":
        # everything happens on the table top: hands go there, not under it
        top = base - 118
        adult_hand = (350, top - 14) if act in ("demo", "talk", "together") or i == 0 else (318, top - 6)
        child_hand = (400, top - 10) if act in ("child", "together", "look") or i > 0 else None
    # the adult
    apose = "kneel" if setting in ("mat",) else ("stand" if setting in ("outdoor",) else "sit" if setting == "floor" and child_pose in ("held",) else "stand")
    if setting == "table": apose = "stand"; ax = 170; cxp = 560
    if theme == "mirror": cxp = 420
    if child_pose == "held":
        hd, sh = adult(s, "hold", ax + 60, base, ADULT)
        # the child in the adult's arms
        s.add(f'<rect x="{ax + 30}" y="{base - 150}" width="96" height="32" rx="16" fill="{CHILD}" transform="rotate(-14 {ax + 78} {base - 134})"/>')
        s.add(f'<circle cx="{ax + 128}" cy="{base - 170}" r="20" fill="#EDD3AE"/>')
        arm(s, (sh[0] - 4, sh[1] + 20), (ax + 112, base - 128), ADULT, 15)
        chead = (ax + 128, base - 170)
        if thing == "book": obj(s, "book", 470, base - 150, 1.1)
        if thing == "tree": obj(s, "tree", 520, base); obj(s, "bird", 470, 150)
    else:
        lean = 8 if act in ("demo", "talk", "together") else 0
        hd, sh = adult(s, apose, ax, base, ADULT, hand_to=adult_hand, lean=lean)
        chead, csh = baby(s, child_pose, cxp, base, CHILD, hand_to=child_hand)
        if thing and thing not in ("tree", "frame", "mirror", "cushion", "car"):
            sx_, sy_ = (370, base - 150) if setting == "table" and thing in ("cards3", "crayon", "pot", "cloth") else (obj_at[0], base - 34)
            s.add(f'<path d="{shape("flower" if fam != "Together" else "cookie", sx_, sy_, 62)}" fill="{FIELD[fam][1]}"/>')
        if thing and thing not in ("tree",):
            if setting == "table" and thing in ("cards3", "crayon", "pot", "cloth"):
                obj(s, thing, 370, base - 118, 0.85)
            elif thing in ("mirror",): obj(s, "mirror", 540, base)
            elif thing == "frame": obj(s, "frame", 340, base - 120)
            elif thing == "cushion": obj(s, "cushion", 360, base); obj(s, "cushion", 560, base, 0.8, P["rodL"])
            elif thing == "car": obj(s, "car", 360, base)
            else: obj(s, thing, *obj_at)
        if thing == "tree" or theme == "nature": obj(s, "tree", 580, base, 0.9); obj(s, "sun", 560, base - 300, 0.8)
        if theme == "road": s.add(f'<rect x="60" y="{base - 6}" width="600" height="6" fill="{P["stone"]}"/>' + "".join(f'<rect x="{90 + k * 90}" y="{base + 14}" width="50" height="8" rx="4" fill="{P["paper"]}"/>' for k in range(6)))
        if theme == "peer": baby(s, "sit", 620, base, CHILD2)
        if theme == "mirror": mark(s, "look", (chead[0] + 18, chead[1]), (530, base - 60))
    # the step's own sign
    talk_from = (hd[0] + 40, hd[1])
    if act == "talk" or theme in ("talk",) and act == "together": mark(s, "talk", talk_from)
    elif act == "wait": mark(s, "pause", (hd[0] + 50, hd[1] - 30)); mark(s, "talkL", (chead[0] - 34, chead[1]), color=P["rodL"])
    elif act == "look": mark(s, "look", (hd[0] + 26, hd[1] + 4), (chead[0] - 20, chead[1]))
    elif act == "rest": mark(s, "rest", (chead[0] + 40, chead[1] - 60))
    elif act == "note": obj(s, "notebook", 370 if setting == "table" else 560, base - 118 if setting == "table" else base)
    elif act == "child" and not thing: mark(s, "talkL", (chead[0] - 30, chead[1]), color=P["rodL"])
    elif act == "demo" and not thing: mark(s, "hands", (hd[0] + 70, hd[1] + 60))
    # theme accents
    if theme == "song" and act in ("demo", "talk", "together", "child"): mark(s, "note", (hd[0] + 70, hd[1] - 10), color=P["rod"]); mark(s, "note", (chead[0] + 30, chead[1] - 60), color=P["red"])
    if theme == "sound" and act in ("child", "together", "look", "demo"): mark(s, "sound", (obj_at[0], base - 90))
    if theme == "roll" and act in ("child", "together", "wait"): mark(s, "move", (obj_at[0] + 30, base - 60), (cxp - 60, base - 40))
    if theme == "peek" and act in ("demo", "together"): mark(s, "hands", (hd[0], hd[1]))
    if theme == "calm": mark(s, "heart", (hd[0] + 70, hd[1] - 40))
    if theme == "listen": mark(s, "sound", (480, 210))
    s.add('</g>')
    if i == len(play["steps"]) - 1 and act not in ("rest",): mark(s, "done", (656, 64))
    return s.svg()

def cover(m, mo):
    feature = next((a for a in C["activities"] if a["code"] == mo.get("feature")), None)
    fam = family(feature["domains"]) if feature else "Words"
    tint, deep, kind = FIELD[fam]
    s = S(); w, h = 840, 450
    s.add(f'<rect width="{w}" height="{h}" fill="{P["chalk"]}"/>')
    s.add(f'<path d="{shape(kind, 560, 210, 220)}" fill="{tint}"/>')
    s.add(f'<path d="{shape("cookie", 150, 110, 70)}" fill="{deep}" opacity=".7"/>')
    # a bead chain of the months walked so far, along the top
    for k in range(37):
        x = 40 + k * 21; on = k < m; here = k == m
        s.add(f'<circle cx="{x}" cy="40" r="{9 if here else 6}" fill="{P["bead"] if on else (P["moss"] if here else P["stone"])}"/>')
    base = 380
    s.add(f'<rect x="80" y="{base - 6}" width="680" height="48" rx="20" fill="{P["linen"]}"/>')
    pose = stage_pose(m)
    s.add(f'<g transform="translate(420 {base}) scale(1.35) translate(-420 {-base})">')
    s.add(f'<path d="{shape("flower", 400, base - 34, 60)}" fill="{deep}"/>')
    adult(s, "kneel", 260, base, ADULT, hand_to=(392, base - 70) if m >= 6 else None, lean=6)
    baby(s, pose, 540, base, CHILD)
    thing = PLAY.get(mo.get("feature") or "", (None, None))[1]
    if thing and thing not in ("tree",): obj(s, thing, 400, base, 0.9)
    elif m >= 18: obj(s, "tower", 690, base, 0.9)
    else: obj(s, "rattle", 400, base)
    s.add('</g>')
    return s.svg(w, h)

def render(svg, path, width):
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=width)
    im = Image.open(io.BytesIO(png)).convert("RGB")
    # flat shapes: lossless keeps every edge as sharp as the interface around it
    im.save(path, "WEBP", lossless=True, quality=100, method=6)
    return im.size

def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".webp"): os.remove(os.path.join(OUT, f))
    index = {"plays": {}, "covers": {}, "size": {}}
    for p in C["activities"]:
        names = []
        for i, t in enumerate(p["steps"]):
            n = f"play_{p['code'].lower()}_{i + 1}.webp"
            index["size"][n] = list(render(draw_step(p, i, t), os.path.join(OUT, n), 1440)); names.append(n)
        index["plays"][p["code"]] = names
    for mo in C["months"]:
        n = "cover_%02d.webp" % mo["month"]
        index["size"][n] = list(render(cover(mo["month"], mo), os.path.join(OUT, n), 1440))
        index["covers"][str(mo["month"])] = n
    json.dump(index, open(os.path.join(OUT, "index.json"), "w"), separators=(",", ":"))
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print("steps", sum(len(v) for v in index["plays"].values()), "covers", len(index["covers"]), "bytes", total)
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        pick = [n for v in list(index["plays"].values())[::4] for n in v][:24] + [index["covers"][k] for k in ("0", "6", "12", "24")]
        ims = [Image.open(os.path.join(OUT, n)).resize((360, 270)) for n in pick]
        cols = 6; rows = (len(ims) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * 360, rows * 270), "white")
        for k, im in enumerate(ims): sheet.paste(im, ((k % cols) * 360, (k // cols) * 270))
        sheet.save(out)

if __name__ == "__main__":
    main()
