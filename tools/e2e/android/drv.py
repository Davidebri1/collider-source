"""Drive Collider on an Android emulator over adb: screenshots, OCR, taps in
dp (the AVD is 1320x2868 px at 480 dpi = 440x956 dp), text input, and the
Flutter/WebView accessibility tree via uiautomator."""
import json, os, re, subprocess, time
from PIL import Image

ADB = os.environ.get('ADB', '/home/box/sdk/android/platform-tools/adb')
SERIAL = os.environ.get('SERIAL', 'emulator-5580')
SCALE = float(os.environ.get("SCALE", "1.0"))  # px per dp (AVD 440x956 px @160dpi = 440x956 dp)
OUT = os.environ.get('OUT', '/workspace/native/e2e')
PKG = 'com.collider.collider_flutter'
os.makedirs(OUT, exist_ok=True)
_ocr = None


def adb(*a, check=True, timeout=120):
    r = subprocess.run([ADB, '-s', SERIAL, *a], capture_output=True, timeout=timeout)
    if check and r.returncode != 0:
        raise RuntimeError(f'adb {a}: {r.stderr.decode(errors="replace")[:300]}')
    return r.stdout


def sh(cmd, **k):
    return adb('shell', cmd, **k).decode(errors='replace')


def shot(name):
    """Full-resolution screenshot plus a 440x956 copy; returns the 440 path."""
    full = os.path.join(OUT, 'full', name + '.png')
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, 'wb').write(adb('exec-out', 'screencap', '-p'))
    small = os.path.join(OUT, name + '.png')
    Image.open(full).convert('RGB').resize((440, 956), Image.LANCZOS).save(small)
    return small


def ocr(name):
    """OCR the full-res screenshot; boxes are returned in dp."""
    global _ocr
    if _ocr is None:
        from rapidocr_onnxruntime import RapidOCR
        _ocr = (RapidOCR(), RapidOCR(text_score=0.2, box_thresh=0.3))
    path = shot(name)
    full = os.path.join(OUT, 'full', name + '.png')
    lines, boxes = [], []
    for e in _ocr:
        res, _ = e(full)
        for box, text, _s in (res or []):
            if text in lines:
                continue
            lines.append(text)
            xs = [p[0] for p in box]; ys = [p[1] for p in box]
            boxes.append((text, sum(xs) / 4 / SCALE, sum(ys) / 4 / SCALE))
    return lines, boxes


def squash(s):
    return re.sub(r'\s+', '', s).lower()


def find(boxes, text, region=None):
    t = squash(text)
    for b in boxes:
        if t in squash(b[0]):
            if region and not (region[0] <= b[1] <= region[2] and region[1] <= b[2] <= region[3]):
                continue
            return b
    return None


def tap(x, y, pause=1.2):
    sh(f'input tap {int(x * SCALE)} {int(y * SCALE)}')
    time.sleep(pause)


def swipe(x1, y1, x2, y2, ms=300):
    sh(f'input swipe {int(x1*SCALE)} {int(y1*SCALE)} {int(x2*SCALE)} {int(y2*SCALE)} {ms}')


def type_text(s):
    # input text needs spaces as %s and shell metachars escaped
    esc = s.replace(' ', '%s')
    esc = re.sub(r'([\\"\'`$&|;<>()?*!#])', r'\\\1', esc)
    sh(f'input text "{esc}"')


def key(k):
    sh(f'input keyevent {k}')


def tree():
    """uiautomator dump -> list of (text/desc, cx_dp, cy_dp, cls)."""
    sh('uiautomator dump /sdcard/ui.xml', check=False, timeout=60)
    xml = adb('exec-out', 'cat', '/sdcard/ui.xml', check=False).decode(errors='replace')
    out = []
    for m in re.finditer(r'<node [^>]*>', xml):
        n = m.group(0)
        g = lambda a: (re.search(a + r'="([^"]*)"', n) or [None, ''])[1]
        lab = g('text') or g('content-desc')
        b = re.findall(r'\d+', g('bounds'))
        if not b:
            continue
        x1, y1, x2, y2 = map(int, b)
        out.append((lab, (x1 + x2) / 2 / SCALE, (y1 + y2) / 2 / SCALE, g('class')))
    return out


def tfind(nodes, label, exact=False):
    for n in nodes:
        if (n[0] == label) if exact else (label.lower() in n[0].lower()):
            return n
    return None


def launch(clear=False):
    if clear:
        sh(f'pm clear {PKG}')
    sh(f'am force-stop {PKG}')
    sh(f'monkey -p {PKG} -c android.intent.category.LAUNCHER 1', check=False)
