// Browser acceptance for Smart Gen objects and a few whole-app screens.
// Serves BUILD (default build/web) and drives headless Chrome at 440x956 CSS, scale 2.
// Writes PNGs and report.json under OUT (default /tmp/accept).
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, createWriteStream } from 'node:fs';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = process.env.BUILD || 'build/web';
const OUT = process.env.OUT || '/tmp/accept';
const PORT = Number(process.env.PORT || 8765);
const CHROME = process.env.CHROME || 'google-chrome';
mkdirSync(OUT, { recursive: true });

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.json': 'application/json', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.wasm': 'application/wasm', '.ttf': 'font/ttf',
  '.otf': 'font/otf', '.svg': 'image/svg+xml',
};

const server = createServer(async (req, res) => {
  let path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  if (path.startsWith('/collider-app')) path = path.slice('/collider-app'.length) || '/';
  if (path.endsWith('/')) path += 'index.html';
  const file = normalize(join(ROOT, path));
  if (!file.startsWith(normalize(ROOT))) {
    res.writeHead(403);
    res.end();
    return;
  }
  try {
    const buf = await readFile(file);
    res.writeHead(200, { 'content-type': types[extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
    res.end(buf);
  } catch {
    res.writeHead(404);
    res.end('missing');
  }
});
await new Promise((r) => server.listen(PORT, '127.0.0.1', r));

const chrome = spawn(CHROME, [
  '--headless=new', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
  `--window-size=440,956`, '--force-device-scale-factor=2',
  '--remote-debugging-port=9223', `--user-data-dir=${OUT}/chrome-profile`,
  'about:blank',
], { stdio: 'ignore' });

async function json(url) {
  const res = await fetch(url);
  return res.json();
}
let wsUrl = '';
for (let i = 0; i < 40 && !wsUrl; i++) {
  try {
    const tabs = await json('http://127.0.0.1:9223/json/list');
    wsUrl = tabs.find((t) => t.type === 'page')?.webSocketDebuggerUrl || '';
  } catch { /* chrome still starting */ }
  if (!wsUrl) await new Promise((r) => setTimeout(r, 250));
}
if (!wsUrl) throw new Error('chrome debugger did not start');

const ws = new WebSocket(wsUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let seq = 0;
const pending = new Map();
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) pending.get(msg.id)(msg);
});
function send(method, params = {}, sessionId) {
  const id = ++seq;
  const body = { id, method, params };
  if (sessionId) body.sessionId = sessionId;
  ws.send(JSON.stringify(body));
  return new Promise((resolve) => pending.set(id, (msg) => {
    pending.delete(id);
    resolve(msg);
  }));
}
const target = await send('Target.getTargets');
const page = (target.result?.targetInfos || []).find((t) => t.type === 'page');
const attached = await send('Target.attachToTarget', { targetId: page.targetId, flatten: true });
const sessionId = attached.result.sessionId;
const cdp = (method, params) => send(method, params, sessionId);
await cdp('Page.enable');
await cdp('Runtime.enable');
const logs = [];
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.method === 'Runtime.consoleAPICalled') {
    const text = (msg.params.args || []).map((a) => a.value ?? a.description ?? '').join(' ');
    logs.push(text);
  }
});

async function go(query) {
  await cdp('Page.navigate', { url: `http://127.0.0.1:${PORT}/collider-app/${query}` });
  await new Promise((r) => setTimeout(r, 8000));
  await cdp('Runtime.evaluate', { expression: `document.querySelector('flt-semantics-placeholder')?.click()`, awaitPromise: true });
  await new Promise((r) => setTimeout(r, 1500));
}
async function evalJson(expression) {
  const res = await cdp('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  return res.result?.result?.value;
}
async function labels() {
  return await evalJson(`JSON.stringify([...document.querySelectorAll('[aria-label]')].map(e => e.getAttribute('aria-label')).filter(Boolean).slice(0, 80))`) || '[]';
}
async function shot(name) {
  const { result } = await cdp('Page.captureScreenshot', { format: 'png' });
  const buf = Buffer.from(result.data, 'base64');
  writeFileSync(join(OUT, name), buf);
  return buf.length;
}
async function locate(text) {
  return await evalJson(`(() => {
    const want = ${JSON.stringify(text)};
    const nodes = [...document.querySelectorAll('[aria-label]')].filter(e => {
      const a = (e.getAttribute('aria-label') || '').replace(/\\s+/g, ' ').trim();
      return a === want || a.startsWith(want + ' ');
    });
    if (!nodes.length) return null;
    nodes.sort((a, b) => b.getBoundingClientRect().y - a.getBoundingClientRect().y);
    const el = nodes[0];
    const r = el.getBoundingClientRect();
    return JSON.stringify({x:r.x + r.width/2, y:r.y + r.height/2, w:r.width, h:r.height, top:r.y});
  })()`);
}
async function clickLabel(text) {
  const raw = await locate(text);
  if (!raw) return 'missing:' + text;
  const p = JSON.parse(raw);
  await cdp('Input.dispatchMouseEvent', { type: 'mouseMoved', x: p.x, y: p.y });
  await cdp('Input.dispatchMouseEvent', { type: 'mousePressed', x: p.x, y: p.y, button: 'left', clickCount: 1 });
  await cdp('Input.dispatchMouseEvent', { type: 'mouseReleased', x: p.x, y: p.y, button: 'left', clickCount: 1 });
  return 'clicked';
}
async function box(text) {
  return await evalJson(`(() => {
    const el = [...document.querySelectorAll('[aria-label]')].find(e => (e.getAttribute('aria-label')||'').includes(${JSON.stringify(text)}));
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return JSON.stringify({x:r.x,y:r.y,w:r.width,h:r.height});
  })()`);
}
async function pointerDrag(from, to) {
  const a = JSON.parse(from);
  const b = JSON.parse(to);
  const x1 = a.x + a.w / 2, y1 = a.y + Math.min(a.h / 2, 30);
  const x2 = b.x + b.w / 2, y2 = b.y + Math.min(b.h / 2, 40);
  await cdp('Input.dispatchMouseEvent', { type: 'mousePressed', x: x1, y: y1, button: 'left', clickCount: 1 });
  await new Promise((r) => setTimeout(r, 400));
  for (let i = 1; i <= 8; i++) {
    await cdp('Input.dispatchMouseEvent', { type: 'mouseMoved', x: x1 + (x2 - x1) * i / 8, y: y1 + (y2 - y1) * i / 8, button: 'left' });
    await new Promise((r) => setTimeout(r, 40));
  }
  await cdp('Input.dispatchMouseEvent', { type: 'mouseReleased', x: x2, y: y2, button: 'left', clickCount: 1 });
  await new Promise((r) => setTimeout(r, 800));
}

const report = { shots: [], actions: [], console: [] };
const boardKinds = [
  'Desk', 'Table', 'Wood Long Table', 'Wood Coffee Table', 'Long wood bench', 'Wood round table',
  'Wood Night Stand', 'Workbench', 'Whiteboard empty', 'Whiteboard with swim lanes',
  'White board without swim lanes', 'Calendar', 'Kanban Board with Swim lanes',
  'Various Different Charts and diagrams',
];
const canvases = [
  'Glass', 'Mirror', 'Swimlane vertical', 'Swimlane horizontal', 'Name Photo Description',
  'Portfolio', 'Notebook', 'Collection', 'Folder', 'Gallery', 'Diary', 'Journal',
  'Kanban Board widget', 'Table', 'Calendar Widget', 'Chart',
];

await go('?app=smartgen&sg=canvas&cap=1&fresh=1');
report.actions.push({ step: 'boot', labels: await labels() });
await shot('00-boot.png');

// One card, then each board kind with that card still on the desk.
await clickLabel('Board menu');
await new Promise((r) => setTimeout(r, 2000));
await clickLabel('New card');
await new Promise((r) => setTimeout(r, 1500));
report.actions.push({ step: 'new-card-menu', clickNote: await clickLabel('Note') });
await new Promise((r) => setTimeout(r, 800));
await clickLabel('Back');
await new Promise((r) => setTimeout(r, 400));

let menuLogged = false;
for (const kind of boardKinds) {
  const menu = await clickLabel('Board menu');
  await new Promise((r) => setTimeout(r, 2000));
  if (!menuLogged) {
    report.actions.push({ step: 'menu-open', menu, labels: await labels() });
    await shot('menu-open.png');
    menuLogged = true;
  }
  const clicked = await clickLabel(kind);
  const closed = await clickLabel('Close Board menu');
  report.actions.push({ step: 'kind', kind, clicked, closed });
  if (!String(await labels()).includes('Board menu')) {
    await go('?app=smartgen&sg=canvas&cap=1');
  }
  await new Promise((r) => setTimeout(r, 500));
  const file = `board-${kind.replaceAll(' ', '_')}.png`;
  const n = await shot(file);
  report.shots.push({ kind, file, bytes: n, clicked });
}

// Canvas types, one at a time so the 10-canvas cap is not hit. Each gets the Note if it lands on the new canvas.
for (const kind of canvases) {
  await clickLabel('Board menu');
  await new Promise((r) => setTimeout(r, 2000));
  await clickLabel('Add a canvas');
  await new Promise((r) => setTimeout(r, 1500));
  const clicked = await clickLabel(kind);
  await new Promise((r) => setTimeout(r, 700));
  const file = `canvas-${kind.replaceAll(' ', '_')}.png`;
  report.shots.push({ canvas: kind, file, bytes: await shot(file), clicked });
  // Remove it so the next one is the focus, except we keep two for the drag.
  if (kind !== 'Notebook' && kind !== 'Gallery') {
    await clickLabel('Close');
    await new Promise((r) => setTimeout(r, 300));
  }
}

report.actions.push({ step: 'before-drag', labels: await labels() });
const from = await box('Field note') || await box('Note');
const to = await box('Gallery');
report.actions.push({ step: 'drag-boxes', from, to });
if (from && to) {
  await pointerDrag(from, to);
  report.shots.push({ drag: true, file: 'drag-after.png', bytes: await shot('drag-after.png') });
}
await cdp('Page.reload', { ignoreCache: true });
await new Promise((r) => setTimeout(r, 8000));
await cdp('Runtime.evaluate', { expression: `document.querySelector('flt-semantics-placeholder')?.click()` });
await new Promise((r) => setTimeout(r, 1500));
report.actions.push({ step: 'after-reload', labels: await labels() });
report.shots.push({ reload: true, file: 'after-reload.png', bytes: await shot('after-reload.png') });

// Other surfaces at the same viewport.
for (const app of ['files', 'themes', 'market', 'apps']) {
  await go(`?app=${app}`);
  report.shots.push({ app, file: `app-${app}.png`, bytes: await shot(`app-${app}.png`), labels: await labels() });
}
await go('?ask=' + encodeURIComponent('Reply with the single word PINEAPPLE'));
await new Promise((r) => setTimeout(r, 25000));
report.actions.push({ step: 'ask', labels: await labels(), chain: logs.filter((l) => l.includes('[chain]')).slice(0, 12) });
report.shots.push({ ask: true, file: 'ask-pineapple.png', bytes: await shot('ask-pineapple.png') });
report.console = logs.slice(-40);
writeFileSync(join(OUT, 'report.json'), JSON.stringify(report, null, 2));
console.log('wrote', OUT, 'shots', report.shots.length);
chrome.kill('SIGKILL');
server.close();
process.exit(0);
