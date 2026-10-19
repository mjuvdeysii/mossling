// Moss & Otto — geometry in a 100×100 box, shared 1:1 with the Kotlin Canvas drawing (ui/ip/Creatures.kt).
// Deadpan picture-book characters: flat matte shapes, no outlines, small eyes that glance, a second
// layer slightly off-register for a printed feel. Expression lives in the eyes, not in smiles.
const P = {
  ink: "#1C1D19", paper: "#F4F2EC", white: "#FBF9F3",
  moss: "#55704A", mossDeep: "#3D5434", mossLight: "#88A06C", sprout: "#9DB26F",
  otto: "#2D4A8C", ottoDeep: "#1F3566", ottoLight: "#4D69AA", gold: "#D4A21C", goldLight: "#EDCB6A",
};
const f = (n) => +n.toFixed(2);
// an almond-ish eye: white, pupil that can sit anywhere inside, optional heavy lid in body colour
function eye(cx, cy, rx, ry, o, body) {
  const mood = o.mood || "open", [lx, ly] = o.look || [0, 0];
  if (mood === "sleep") return `<path d="M${f(cx - rx)} ${f(cy)}Q${cx} ${f(cy + ry * 0.9)} ${f(cx + rx)} ${f(cy)}" fill="none" stroke="${P.ink}" stroke-width="${f(Math.max(1.6, ry * 0.32))}" stroke-linecap="round"/>`;
  if (mood === "happy") return `<path d="M${f(cx - rx)} ${f(cy + ry * 0.35)}Q${cx} ${f(cy - ry * 0.9)} ${f(cx + rx)} ${f(cy + ry * 0.35)}" fill="none" stroke="${P.ink}" stroke-width="${f(Math.max(1.6, ry * 0.34))}" stroke-linecap="round"/>`;
  const pr = Math.min(rx, ry) * (mood === "wow" ? 0.5 : 0.62);
  const px = cx + lx * (rx - pr - 0.3), py = cy + ly * (ry - pr - 0.3);
  let s = `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${P.white}"/>`;
  s += `<circle cx="${f(px)}" cy="${f(py)}" r="${f(pr)}" fill="${P.ink}"/>`;
  const lid = o.lid == null ? 0 : o.lid; // 0 open … 1 shut
  if (lid > 0) s += `<rect x="${f(cx - rx - 0.6)}" y="${f(cy - ry - 0.6)}" width="${f(rx * 2 + 1.2)}" height="${f((ry * 2 + 1.2) * lid)}" fill="${body}"/>`;
  return s;
}
// Moss — a soft mossy boulder with a sprout. Two eyes, set close; it watches.
function moss(o = {}) {
  let s = `<ellipse cx="51" cy="90.5" rx="31" ry="3" fill="${P.ink}" opacity=".09"/>`;
  s += `<path d="M47 36 C46 29 47 23 50 18" fill="none" stroke="${P.mossDeep}" stroke-width="2.2" stroke-linecap="round"/>`;
  s += `<path d="M50 19 C52 11 60 8 65 10 C62 17 55 21 50 19Z" fill="${P.sprout}"/>`;
  s += `<path d="M48.5 25 C45 20 38 19 35 21 C38 26 44 28 48.5 25Z" fill="${P.mossLight}"/>`;
  s += `<rect x="33" y="80" width="6.5" height="10" rx="3.2" fill="${P.ink}"/><rect x="59" y="80" width="6.5" height="10" rx="3.2" fill="${P.ink}"/>`;
  const body = "M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z";
  s += `<path d="${body}" fill="${P.mossDeep}" transform="translate(1.4 1.2)"/><path d="${body}" fill="${P.moss}"/>`;
  // moss texture: a few soft tufts, lighter, low contrast
  s += `<path d="M24 52 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M64 44 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M70 72 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M28 72 c2 -2 5 -2 7 0 c-2 1.6 -5 1.6 -7 0Z" fill="${P.mossLight}" opacity=".7"/>`;
  s += eye(43, 55, 6.4, 7.4, o, P.moss) + eye(58, 55, 6.4, 7.4, o, P.moss);
  if (o.mood === "wow") s += `<ellipse cx="50.5" cy="68" rx="2.2" ry="2.8" fill="${P.ink}"/>`;
  return `<g transform="rotate(${o.lean || 0} 50 88)">${s}</g>`;
}
// Otto — tall and a little lopsided, one big eye under a heavy lid; it concentrates. Holds a golden bead.
function otto(o = {}) {
  let s = `<ellipse cx="50" cy="90.5" rx="23" ry="3" fill="${P.ink}" opacity=".09"/>`;
  s += `<path d="M53 17 C54 12 57 8 61 6" fill="none" stroke="${P.ottoDeep}" stroke-width="2.2" stroke-linecap="round"/><circle cx="62" cy="5.8" r="3.2" fill="${P.gold}"/>`;
  s += `<rect x="38" y="80" width="6.5" height="10" rx="3.2" fill="${P.ink}"/><rect x="56" y="80" width="6.5" height="10" rx="3.2" fill="${P.ink}"/>`;
  const body = "M30 84 C25 74 24 58 26 44 C28 28 38 16 52 16 C65 17 74 28 75 44 C76 60 74 75 70 84 C60 88 40 88 30 84Z";
  s += `<path d="${body}" fill="${P.ottoDeep}" transform="translate(1.4 1.2)"/><path d="${body}" fill="${P.otto}"/>`;
  // dipped in ink: the lower third a shade darker
  s += `<path d="M25.2 64 C35 68 64 68 75.4 63 C75 71 73 78 70 84 C60 88 40 88 30 84 C27.6 78 26 71 25.2 64Z" fill="${P.ottoDeep}" opacity=".55"/>`;
  const lid = o.lid == null ? 0.34 : o.lid;
  s += eye(51, 44, 12.5, 11.5, Object.assign({}, o, { lid }), P.otto);
  if (o.bead !== false) s += `<circle cx="74" cy="70" r="6.2" fill="${P.gold}"/><circle cx="72.2" cy="68" r="1.8" fill="${P.goldLight}"/>`;
  if (o.mood === "wow") s += `<ellipse cx="51" cy="64" rx="2.2" ry="2.8" fill="${P.ink}"/>`;
  return `<g transform="rotate(${o.lean || 0} 50 88)">${s}</g>`;
}
const svg = (inner, w = 100, h = 100, vb = "0 0 100 100") => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb}" width="${w}" height="${h}">${inner}</svg>`;
module.exports = { P, moss, otto, svg };
