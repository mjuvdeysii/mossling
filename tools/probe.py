"""Walks the release build on an emulator through every logging path and the main screens with adb + uiautomator,
and reports any crash (the stack from the crash log buffer) as a GitHub annotation. Runs inside emulator.yml."""
import re, subprocess, sys, time, xml.etree.ElementTree as ET

PKG = "app.mossling"
def sh(*a): return subprocess.run(["adb", "shell", *a], capture_output=True, text=True, timeout=60).stdout
def dump():
    for _ in range(3):
        sh("uiautomator", "dump", "/sdcard/ui.xml")
        x = subprocess.run(["adb", "exec-out", "cat", "/sdcard/ui.xml"], capture_output=True, text=True).stdout
        if x.strip().startswith("<?xml"): return ET.fromstring(x)
        time.sleep(1)
    return None

def find(text, exact=True):
    root = dump()
    if root is None: return None
    for n in root.iter("node"):
        t = n.get("text", "") or n.get("content-desc", "")
        if (t == text) if exact else (text in t):
            m = re.findall(r"\d+", n.get("bounds", ""))
            if len(m) == 4: x1, y1, x2, y2 = map(int, m); return ((x1 + x2) // 2, (y1 + y2) // 2)
    return None

crashes = []
def alive(): return sh("pidof", PKG).strip() != ""
def check(step):
    log = subprocess.run(["adb", "logcat", "-b", "crash", "-d"], capture_output=True, text=True).stdout
    if PKG in log or not alive():
        lines = [l for l in log.splitlines() if "AndroidRuntime" in l or "at app.mossling" in l or "Exception" in l or "Error" in l]
        crashes.append((step, "\n".join(lines[:30]) or "process died"))
        subprocess.run(["adb", "logcat", "-b", "crash", "-c"])
        sh("am", "start", "-n", f"{PKG}/.MainActivity"); time.sleep(3)
        return False
    return True

found, missed = [0], []
def tap(text, exact=True, wait=1.2):
    p = find(text, exact)
    if p is None: print(f"  (not found: {text})"); missed.append(text); return False
    found[0] += 1
    sh("input", "tap", str(p[0]), str(p[1])); time.sleep(wait); return True

def back(): sh("input", "keyevent", "4"); time.sleep(1)
def scroll_up(): sh("input", "swipe", "540", "1700", "540", "700", "300"); time.sleep(0.8)

steps = [
    ("first run", lambda: tap("先看看")),
    ("journal on", lambda: tap("我的") and (scroll_up() or True) and tap("手帐") and tap("今天")),
    ("bottle", lambda: tap("瓶喂") and tap("记下来")),
    ("nurse start", lambda: tap("亲喂") and tap("左边")),
    ("nurse stop", lambda: tap("进行中")),
    ("sleep start", lambda: tap("睡觉")),
    ("sleep stop", lambda: tap("进行中")),
    ("diaper", lambda: tap("尿布") and tap("湿")),
    ("journal tab", lambda: tap("手帐")),
    ("solid", lambda: tap("辅食") and tap("米粉") and tap("记下来")),
    ("bath", lambda: tap("洗澡")),
    ("temperature", lambda: tap("体温") and tap("记下来")),
    ("medicine", lambda: tap("用药") and tap("维生素 D") and tap("记下来")),
    ("note", lambda: tap("备注") and (sh("input", "text", "test") or True) and tap("记下来")),
    ("growth sheet", lambda: tap("生长") and (back() or True)),
    ("backfill", lambda: tap("补记") and tap("瓶喂") and tap("记下来")),
    ("open entry", lambda: tap("120 毫升", exact=False) and tap("好")),
    ("statistics", lambda: tap("统计") and (back() or True)),
    ("grow tab", lambda: tap("成长")),
    ("map", lambda: tap("成长地图") and (back() or True)),
    ("shelf", lambda: tap("本周的架子") and (back() or True)),
    ("you tab", lambda: tap("我的")),
    ("about", lambda: (scroll_up() or scroll_up() or True) and tap("关于苔生") and (back() or True)),
]
mode = sys.argv[1] if len(sys.argv) > 1 else "full"
if mode == "old":
    # the previous release: just leave some records behind
    steps = [s for s in steps if s[0] in ("first run", "bottle", "diaper")]
elif mode == "upgraded":
    steps = [("journal still there", lambda: tap("手帐")), ("open entry", lambda: tap("120 毫升", exact=False) and tap("好")),
             ("bottle after update", lambda: tap("瓶喂") and tap("记下来"))] + [s for s in steps if s[0] in ("grow tab", "map", "shelf", "you tab", "about")]
subprocess.run(["adb", "logcat", "-b", "crash", "-c"])
sh("pm", "grant", PKG, "android.permission.POST_NOTIFICATIONS")
sh("am", "start", "-n", f"{PKG}/.MainActivity"); time.sleep(5)
for name, f in steps:
    try: f()
    except Exception as e: print("step error", name, e)
    time.sleep(0.8); ok = check(name); print(("ok   " if ok else "CRASH"), name)
if crashes:
    for step, trace in crashes:
        msg = trace.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
        print(f"::error title=Release crash ({mode}) at {step}::{msg}")
    sys.exit(1)
print(f"::notice title=Release walk ({mode})::no crash · {found[0]} taps found" + (f" · not found: {', '.join(missed)}" if missed else ""))
