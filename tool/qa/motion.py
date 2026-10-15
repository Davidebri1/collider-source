#!/usr/bin/env python3
"""motion.py URL NAME [actions-json] [port]: records a phone-sized screencast
(390x844 @3x) around one action, resamples it at 50 ms steps, writes a
contact sheet and judges each transition frame by frame:
  hard_cut  - one 50 ms step carries > 70 % of the whole change
  flash     - a step where mean luma jumps > 25 above both ends (white flash)
  flicker   - the change reverses direction more than twice
actions: [["tap",x,y],["wait",s]] ; recording runs from the first action
for 1.6 s after the last one."""
import json, sys, time, base64, io, threading, urllib.request, websocket
from PIL import Image, ImageStat, ImageChops
url, name = sys.argv[1], sys.argv[2]
acts = json.loads(sys.argv[3]) if len(sys.argv) > 3 else []
port = int(sys.argv[4]) if len(sys.argv) > 4 else 9556
out = '/workspace/collider/release/v91/v917/motion/'
tab = json.load(urllib.request.urlopen(urllib.request.Request(f"http://127.0.0.1:{port}/json/new?about:blank", method="PUT")))
ws = websocket.create_connection(tab["webSocketDebuggerUrl"], timeout=60, suppress_origin=True)
lock = threading.Lock(); n = [0]; pending = {}; frames = []
def reader():
    while True:
        try: r = json.loads(ws.recv())
        except Exception: return
        if r.get("method") == "Page.screencastFrame":
            p = r["params"]; frames.append((p["metadata"]["timestamp"], p["data"]))
            send("Page.screencastFrameAck", {"sessionId": p["sessionId"]}, wait=False)
        elif "id" in r and r["id"] in pending:
            pending[r["id"]].append(r); 
def send(m, p=None, wait=True):
    with lock:
        n[0] += 1; i = n[0]; pending[i] = []
        ws.send(json.dumps({"id": i, "method": m, "params": p or {}}))
    if not wait: return None
    while not pending[i]: time.sleep(0.005)
    return pending.pop(i)[0].get("result")
threading.Thread(target=reader, daemon=True).start()
send("Emulation.setDeviceMetricsOverride", {"width": 390, "height": 844, "deviceScaleFactor": 3, "mobile": True})
send("Emulation.setTouchEmulationEnabled", {"enabled": True})
send("Page.navigate", {"url": url}); time.sleep(14)
def touch(t, x, y): send("Input.dispatchTouchEvent", {"type": t, "touchPoints": [] if t == "touchEnd" else [{"x": x, "y": y}]})
pre = [a for a in acts if a[0] == "pre"]
for a in pre:
    touch("touchStart", a[1], a[2]); time.sleep(0.08); touch("touchEnd", a[1], a[2]); time.sleep(2.5)
send("Page.startScreencast", {"format": "jpeg", "quality": 70, "maxWidth": 390, "maxHeight": 844, "everyNthFrame": 1})
time.sleep(0.6); t_act = None
for a in acts:
    if a[0] == "tap":
        if t_act is None: t_act = time.time()
        touch("touchStart", a[1], a[2]); time.sleep(0.06); touch("touchEnd", a[1], a[2])
    elif a[0] == "wait": time.sleep(a[1])
time.sleep(1.6)
send("Page.stopScreencast"); time.sleep(0.3)
urllib.request.urlopen(f"http://127.0.0.1:{port}/json/close/{tab['id']}")
fr = sorted(frames)
if not fr: print(name, "no frames"); sys.exit(1)
t0 = (t_act or fr[0][0]) - 0.3 if t_act else fr[0][0]
# resample at 50 ms: the latest frame at or before each step
steps = []; t = max(fr[0][0], t0); j = 0
while t <= fr[-1][0] + 1e-6:
    while j + 1 < len(fr) and fr[j + 1][0] <= t: j += 1
    steps.append((round(t - t0, 3), fr[j][1])); t += 0.05
ims = [Image.open(io.BytesIO(base64.b64decode(d))).convert("RGB").resize((130, 281)) for _, d in steps]
lum = [ImageStat.Stat(im.convert("L")).mean[0] for im in ims]
diffs = [ImageStat.Stat(ImageChops.difference(ims[i], ims[i - 1]).convert("L")).mean[0] for i in range(1, len(ims))]
total = sum(diffs) or 1e-9
mx = max(diffs) if diffs else 0
hard = mx / total > 0.7 and mx > 4
flash = any(l > max(lum[0], lum[-1]) + 25 for l in lum)
signs = [1 if lum[i] > lum[i - 1] + 1.5 else (-1 if lum[i] < lum[i - 1] - 1.5 else 0) for i in range(1, len(lum))]
s2 = [s for s in signs if s]; rev = sum(1 for i in range(1, len(s2)) if s2[i] != s2[i - 1])
moving = sum(1 for d in diffs if d > 0.8)
res = {"name": name, "frames_captured": len(fr), "steps_50ms": len(steps), "steps_with_motion": moving,
       "largest_step_share": round(mx / total, 2), "hard_cut": hard, "flash": flash, "flicker_reversals": rev,
       "verdict": "FAIL" if (hard or flash or rev > 2) else "ok"}
cols = 10; rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * 134, rows * 300), "white")
from PIL import ImageDraw
d = ImageDraw.Draw(sheet)
for i, im in enumerate(ims):
    x, y = (i % cols) * 134, (i // cols) * 300
    sheet.paste(im, (x + 2, y + 2)); d.text((x + 4, y + 284), f"{int(steps[i][0]*1000)}ms d={diffs[i-1]:.1f}" if i else "0ms", fill="black")
sheet.save(out + name + ".png")
json.dump(res, open(out + name + ".json", "w"), indent=1)
print(json.dumps(res))
