/**
 * v920l Account UI recapture — 440x956, headless new, --disable-gpu, no swiftshader.
 * Ports >= 9100; never 8790/8791.
 */
import puppeteer from 'puppeteer-core';
import { createServer } from 'http';
import { readFileSync, existsSync, mkdirSync, writeFileSync, statSync, rmSync } from 'fs';
import { join, extname } from 'path';
import { execSync } from 'child_process';

const ROOT = '/workspace/sgrev/v920/account-sync';
const OUT = join(ROOT, 'artifacts/account_sync');
const WEB = join(ROOT, 'build/web');
mkdirSync(OUT, { recursive: true });
const W = 440, H = 956, PORT = 9128;
const MIME = {
  '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
  '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.otf': 'font/otf',
  '.ttf': 'font/ttf', '.woff': 'font/woff', '.woff2': 'font/woff2',
};
function serve(root, port) {
  const server = createServer((req, res) => {
    let path = decodeURIComponent((req.url || '/').split('?')[0]);
    if (path.startsWith('/collider-app')) path = path.slice('/collider-app'.length) || '/';
    if (path === '/') path = '/index.html';
    const file = join(root, path);
    if (!existsSync(file) || statSync(file).isDirectory()) { res.writeHead(404); res.end('missing'); return; }
    res.writeHead(200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(readFileSync(file));
  });
  return new Promise((r) => server.listen(port, '127.0.0.1', () => r(server)));
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
try { execSync('fuser -k ' + PORT + '/tcp', { stdio: 'ignore' }); } catch {}

const server = await serve(WEB, PORT);
const PROFILE = '/tmp/as_account_ui';
rmSync(PROFILE, { recursive: true, force: true });
mkdirSync(PROFILE, { recursive: true });
const browser = await puppeteer.launch({
  executablePath: '/usr/bin/google-chrome',
  headless: 'new',
  userDataDir: PROFILE,
  args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage', '--hide-scrollbars'],
  defaultViewport: { width: W, height: H, deviceScaleFactor: 1 },
});
const page = await browser.newPage();
page.on('pageerror', (e) => console.log('PE', String(e).slice(0, 200)));

async function waitPaint(ms = 6000) {
  for (let i = 0; i < 100; i++) {
    const ok = await page.evaluate(() => !!(document.querySelector('flt-glass-pane')?.shadowRoot?.querySelector('canvas') || document.querySelector('canvas')));
    if (ok) break;
    await sleep(200);
  }
  await sleep(ms);
}
async function a11y() {
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await sleep(900);
}
async function shot(name) {
  const p = join(OUT, name);
  await page.screenshot({ path: p, type: 'png' });
  console.log('wrote', name, statSync(p).size);
}
async function texts() {
  return page.evaluate(() => {
    const out = [];
    const walk = (r) => {
      for (const n of r.querySelectorAll?.('*') || []) {
        if (n.shadowRoot) walk(n.shadowRoot);
        const t = (n.innerText || n.textContent || '').trim();
        if (t && t.length < 120) out.push(t);
      }
    };
    walk(document);
    return [...new Set(out)].slice(0, 80);
  });
}
async function clickIncludes(sub, preferSmall = true) {
  const box = await page.evaluate((sub, preferSmall) => {
    let best = null;
    const walk = (r) => {
      for (const n of r.querySelectorAll?.('*') || []) {
        if (n.shadowRoot) walk(n.shadowRoot);
        const t = (n.innerText || n.textContent || '').trim();
        if (!t.includes(sub) || t.length > 80) continue;
        const b = n.getBoundingClientRect?.();
        if (!b || b.width < 8 || b.height < 8) continue;
        const area = b.width * b.height;
        if (!best || (preferSmall ? area < best.area : area > best.area)) {
          best = { x: b.x + b.width / 2, y: b.y + Math.min(28, b.height / 2), t, w: b.width, h: b.height, area };
        }
      }
    };
    walk(document);
    return best;
  }, sub, preferSmall);
  console.log('click', sub, box);
  if (!box) return false;
  await page.mouse.click(box.x, box.y);
  await sleep(1800);
  return true;
}

await page.goto(`http://127.0.0.1:${PORT}/collider-app/`, { waitUntil: 'networkidle0', timeout: 120000 });
await waitPaint(5000);
await a11y();
await shot('01_home.png');

// Open Settings (sliders FAB bottom)
const settingsHit = await page.evaluate(() => {
  // Prefer bottom FAB area: settings is left of apps grid
  return { x: 190, y: 900 };
});
await page.mouse.click(settingsHit.x, settingsHit.y);
await sleep(2500);
await a11y();
console.log('settings texts', await texts());
await shot('02_settings.png');

await clickIncludes('Account');
await sleep(2000);
await a11y();
console.log('account signed-out texts', await texts());
await shot('04_sign_in_options.png');
await shot('03_account.png');

// Continue with Google (local DEV_AUTH via keeper)
await clickIncludes('Continue with Google');
await sleep(3000);
await a11y();
console.log('after google', await texts());
await shot('05_account_signed_in.png');
await shot('04_account_after_google.png');

writeFileSync(join(OUT, 'capture_log.json'), JSON.stringify({ ok: true, at: new Date().toISOString() }, null, 2));
await browser.close();
server.close();
