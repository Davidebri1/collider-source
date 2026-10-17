#!/usr/bin/env python3
"""Sets every live (video) theme on Home in turn and flags black, frozen,
streaked or soft results.

Needs a QA build (--dart-define=COLLIDER_QA_UNLOCK=true): there the team owns
every theme and ?qa_theme=<id> performs the same state change as tapping
"Set as wallpaper". The live build ignores ?qa_theme.

Usage: set_wallpaper_check.py [base_url] [cdp_port] [out_dir] [name_filter,...]
Phone: 390x844 CSS px, DPR 3. Shots at 1 s, 4 s and 15 s per theme.

Verdicts per theme
- not_set:  the Home <video> isn't playing this theme's file
- black:    wallpaper area mean luma < 14 at 4 s and 15 s
- frozen:   video.currentTime never moves (4 s, 15 s, 4 samples after)
- streaked: the browser reports corrupted frames, or ffmpeg finds decode
            errors in the first 12 s of the source
- soft:     the source is upscaled more than 2.0x to cover the phone
            (2532 device px tall); `soft_dupe` when a sharper copy of the
            same clip exists in the list
"""
import base64, io, json, os, re, subprocess, sys, time, urllib.parse, urllib.request
import numpy as np, websocket
from PIL import Image

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8092/collider-app/"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 9555
OUT = sys.argv[3] if len(sys.argv) > 3 else "/workspace/collider/release/v91/v917/setwall"
ONLY = sys.argv[4].split(",") if len(sys.argv) > 4 and sys.argv[4] and not sys.argv[4].startswith("--") else None
LIST = "https://collider-themes.ebridavid.workers.dev/"
os.makedirs(OUT, exist_ok=True)
W, H, DPR = 390, 844, 3
SHOTS = (1, 4, 15)

items = json.load(urllib.request.urlopen(urllib.request.Request(LIST, headers={"User-Agent": "Mozilla/5.0 collider-qa"}), timeout=30))
vids = [o for o in items if re.search(r"\.(mp4|webm|mov)$", o["name"], re.I) and not o["name"].startswith(("posters/", "thumbs/"))]
# Themes the app hides on purpose (qa/blocked-themes.json) are not set again;
# they are reported as "blocked" so the list stays complete.
BLOCKED = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "blocked-themes.json")))["blocked"] if os.path.exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), "blocked-themes.json")) else {}
blocked_rows = [{"name": o["name"], "flags": ["blocked"], "why": BLOCKED[o["name"]]} for o in vids if o["name"] in BLOCKED]
if "--include-blocked" not in sys.argv: vids = [o for o in vids if o["name"] not in BLOCKED]
if ONLY: vids = [o for o in vids if any(k.lower() in o["name"].lower() for k in ONLY)]

def stem(n):  # "0_Reflection_Lake_1280x720 (1).mp4" -> "0_reflection_lake"
    s = re.sub(r"\.(mp4|webm|mov)$", "", n, flags=re.I)
    s = re.sub(r"\s*\(\d+\)|\s*-\s*copy", "", s, flags=re.I)
    return re.sub(r"_?\d{3,4}x\d{3,4}", "", s).strip().lower()

tab = json.load(urllib.request.urlopen(urllib.request.Request(f"http://127.0.0.1:{PORT}/json/new?about:blank", method="PUT"), timeout=10))
ws = websocket.create_connection(tab["webSocketDebuggerUrl"], timeout=60, suppress_origin=True)
n = [0]
def cmd(m, p=None):
    n[0] += 1; i = n[0]; ws.send(json.dumps({"id": i, "method": m, "params": p or {}}))
    while True:
        r = json.loads(ws.recv())
        if r.get("id") == i: return r.get("result", r)
cmd("Page.enable"); cmd("Runtime.enable")
cmd("Emulation.setDeviceMetricsOverride", {"width": W, "height": H, "deviceScaleFactor": DPR, "mobile": True})
cmd("Emulation.setTouchEmulationEnabled", {"enabled": True})

def shot(path):
    d = base64.b64decode(cmd("Page.captureScreenshot", {"format": "png"})["data"])
    open(path, "wb").write(d)
    return Image.open(io.BytesIO(d)).convert("L")

def region(img):  # wallpaper area above the ticker, right of the rail
    a = np.asarray(img, dtype=np.float32)
    return a[int(70 * DPR):int(430 * DPR), int(70 * DPR):int(380 * DPR)]

def vstate():
    js = """JSON.stringify([...document.querySelectorAll('video')].map(v=>({src:decodeURIComponent(v.currentSrc||v.src||''),t:v.currentTime,w:v.videoWidth,h:v.videoHeight,rs:v.readyState,p:!v.paused,
      c:(v.getVideoPlaybackQuality?v.getVideoPlaybackQuality().corruptedVideoFrames:0),d:(v.getVideoPlaybackQuality?v.getVideoPlaybackQuality().totalVideoFrames:0)})))"""
    r = cmd("Runtime.evaluate", {"expression": js, "returnByValue": True})
    try: return json.loads(r["result"]["value"])
    except Exception: return []

def ffmpeg_errors(url):
    """Decode errors in the first 12 s of the source, read from a complete local
    copy (decoding over HTTP reports dropped connections as decode errors)."""
    tmp = "/tmp/swc_" + re.sub(r"[^A-Za-z0-9]+", "_", url[-60:]) + ".bin"
    try:
        for _ in range(3):
            if subprocess.run(["curl", "-fsSL", "--retry", "3", "-o", tmp, url], timeout=600).returncode == 0: break
        else:
            return ["download failed"]
        p = subprocess.run(["ffmpeg", "-v", "error", "-t", "12", "-i", tmp, "-f", "null", "-"], capture_output=True, text=True, timeout=300)
        return [l for l in p.stderr.splitlines() if l.strip()][:5]
    except Exception as e:
        return [f"ffmpeg failed: {e}"]
    finally:
        if os.path.exists(tmp): os.remove(tmp)

best = {}
for o in vids:
    v = None
    m = re.search(r"(\d{3,4})x(\d{3,4})", o["name"])
    if m: v = int(m.group(1)) * int(m.group(2))
    k = stem(o["name"])
    if v and v > best.get(k, 0): best[k] = v

from concurrent.futures import ThreadPoolExecutor
pool = ThreadPoolExecutor(4)
fut = {o['name']: pool.submit(ffmpeg_errors, o['url']) for o in vids}
results = []
for idx, o in enumerate(vids):
    name = o["name"]; tid = "r2-" + name
    safe = re.sub(r"[^A-Za-z0-9]+", "_", name)[:60]
    url = BASE + "?qa_theme=" + urllib.parse.quote(tid, safe="")
    cmd("Page.navigate", {"url": url}); t0 = time.time()
    imgs = {}; states = {}
    for s in SHOTS:
        time.sleep(max(0, s - (time.time() - t0)))
        imgs[s] = shot(f"{OUT}/{safe}_{s:02d}s.png"); states[s] = vstate()
    def mine(st):
        for v in st:
            if v["src"].endswith(name) or urllib.parse.unquote(v["src"]).endswith(name): return v
        return None
    extra = []
    for _ in range(4):
        time.sleep(0.5); extra.append(mine(vstate()))
    v4, v15 = mine(states[4]), mine(states[15])
    ts = [x["t"] for x in [v4, v15] + extra if x]
    flags = []
    if not v15: flags.append("not_set")
    l4, l15 = float(region(imgs[4]).mean()), float(region(imgs[15]).mean())
    if l4 < 14 and l15 < 14: flags.append("black")
    # frozen: the playhead never moves across 4 s, 15 s and four samples after
    if v15 and len(set(round(t, 3) for t in ts)) == 1: flags.append("frozen")
    diff = float(np.abs(region(imgs[4]) - region(imgs[15])).mean())
    errs = None  # filled in after the loop (decoded in parallel)
    if v15 and v15["c"] > 0: flags.append("streaked")
    vw, vh = (v15["w"], v15["h"]) if v15 else (0, 0)
    up = None
    if vw and vh:
        # cover 1170x2532: scale = max(1170/vw, 2532/vh)
        up = round(max(W * DPR / vw, H * DPR / vh), 2)
        if up > 2.0:
            m = re.search(r"(\d{3,4})x(\d{3,4})", name)
            dupe = m and best.get(stem(name), 0) > int(m.group(1)) * int(m.group(2))
            flags.append("soft_dupe" if dupe else "soft")
    r = {"name": name, "id": tid, "flags": flags, "luma4": round(l4, 1), "luma15": round(l15, 1), "diff4_15": round(diff, 2),
         "video": v15, "times": [round(t, 2) for t in ts], "upscale": up, "ffmpeg_errors": errs, "shots": [f"{safe}_{s:02d}s.png" for s in SHOTS]}
    results.append(r)
    print(f"[{idx+1}/{len(vids)}] {name}: {','.join(flags) or 'ok'} luma={l15:.0f} up={up} t={v15 and round(v15['t'],1)}", flush=True)
    json.dump(results + blocked_rows, open(f"{OUT}/report.json", "w"), indent=1)
print(f"{len(blocked_rows)} themes hidden by the app (qa/blocked-themes.json), not set again")
for r in results:
    r["ffmpeg_errors"] = fut[r["name"]].result()
    if r["ffmpeg_errors"] and "streaked" not in r["flags"]: r["flags"].append("streaked")
json.dump(results + blocked_rows, open(f"{OUT}/report.json", "w"), indent=1)
print(f"{len(blocked_rows)} themes hidden by the app (qa/blocked-themes.json), not set again")
for r in results: print(f"{r['name']}: {','.join(r['flags']) or 'ok'}")
bad = [r for r in results if set(r["flags"]) & {"not_set", "black", "frozen", "streaked"}]
print(f"\n{len(results)} themes set; {len(bad)} broken; {sum('soft' in r['flags'] for r in results)} soft; {sum('soft_dupe' in r['flags'] for r in results)} soft with a sharper copy")
sys.exit(1 if bad else 0)
