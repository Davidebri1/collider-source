#!/usr/bin/env python3
"""shot.py URL OUT.png [wait_s] [port] [actions-json]: phone shot (390x844 DPR 3).
actions: [["tap",x,y],["long",x,y],["wait",s],["shot","path"],["drag",x1,y1,x2,y2]]"""
import json, sys, time, base64, urllib.request, websocket
url, out = sys.argv[1], sys.argv[2]
wait = float(sys.argv[3]) if len(sys.argv) > 3 else 6
port = int(sys.argv[4]) if len(sys.argv) > 4 else 9556
acts = json.loads(sys.argv[5]) if len(sys.argv) > 5 else []
tab = json.load(urllib.request.urlopen(urllib.request.Request(f"http://127.0.0.1:{port}/json/new?about:blank", method="PUT")))
ws = websocket.create_connection(tab["webSocketDebuggerUrl"], timeout=60, suppress_origin=True)
n = [0]
def cmd(m, p=None):
    n[0] += 1; i = n[0]; ws.send(json.dumps({"id": i, "method": m, "params": p or {}}))
    while True:
        r = json.loads(ws.recv())
        if r.get("id") == i: return r.get("result", r)
cmd("Emulation.setDeviceMetricsOverride", {"width": 390, "height": 844, "deviceScaleFactor": 3, "mobile": True})
cmd("Emulation.setTouchEmulationEnabled", {"enabled": True})
import os
if os.environ.get("CLEAR"):
    from urllib.parse import urlsplit
    u = urlsplit(url); cmd("Storage.clearDataForOrigin", {"origin": f"{u.scheme}://{u.netloc}", "storageTypes": "all"})
cmd("Page.navigate", {"url": url}); time.sleep(wait)
def snap(p): open(p, "wb").write(base64.b64decode(cmd("Page.captureScreenshot", {"format": "png"})["data"]))
def touch(t, x, y): cmd("Input.dispatchTouchEvent", {"type": t, "touchPoints": [] if t == "touchEnd" else [{"x": x, "y": y}]})
for a in acts:
    k = a[0]
    if k == "tap": touch("touchStart", a[1], a[2]); time.sleep(0.08); touch("touchEnd", a[1], a[2]); time.sleep(0.6)
    elif k == "long": touch("touchStart", a[1], a[2]); time.sleep(0.9); touch("touchEnd", a[1], a[2]); time.sleep(0.8)
    elif k == "drag":
        touch("touchStart", a[1], a[2])
        for i in range(1, 11): touch("touchMove", a[1] + (a[3]-a[1])*i/10, a[2] + (a[4]-a[2])*i/10); time.sleep(0.02)
        touch("touchEnd", a[3], a[4]); time.sleep(0.8)
    elif k == "wait": time.sleep(a[1])
    elif k == "shot": snap(a[1])
    elif k == "eval": print(cmd("Runtime.evaluate", {"expression": a[1], "returnByValue": True}).get("result", {}).get("value"))
snap(out)
cmd("Target.closeTarget", {"targetId": tab["id"]}) if False else None
urllib.request.urlopen(f"http://127.0.0.1:{port}/json/close/{tab['id']}")
