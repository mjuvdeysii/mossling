"""Maps the web handbook's tick keys (hb:rec, e.g. "6:c7az543", "6:aA11", "6:v0") to the native app's keys
("6:c:0-0", "6:a:A11", "6:v:0"), by matching each item's text. Run after export_content.py."""
import json, re, html, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = os.path.join(ROOT, 'app/src/main/assets/site/v')
OUT = os.path.join(ROOT, 'native/app/src/main/assets/legacy_map.json')
C = json.load(open(os.path.join(ROOT, 'native/app/src/main/assets/content.json')))
norm = lambda t: re.sub(r'[\s。．.，,；;：:（）()、]', '', html.unescape(re.sub(r'<[^>]+>', '', t)))
out, miss = {}, []
for mo in C['months']:
    m = mo['month']; f = os.path.join(SITE, 'm%d.html' % m)
    if not os.path.exists(f): continue
    page = open(f).read()
    native = {}
    for gi, g in enumerate(mo['observe']):
        for ii, t in enumerate(g['items']): native.setdefault(norm(t), '%d:c:%d-%d' % (m, gi, ii))
    for k, label in re.findall(r'data-mk="([^"]+)"><label[^>]*><span>(.*?)</span>', page):
        mm, rest = k.split(':', 1)
        if rest[0] == 'c':
            n = native.get(norm(label))
            if n: out[k] = n
            else: miss.append((k, label))
        elif rest[0] == 'a': out[k] = '%s:a:%s' % (mm, rest[1:])
        elif rest[0] in 'vk': out[k] = '%s:%s:%s' % (mm, rest[0], rest[1:])
json.dump(out, open(OUT, 'w'), ensure_ascii=False, separators=(',', ':'))
print('mapped', len(out), 'unmatched', len(miss)); [print(' ', *x) for x in miss[:20]]
