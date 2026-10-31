/**
 * Capture vendored smartgen_planka standalone Flutter web at 440×956.
 * Same chrome args as capture_ps_screens.mjs (SwiftShader, no --disable-gpu).
 */
import puppeteer from 'puppeteer-core';
import { createServer } from 'http';
import { readFileSync, existsSync, mkdirSync, writeFileSync, statSync } from 'fs';
import { join, extname } from 'path';

const ROOT = '/workspace/sgrev/v920/collider/packages/smartgen_planka/build/web';
const OUT = '/workspace/sgrev/v920/collider/artifacts/smartgen_planka_captures/ours';
mkdirSync(OUT, { recursive: true });
const PORT = 8931;
const W = 440, H = 956;
const MIME = {
  '.html':'text/html','.js':'application/javascript','.css':'text/css',
  '.json':'application/json','.png':'image/png','.jpg':'image/jpeg',
  '.svg':'image/svg+xml','.wasm':'application/wasm','.otf':'font/otf',
  '.ttf':'font/ttf','.woff':'font/woff','.woff2':'font/woff2',
};

const server = createServer((req, res) => {
  let path = decodeURIComponent((req.url || '/').split('?')[0]);
  if (path === '/planka-dropin' || path === '/planka-dropin/') path = '/';
  if (path.startsWith('/planka-dropin/')) path = path.slice('/planka-dropin'.length);
  if (path === '/') path = '/index.html';
  const file = join(ROOT, path);
  if (!file.startsWith(ROOT) || !existsSync(file) || statSync(file).isDirectory()) {
    res.writeHead(404); res.end('missing ' + path); return;
  }
  res.writeHead(200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  res.end(readFileSync(file));
});
await new Promise((r) => server.listen(PORT, '127.0.0.1', r));
console.log('serving', PORT, ROOT);

const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome', headless: 'new',
  args: ['--no-sandbox','--disable-dev-shm-usage','--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader-webgl','--hide-scrollbars'],
  defaultViewport: { width: W, height: H, deviceScaleFactor: 2 },
});
const page = await browser.newPage();
page.on('console', (m) => {
  const t = m.text();
  if (/Error|Exception|Uncaught|EasyLocalization|Flutter/i.test(t)) console.log('C', t.slice(0, 220));
});
page.on('pageerror', (e) => console.log('PE', String(e).slice(0, 240)));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitPaint(ms = 4500) {
  for (let i = 0; i < 80; i++) {
    const ok = await page.evaluate(() => {
      const g = document.querySelector('flt-glass-pane');
      if (g?.shadowRoot?.querySelector('canvas')) return true;
      if (document.querySelector('canvas')) return true;
      return false;
    });
    if (ok) break;
    await sleep(250);
  }
  await sleep(ms);
}
async function sampleMid() {
  return page.evaluate(async () => {
    const glass = document.querySelector('flt-glass-pane');
    const canvas = glass?.shadowRoot?.querySelector('canvas') || document.querySelector('canvas');
    if (!canvas) return null;
    try {
      const bmp = await createImageBitmap(canvas);
      const full = document.createElement('canvas');
      full.width = canvas.width; full.height = canvas.height;
      const ctx = full.getContext('2d'); ctx.drawImage(bmp, 0, 0);
      return [...ctx.getImageData((full.width / 2) | 0, (full.height / 2) | 0, 1, 1).data];
    } catch (e) { return ['err', String(e)]; }
  });
}
async function shot(name, screen) {
  const url = `http://127.0.0.1:${PORT}/planka-dropin/?sgcap=1&screen=${screen}`;
  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  await waitPaint(screen === 'board' || screen === 'card' ? 5500 : 4000);
  const mid = await sampleMid();
  const path = join(OUT, `${name}.png`);
  await page.screenshot({ path, type: 'png', clip: { x: 0, y: 0, width: W, height: H } });
  console.log('shot', name, 'mid', mid, 'bytes', statSync(path).size);
  return { name, mid, bytes: statSync(path).size };
}

const shots = [
  ['00_home', 'home'],
  ['01_boards', 'boards'],
  ['02_board', 'board'],
  ['03_card_detail', 'card'],
  ['04_board_menu', 'menu'],
  ['05_custom_fields', 'customfields'],
  ['05b_custom_fields_add', 'customfields_add'],
  ['06_search', 'search'],
  ['07_filter', 'filter'],
  ['08_table', 'table'],
  ['09_calendar', 'calendar'],
  ['10_timeline', 'timeline'],
  ['11_cover', 'cover'],
  ['12_labels', 'labels'],
  ['13_freedrag', 'freedrag'],
];

const results = [];
for (const [n, s] of shots) results.push(await shot(n, s));

writeFileSync(join(OUT, 'CAPTURE.json'), JSON.stringify({
  at: new Date().toISOString(),
  viewport: { w: W, h: H, deviceScaleFactor: 2 },
  root: ROOT,
  shots: results,
}, null, 2));

await browser.close();
server.close();
console.log('done');
