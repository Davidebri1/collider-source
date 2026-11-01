/**
 * Portrait 440x956 — v920l: headless new, --disable-gpu, NO swiftshader.
 * Captures: Account sign-in sheet; Smart Gen board (synced path).
 */
import puppeteer from 'puppeteer-core';
import { createServer } from 'http';
import { readFileSync, existsSync, mkdirSync, writeFileSync, statSync, rmSync } from 'fs';
import { join, extname } from 'path';

const OUT = '/workspace/sgrev/v920/collider/artifacts/account_sync';
mkdirSync(OUT, { recursive: true });
const W = 440, H = 956;
const PORT = 9120; // >= 9100, not 8790/8791
const MIME = {
  '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
  '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.otf': 'font/otf',
  '.ttf': 'font/ttf', '.woff': 'font/woff', '.woff2': 'font/woff2',
};

function serve(root, port) {
  const server = createServer((req, res) => {
    let path = decodeURIComponent((req.url || '/').split('?')[0]);
    for (const base of ['/collider-app']) {
      if (path === base || path === base + '/') path = '/';
      else if (path.startsWith(base + '/')) path = path.slice(base.length);
    }
    if (path === '/') path = '/index.html';
    const file = join(root, path);
    if (!file.startsWith(root) || !existsSync(file) || statSync(file).isDirectory()) {
      res.writeHead(404); res.end('missing ' + path); return;
    }
    res.writeHead(200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(readFileSync(file));
  });
  return new Promise((r) => server.listen(port, '127.0.0.1', () => r(server)));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const root = '/workspace/sgrev/v920/collider/build/web';
  const server = await serve(root, PORT);
  const PROFILE = '/tmp/account_sync_v920l_profile';
  try { rmSync(PROFILE, { recursive: true, force: true }); } catch {}
  mkdirSync(PROFILE, { recursive: true });

  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome',
    headless: 'new',
    userDataDir: PROFILE,
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage', '--hide-scrollbars'],
    defaultViewport: { width: W, height: H, deviceScaleFactor: 1 },
  });
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.log('PE', String(e).slice(0, 240)));

  async function waitPaint(ms = 5000) {
    for (let i = 0; i < 100; i++) {
      const ok = await page.evaluate(() => {
        const g = document.querySelector('flt-glass-pane');
        return !!(g?.shadowRoot?.querySelector('canvas') || document.querySelector('canvas'));
      });
      if (ok) break;
      await sleep(200);
    }
    await sleep(ms);
  }
  async function enableA11y() {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await sleep(800);
  }
  async function shot(name) {
    const path = join(OUT, name);
    await page.screenshot({ path, type: 'png' });
    console.log('wrote', path, statSync(path).size);
  }
  async function clickText(re) {
    const h = await page.evaluateHandle((pattern) => {
      const rx = new RegExp(pattern, 'i');
      const walk = (root) => {
        const nodes = root.querySelectorAll?.('*') || [];
        for (const n of nodes) {
          if (n.shadowRoot) {
            const hit = walk(n.shadowRoot);
            if (hit) return hit;
          }
          const t = (n.innerText || n.textContent || '').trim();
          if (t && rx.test(t) && t.length < 80) return n;
        }
        return null;
      };
      return walk(document);
    }, re.source || re);
    const el = h.asElement();
    if (!el) return false;
    const box = await el.boundingBox();
    if (!box) return false;
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
    await sleep(900);
    return true;
  }

  // Seed Smart Gen board via keeper so "synced" board has content after sign-in sync
  const seedAuth = await fetch('http://127.0.0.1:9103/auth/dev', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'user@collider.app', name: 'Collider' }),
  }).then((r) => r.json());
  const tok = seedAuth.accessToken;
  const planka = {
    users: [], projects: [{ id: 'p1', name: 'Collider', createdAt: new Date().toISOString() }],
    boards: [{ id: 'b1', name: 'Synced board', projectId: 'p1', position: 1, type: 'kanban' }],
    lists: [
      { id: 'l1', boardId: 'b1', name: 'To do', position: 1 },
      { id: 'l2', boardId: 'b1', name: 'Doing', position: 2 },
    ],
    cards: [
      { id: 'c1', listId: 'l1', boardId: 'b1', name: 'From account sync', position: 1 },
    ],
    labels: [], cardLabels: [], tasks: [], comments: [], attachments: [],
    cardMemberships: [], boardMemberships: [], customFieldGroups: [], customFields: [],
    cardCustomFieldValues: [],
  };
  await fetch('http://127.0.0.1:9103/v1/blobs/' + encodeURIComponent('smartgen/planka.json'), {
    method: 'PUT',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/octet-stream', 'X-Updated-At': String(Date.now()) },
    body: Buffer.from(JSON.stringify(planka)),
  });

  // Home
  await page.goto(`http://127.0.0.1:${PORT}/collider-app/?fresh=1`, { waitUntil: 'networkidle0', timeout: 120000 });
  await waitPaint(6000);
  await enableA11y();
  await shot('01_home.png');

  // Open settings → Account (best-effort via a11y text)
  let opened = await clickText(/settings/i);
  console.log('settings click', opened);
  await sleep(1000);
  opened = await clickText(/^account$/i) || await clickText(/account/i);
  console.log('account click', opened);
  await sleep(1200);
  await shot('02_account_signed_out.png');

  opened = await clickText(/^sign in$/i) || await clickText(/sign in/i);
  console.log('sign in click', opened);
  await sleep(800);
  await shot('03_account_sign_in_options.png');

  opened = await clickText(/continue with google/i);
  console.log('google click', opened);
  await sleep(2000);
  await shot('04_account_after_google.png');

  // Smart Gen
  await page.goto(`http://127.0.0.1:${PORT}/collider-app/?app=smartgen&fresh=1`, { waitUntil: 'networkidle0', timeout: 120000 });
  await waitPaint(7000);
  await enableA11y();
  await shot('05_smartgen_board.png');

  writeFileSync(join(OUT, 'capture_log.json'), JSON.stringify({
    ok: true, port: PORT, api: 'http://127.0.0.1:9103', method: 'v920l',
    shots: ['01_home.png','02_account_signed_out.png','03_account_sign_in_options.png','04_account_after_google.png','05_smartgen_board.png'],
  }, null, 2));

  await browser.close();
  server.close();
}

main().catch((e) => { console.error(e); process.exit(1); });
