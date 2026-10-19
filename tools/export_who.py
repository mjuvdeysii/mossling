"""WHO Child Growth Standards (2006), LMS parameters by completed month 0–36, for weight-for-age, length/height-for-age
and head-circumference-for-age, boys and girls → app/src/main/assets/who_growth.json.
Source tables: tools/who/*.json (the WHO's published expanded tables, as packaged in pygrowup 0.8.2)."""
import json, os
H = os.path.dirname(os.path.abspath(__file__))
out = {"source": "WHO Child Growth Standards (2006)", "unit": {"wfa": "kg", "lhfa": "cm", "hcfa": "cm"}}
for ind in ("wfa", "lhfa", "hcfa"):
    out[ind] = {}
    for sex in ("boys", "girls"):
        rows = json.load(open(os.path.join(H, "who", f"{ind}_{sex}_0_5_zscores.json")))
        by = {}
        for r in rows:
            m = int(float(r["Month"]))
            if m <= 36 and m not in by: by[m] = [float(r["L"]), float(r["M"]), float(r["S"])]
        out[ind][sex] = [by[m] for m in range(37)]
json.dump(out, open(os.path.join(H, "..", "app/src/main/assets/who_growth.json"), "w"), separators=(",", ":"))
print("ok", {k: len(v["boys"]) for k, v in out.items() if isinstance(v, dict) and "boys" in v})
