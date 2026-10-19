"""Exports the handbook's content into one structured bundle for the native app (content.json).
Source codes like [CDC-06] are lifted out of the text into a `refs` list: sources live in one place in the app."""
import json, re, subprocess, sys, html
S = '/tmp/claude-0/-home-claude/bb80428a-e1ff-57c4-b200-b7ffb2609499/scratchpad/'
OUT = sys.argv[1]
C = json.load(open(S + 'proto/content_fixed.json'))
F = json.load(open(S + 'proto/full_fixed.json'))
TITLES = json.load(open(S + 'proto/titles.json'))
care = json.loads(subprocess.check_output(['node', '-e', "const c=require('./care');const {M}=require('./months');console.log(JSON.stringify({SRC:c.SRC,VAX:c.VAX,VAXNOTE:c.VAXNOTE,CHECK:c.CHECK,CHECKNOTE:c.CHECKNOTE,OTHER:c.OTHER,HEALTH:c.HEALTH,M:M}))"], cwd=S + 'proto').decode())
CODE = re.compile(r'\s*\[([A-Z][A-Za-z0-9]*(?:-[A-Za-z0-9]+)*)\]')


def clean(t):
    if t is None: return "", []
    refs = CODE.findall(t)
    t = CODE.sub('', t)
    t = re.sub(r'\s+([；。，、）])', r'\1', t).strip()
    return t, list(dict.fromkeys(refs))


def cl(t): return clean(t)[0]


def steps(s):
    st = [x.strip() for x in re.split(r'(?<=[；。])', s) if x.strip()]
    if len(st) == 1: st = [x.strip() for x in re.split(r'(?<=[，,])', s) if x.strip()]
    return [re.sub(r'[；。，,]$', '', x) for x in st]


def lo_hi(agedom):
    m = re.search(r'(出生|\d+)\s*[—–\-~]\s*(\d+)', agedom)
    if not m: return 0, 36
    return (0 if m.group(1) == '出生' else int(m.group(1))), int(m.group(2))


# ---------- activities ----------
acts = []
for a in C['acts']:
    age, dom = (a['agedom'].rstrip('。').split('；') + [''])[:2]
    lo, hi = lo_hi(a['agedom'])
    t, refs = clean(a.get('src', ''))
    acts.append({"code": a['code'], "name": a['name'], "age": age.strip(), "domains": [d.strip() for d in re.split(r'[、／/]', dom) if d.strip()], "from": lo, "to": hi,
                 "prepare": cl(a['prep']), "steps": steps(cl(a['steps'])), "observe": cl(a['obs']), "pause": cl(a['stop']), "safety": cl(a['safe']), "refs": refs})
ACT = {a['code']: a for a in acts}

# ---------- what the site shows as this month's three things and the featured activity ----------
site = {}
for m in range(37):
    try: t = open(S + 'site/v/m%d.html' % m).read()
    except Exception: continue
    three = re.findall(r'<li><a href="#m\d+-([^"]+)"><span class="q">([^<]+)</span><span class="a">(.*?)</span><span class="tag">([^<]+)</span>', t)
    feat = re.search(r'<article class="ac feat" id="m\d+-([AN]\d+)"', t)
    site[m] = {"three": [{"kind": q, "text": cl(html.unescape(re.sub(r'<[^>]+>', '', a))), "anchor": h, "tag": tag} for h, q, a, tag in three], "feat": feat.group(1) if feat else None}

DOM = {"A": "语言与沟通", "B": "大运动", "C": "精细动作与认知", "D": "社会情绪与关系", "E": "生活参与与自理", "F": "健康与安全"}
months = []
for x in C['months']:
    m = x['m']; spec = care['M'].get(str(m), {})
    off, r1 = clean(x.get('official', '')); who, r2 = clean(x.get('who', '')); src, r3 = clean(x.get('src', ''))
    doms = []
    for k in "ABCDEF":
        t, r = clean(x.get(k, ''))
        doms.append({"key": k, "name": DOM[k], "text": t, "refs": r})
    cdc = C['cdc'].get(str(m))
    vax = care['VAX'].get(str(m), []); chk = care['CHECK'].get(str(m), []); oth = care['OTHER'].get(str(m), [])
    months.append({
        "month": m, "title": TITLES.get(str(m), ""), "focus": spec.get('focus'),
        "feature": (site.get(m) or {}).get('feat') or spec.get('feat') or (x.get('acts') or [None])[0],
        "highlights": (site.get(m) or {}).get('three', []),
        "official": off, "who": who, "basis": src, "refs": list(dict.fromkeys(r1 + r2 + r3)),
        "domains": doms, "activities": x.get('acts', []),
        "observe": [{"area": k, "items": v} for k, v in (cdc or {}).items()],
        "vaccines": [cl(v) for v in vax], "checkups": [cl(v) for v in chk],
        "notes": [{"topic": a, "text": cl(b), "refs": clean(b)[1]} for a, b in oth],
    })

# ---------- sources, all in one place ----------
sources = []
seen = set()
for r in C['refs']:
    sources.append({"code": r['code'], "org": r['org'], "title": r['title'], "date": r.get('date', ''), "scope": r.get('scope', ''), "url": r.get('url', ''), "checked": r.get('status', '')}); seen.add(r['code'])
for s in care['SRC']:
    if s[0] in seen: continue
    sources.append({"code": s[0], "org": s[1], "title": s[2], "date": s[3], "scope": s[4], "checked": s[5], "url": s[6]}); seen.add(s[0])
for k, u in F.get('urls', {}).items():
    for s in sources:
        if s['code'] == k and not s['url']: s['url'] = u


def blocks(bl):
    out = []
    for b in bl:
        if b['t'] in ('p', 'quote'): out.append({"type": b['t'], "text": cl(b['text'])})
        elif b['t'] == 'ul': out.append({"type": "list", "items": [cl(i) for i in b['items']]})
        elif b['t'] == 'table': out.append({"type": "table", "head": [cl(h) for h in b['head']], "rows": [[cl(c) for c in row] for row in b['rows']]})
    return out


topics = []
for key, title in [("s61", "睡眠、活动与屏幕"), ("s62", "安全睡眠与防跌落"), ("s63", "辅食与回应式喂养"), ("s64", "口腔、屏幕与多种语言"), ("s83", "什么时候要找医生")]:
    topics.append({"id": key, "title": title, "source_title": re.sub(r'^[\d.｜| ]+', '', F[key]['title']), "blocks": blocks(F[key]['blocks'])})
health = [{"topic": a, "text": cl(b), "refs": clean(b)[1]} for a, b in care['HEALTH']]
boards = []
for b in C['boards']:
    boards.append({"title": re.sub(r'^[A-F]｜', '', b['title']), "key": b['title'][0], "rows": [{"age": r['age'], "do": cl(r['step']), "notice": cl(r['obs']).replace('观察：', '')} for r in b['rows']]})
about = {"method": blocks(F['s11']['blocks']) + blocks(F['s12']['blocks']), "confidence": blocks(F['s13']['blocks']), "top": blocks(F['top']),
         "ledger": [{"id": l['id'], "claim": l['claim'], "age": l['age'], "source": l['src'], "level": l['conf'], "checked": l['check'], "limit": l['bound']} for l in C['ledger']],
         "vaccine_note": cl(care['VAXNOTE']), "checkup_note": cl(care['CHECKNOTE'])}
bundle = {"version": 1, "months": months, "activities": acts, "topics": topics, "health": health, "domains": boards, "who": C['who'], "sources": sources, "about": about}
json.dump(bundle, open(OUT, 'w'), ensure_ascii=False, separators=(',', ':'))
print('months', len(months), 'acts', len(acts), 'sources', len(sources), 'topics', len(topics), 'bytes', len(json.dumps(bundle, ensure_ascii=False).encode()))
missing = sorted({c for mo in months for c in mo['activities'] if c not in ACT}); print('missing acts', missing)
print('feature none', [mo['month'] for mo in months if not mo['feature']])
