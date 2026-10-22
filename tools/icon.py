"""Launcher icon, monochrome icon and the animated splash icon: Moss (front, with mint leaves) and Otto (behind),
Otto dangling the golden bead over Moss, who looks up at it. Writes vector drawables into app/src/main/res/."""
import json, os
R = os.path.join(os.path.dirname(__file__), '..', 'app', 'src', 'main', 'res')
INK = '#FF1C1D19'; WHITE = '#FFFBF9F3'
MOSS_BODY = "M22,82 C15,77 13,66 16,56 C19,45 28,36 41,34 C53,32 63,33 72,38 C82,44 88,55 87,67 C86,77 80,84 70,86 C56,88 33,89 22,82Z"
OTTO_BODY = "M30,84 C25,74 24,58 26,44 C28,28 38,16 52,16 C65,17 74,28 75,44 C76,60 74,75 70,84 C60,88 40,88 30,84Z"
OTTO_DIP = "M25.2,64 C35,68 64,68 75.4,63 C75,71 73,78 70,84 C60,88 40,88 30,84 C27.6,78 26,71 25.2,64Z"
MINT = json.load(open(os.path.join(os.path.dirname(__file__), 'mint.json')))

def oval(cx, cy, rx, ry):
    return f"M{cx-rx:.2f},{cy} a{rx},{ry} 0 1,0 {2*rx:.2f},0 a{rx},{ry} 0 1,0 {-2*rx:.2f},0Z"
def rrect(x, y, w, h, r):
    return f"M{x+r},{y} h{w-2*r} a{r},{r} 0 0,1 {r},{r} v{h-2*r} a{r},{r} 0 0,1 {-r},{r} h{-(w-2*r)} a{r},{r} 0 0,1 {-r},{-r} v{-(h-2*r)} a{r},{r} 0 0,1 {r},{-r}Z"
def path(d, fill=None, stroke=None, w=None, alpha=None, name=None):
    a = [f'android:pathData="{d}"']
    if name: a.insert(0, f'android:name="{name}"')
    a.append(f'android:fillColor="{fill or "#00000000"}"')
    if alpha is not None: a.append(f'android:fillAlpha="{alpha}"')
    if stroke:
        a += [f'android:strokeColor="{stroke}"', f'android:strokeWidth="{w}"', 'android:strokeLineCap="round"']
    return '<path ' + ' '.join(a) + ' />'
def group(body, name=None, **t):
    a = [f'android:name="{name}"'] if name else []
    a += [f'android:{k}="{v}"' for k, v in t.items()]
    return f'<group {" ".join(a)}>' + body + '</group>'

def moss(mono=False):
    if mono:
        leaves = path(' '.join(m[0] for m in MINT), '#FFFFFFFF')
        stem = path("M49,36 C48,30 49.2,23 50,17.6", stroke='#FFFFFFFF', w=2.6)
        body = f'<path android:fillColor="#FFFFFFFF" android:fillType="evenOdd" android:pathData="{MOSS_BODY} {oval(43,55,6.4,7.4)} {oval(58,55,6.4,7.4)}" />'
        return stem + group(leaves, 'mint', pivotX='49.6', pivotY='25') + body
    leaves = ''.join(path(m[0], c) for m, c in zip(MINT, ['#FF4FAE7F', '#FF7FCBA0', '#FFA9E0C0', '#FFA9E0C0']))
    # draw order: back leaf first
    leaves = path(MINT[1][0], '#FF7FCBA0') + path(MINT[0][0], '#FF4FAE7F') + path(MINT[3][0], '#FFA9E0C0') + path(MINT[2][0], '#FFA9E0C0')
    veins = path(' '.join(m[1] for m in MINT).replace(' L', ' L'), stroke='#732B6A4A', w=0.6)
    out = path(oval(50, 90.5, 31, 3), INK, alpha='0.09')
    out += path("M49,36 C48,30 49.2,23 50,17.6", stroke='#FF3D5434', w=2.2)
    out += group(leaves + veins, 'mint', pivotX='49.6', pivotY='25')
    out += path(rrect(33, 80, 6.5, 10, 3.2) + ' ' + rrect(59, 80, 6.5, 10, 3.2), INK)
    out += group(path(MOSS_BODY, '#FF3D5434'), translateX='1.4', translateY='1.2')
    out += path(MOSS_BODY, '#FF55704A')
    out += path(oval(43, 55, 6.4, 7.4) + ' ' + oval(58, 55, 6.4, 7.4), WHITE)
    out += path(oval(45.9, 51.4, 4, 4) + ' ' + oval(60.9, 51.4, 4, 4), INK)
    return out

def otto(mono=False):
    stem = "M50,16.5 C47,9 40,5 31,6"
    if mono:
        bead = group(path(stem, stroke='#FFFFFFFF', w=2.6) + path(oval(29.5, 6.4, 5, 5), '#FFFFFFFF'), 'rod', pivotX='50', pivotY='17')
        body = f'<path android:fillColor="#FFFFFFFF" android:fillType="evenOdd" android:pathData="{OTTO_BODY} {oval(51,44,12.5,11.5)}" />'
        return bead + body
    out = path(oval(50, 90.5, 23, 3), INK, alpha='0.09')
    out += group(path(stem, stroke='#FF1F3566', w=2.4) + path(oval(29.5, 6.4, 5, 5), '#FFD4A21C') + path(oval(28, 4.9, 1.5, 1.5), '#FFEDCB6A'),
                 'rod', pivotX='50', pivotY='17')
    out += path(rrect(38, 80, 6.5, 10, 3.2) + ' ' + rrect(56, 80, 6.5, 10, 3.2), INK)
    out += group(path(OTTO_BODY, '#FF1F3566'), translateX='1.4', translateY='1.2')
    out += path(OTTO_BODY, '#FF2D4A8C')
    out += path(OTTO_DIP, '#8C1F3566')
    eye = oval(51, 44, 12.5, 11.5)
    out += path(eye, WHITE)
    out += path(oval(45.0, 48.5, 7.1, 7.1), INK)
    # the heavy upper lid, which also blinks in the splash
    lid = f'<clip-path android:pathData="{eye}" />' + group(path("M38,32 H64 V39.6 H38Z", '#FF2D4A8C'), 'lid', pivotX='51', pivotY='32.5')
    out += group(lid)
    return out

def fg(mono=False):
    o = group(otto(mono), 'otto', translateX='42', translateY='26', scaleX='0.56', scaleY='0.56')
    m = group(group(moss(mono), 'moss_hop'), 'moss', translateX='14', translateY='36', scaleX='0.56', scaleY='0.56')
    return group(o + m, 'pair', pivotX='53.5', pivotY='57.5', scaleX='0.8', scaleY='0.8', translateX='0.5', translateY='-3.5')

def vector(body):
    return ('<?xml version="1.0" encoding="utf-8"?>\n<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">\n'
            + body + '\n</vector>\n')

open(f'{R}/drawable/ic_launcher_foreground.xml', 'w').write(vector(fg()))
open(f'{R}/drawable/ic_launcher_monochrome.xml', 'w').write(vector(fg(True)))
open(f'{R}/drawable/ic_launcher_background.xml', 'w').write(vector(
    path("M0,0 H108 V108 H0Z", '#FFF4F2EC') + path(oval(54, 54, 27, 27), '#FFE3EEDF')))

# Splash (Android 12+): about a second, once. Otto swings the bead over, Moss hops and its mint leaves wave, Otto blinks.
def anim(prop, frames, dur, start=0, interp='@android:interpolator/fast_out_slow_in'):
    vals = list(zip(frames, frames[1:]))
    seq = ''
    step = dur // len(vals)
    for i, (a, b) in enumerate(vals):
        seq += (f'<objectAnimator android:propertyName="{prop}" android:valueFrom="{a}" android:valueTo="{b}" '
                f'android:duration="{step}" android:interpolator="{interp}" />')
    return f'<set android:ordering="sequentially" android:startOffset="{start}">' + seq + '</set>'
def target(name, *sets):
    return (f'<target android:name="{name}"><aapt:attr name="android:animation"><set android:ordering="together">'
            + ''.join(sets) + '</set></aapt:attr></target>')
avd = ('<?xml version="1.0" encoding="utf-8"?>\n<animated-vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
       '    xmlns:aapt="http://schemas.android.com/aapt">\n<aapt:attr name="android:drawable">'
       + vector(fg()).split('?>\n', 1)[1] + '</aapt:attr>\n'
       + target('rod', anim('rotation', [18, -6, 3, 0], 720))
       + target('moss_hop', anim('translateY', [0, -7, 0, -2, 0], 640, 160))
       + target('mint', anim('rotation', [0, 14, -8, 4, 0], 760, 200))
       + target('lid', anim('scaleY', [1, 3.2, 1], 220, 620))
       + '\n</animated-vector>\n')
open(f'{R}/drawable/splash_icon.xml', 'w').write(avd)
print('ok')
