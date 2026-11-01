#!/usr/bin/env python3
"""Capture Smart Gen canvas gaps at 440x956 via headless Chrome (Playwright). Port != 8790/8791."""
from __future__ import annotations

import http.server
import json
import os
import socketserver
import threading
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path('/workspace/sgrev/v920/canvas')
WEB = ROOT / 'build/web'
OUT = ROOT / 'artifacts/canvas_gaps'
OUT.mkdir(parents=True, exist_ok=True)
W, H, PORT = 440, 956, 9144
BASE = f'http://127.0.0.1:{PORT}/collider-app/'

MIME = {
    '.html': 'text/html',
    '.js': 'application/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.wasm': 'application/wasm',
    '.otf': 'font/otf',
    '.ttf': 'font/ttf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(WEB), **k)

    def translate_path(self, path: str) -> str:
        path = path.split('?', 1)[0]
        if path.startswith('/collider-app'):
            path = path[len('/collider-app'):] or '/'
        if path in ('', '/'):
            path = '/index.html'
        return super().translate_path(path)

    def log_message(self, fmt, *args):
        pass


def serve():
    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(('127.0.0.1', PORT), Handler)
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()
    return httpd


def wait_paint(page, ms=6000):
    for _ in range(80):
        ok = page.evaluate(
            """() => !!(document.querySelector('flt-glass-pane')?.shadowRoot?.querySelector('canvas')
              || document.querySelector('canvas'))"""
        )
        if ok:
            break
        page.wait_for_timeout(200)
    page.wait_for_timeout(ms)


def a11y(page):
    page.evaluate("""() => document.querySelector('flt-semantics-placeholder')?.click()""")
    page.wait_for_timeout(900)


def texts(page):
    return page.evaluate(
        """() => {
          const out = [];
          const walk = (r) => {
            for (const n of r.querySelectorAll?.('*') || []) {
              if (n.shadowRoot) walk(n.shadowRoot);
              const t = (n.innerText || n.textContent || '').trim();
              if (t && t.length < 160) out.push(t);
            }
          };
          walk(document);
          return [...new Set(out)].slice(0, 100);
        }"""
    )


def shot(page, name, log):
    path = OUT / name
    page.screenshot(path=str(path), type='png')
    words = texts(page)
    meta = {'file': name, 'words': words, 'bytes': path.stat().st_size}
    (OUT / (name.replace('.png', '.meta.json'))).write_text(json.dumps(meta, indent=2))
    log.append(meta)
    print('wrote', name, path.stat().st_size, 'words', len(words))
    print('  sample:', words[:12])
    return words


def goto(page, qs: str):
    page.goto(BASE + '?' + qs, wait_until='networkidle', timeout=120000)
    wait_paint(page, 5000)
    a11y(page)


def main():
    os.system(f'fuser -k {PORT}/tcp >/dev/null 2>&1')
    httpd = serve()
    log = []
    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path='/usr/bin/google-chrome',
            headless=True,
            args=['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage', '--hide-scrollbars'],
        )
        context = browser.new_context(
            viewport={'width': W, 'height': H},
            device_scale_factor=1,
        )
        page = context.new_page()
        page.on('pageerror', lambda e: print('PE', str(e)[:200]))

        # 1) Board tiles of different kinds (centred SettingsGlassPane window)
        goto(page, 'app=smartgen&cap=1&fresh=1&sg=canvas&boardtiles=1')
        shot(page, '01_board_tiles.png', log)

        # 2a) Scene applied behind the grid (free alley still — ThemeCatalog R2 id)
        goto(page, 'app=smartgen&cap=1&fresh=1&sg=canvas&boardtiles=1&bg=r2-free/alley3.jpg')
        page.wait_for_timeout(4500)  # ThemeCatalog + poster decode
        a11y(page)
        shot(page, '01b_scene_applied.png', log)

        # 2b) Background picker open — scenes first, de-duped; navy tint selected
        goto(page, 'app=smartgen&cap=1&fresh=1&sg=canvas&canvases=1&pickbg=1&bg=tint:1A2838')
        page.wait_for_timeout(4000)
        a11y(page)
        shot(page, '02_background_picker.png', log)

        # 3) Real throw via Playwright mouse: down → fast multi-step move → up.
        # Frames: at release, mid-glide, settled. Card must end past release point.
        # dx0/dy0 park Thrown in a clear upper slot; siblings stay low via scatter.
        goto(page, 'app=smartgen&cap=1&fresh=1&sg=canvas&canvases=1&scatter=1&c1=Thrown&c2=Beta&c3=Gamma&dx0=28&dy0=72')
        page.wait_for_timeout(900)
        a11y(page)
        box = page.evaluate("""() => {
          let best = null;
          const walk = (r) => {
            for (const n of r.querySelectorAll?.('*') || []) {
              if (n.shadowRoot) walk(n.shadowRoot);
              const t = (n.innerText || n.textContent || '').trim();
              if (t !== 'Thrown' && !t.startsWith('Thrown')) continue;
              const b = n.getBoundingClientRect?.();
              if (!b || b.width < 20 || b.height < 20) continue;
              const area = b.width * b.height;
              if (!best || area < best.area) {
                best = { x: b.x + b.width/2, y: b.y + b.height/2, w: b.width, h: b.height, area };
              }
            }
          };
          walk(document);
          return best;
        }""")
        print('Thrown card box', box)
        if not box:
            raise SystemExit('Thrown card not found for throw gesture')
        sx, sy = box['x'], box['y']
        page.mouse.move(sx, sy)
        page.mouse.down()
        page.wait_for_timeout(30)
        # Fast flick down-right: many single-step hops so Flutter sees high velocity.
        # Distance kept inside the canvas so chrome does not steal the gesture.
        hops = [
            (sx + 30, sy + 18),
            (sx + 70, sy + 40),
            (sx + 120, sy + 70),
            (sx + 180, sy + 105),
            (sx + 250, sy + 145),
            (sx + 320, sy + 190),
        ]
        for hx, hy in hops:
            page.mouse.move(hx, hy, steps=1)
        release = hops[-1]
        page.mouse.up()
        page.wait_for_timeout(30)
        shot(page, '03_throw_1_grab.png', log)  # at release
        page.wait_for_timeout(180)
        shot(page, '03_throw_2_mid.png', log)   # mid-glide
        page.wait_for_timeout(750)  # spring settle (~700ms controller)
        shot(page, '03_throw_3_glide.png', log) # settled — fully inside pane
        after = page.evaluate("""() => {
          let best = null;
          const walk = (r) => {
            for (const n of r.querySelectorAll?.('*') || []) {
              if (n.shadowRoot) walk(n.shadowRoot);
              const t = (n.innerText || n.textContent || '').trim();
              if (!t.includes('Thrown')) continue;
              const b = n.getBoundingClientRect?.();
              if (!b || b.width < 20 || b.height < 20) continue;
              const area = b.width * b.height;
              if (!best || area < best.area) {
                best = { x: b.x + b.width/2, y: b.y + b.height/2,
                         left: b.x, top: b.y, right: b.x + b.width, bottom: b.y + b.height, area };
              }
            }
          };
          walk(document);
          return best;
        }""")
        # Pane bounds via Sprint header / canvas chrome — use flt glass content approx.
        pane = page.evaluate("""() => {
          // SettingsGlassPane is centred ~0.82 width; find densest dark rect mid-screen.
          return { left: 40, top: 80, right: 400, bottom: 820, w: 360, h: 740 };
        }""")
        print('Thrown after', after, 'release', release, 'pane', pane)
        if after:
            dist = ((after['x'] - release[0])**2 + (after['y'] - release[1])**2) ** 0.5
            start_dist = ((after['x'] - sx)**2 + (after['y'] - sy)**2) ** 0.5
            print('dist from release', dist, 'dist from start', start_dist)
            if start_dist < 40:
                print('WARNING: card barely moved — gesture may still be stolen')
            # Must clear canvasEdgePad (24) from the glass frame on every side.
            edge = 24
            tol = 3
            if (after['left'] < pane['left'] + edge - tol or after['right'] > pane['right'] - edge + tol
                    or after['top'] < pane['top'] + edge - tol or after['bottom'] > pane['bottom'] - edge + tol):
                print('WARNING: Thrown card missing edge inset', after, pane, 'need', edge)
            else:
                print('Thrown card inset', edge, 'px from pane frame')
            if dist < 8:
                print('WARNING: card did not travel past release — throw velocity may be low')

        # 4) Genie open over canvas
        goto(page, 'app=smartgen&cap=1&fresh=1&sg=canvas&canvases=1&boardtiles=1&genie=1')
        shot(page, '04_genie_open.png', log)

        # 5) Genie minimised
        goto(page, 'app=smartgen&cap=1&fresh=1&sg=canvas&canvases=1&boardtiles=1&geniemin=1')
        shot(page, '05_genie_minimised.png', log)

        browser.close()
    httpd.shutdown()
    (OUT / 'capture_log.json').write_text(json.dumps(log, indent=2))
    print('done', OUT)


if __name__ == '__main__':
    main()
