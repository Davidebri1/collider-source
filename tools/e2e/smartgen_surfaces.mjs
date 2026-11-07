#!/usr/bin/env node
/**
 * Local QA of a built web artifact, intercepted at the live origin
 * https://davidebri1.github.io/collider-app/ (no local port, no CORS change).
 * Viewport 440×956 CSS at device scale 2 → screenshots 880×1912.
 *
 *   ROOT=build/web OUT=/tmp/sg-surfaces node tools/e2e/smartgen_surfaces.mjs
 */
import { createRequire } from 'module';
import { execFileSync } from 'child_process';
import { mkdirSync, writeFileSync, readFileSync, existsSync, statSync, copyFileSync } from 'fs';
import { join, extname, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const PW = process.env.PLAYWRIGHT_CORE || '/usr/local/lib/pnpm/5/.pnpm/playwright-core@1.59.1/node_modules/playwright-core';
const { chromium } = require(PW);
const HERE = dirname(fileURLToPath(import.meta.url));
const PY = process.env.OCR_PYTHON || '/tmp/ocrvenv/bin/python';
const APP = 'https://davidebri1.github.io/collider-app/';
const ROOT = resolve(process.env.ROOT || 'build/web');
const OUT = resolve(process.env.OUT || '/tmp/sg-surfaces');
const ART = resolve(process.env.ART || '/opt/cursor/artifacts/smartgen-qa');
const DSF = 2;
const W = 440, H = 956;
mkdirSync(OUT, { recursive: true });
mkdirSync(ART, { recursive: true });

const MIME = { '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.webp': 'image/webp' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const norm = (s) => (s || '').toLowerCase().replace(/[^a-z0-9]+/g, '');
const log = [];
const note = (m) => { log.push(m); console.log(m); };

const BOARDS = [
  ['Desk', 'board-desk'],
  ['Kanban Board with Swim lanes', 'board-kanban'],
  ['Calendar', 'board-calendar'],
  ['Whiteboard empty', 'board-whiteboard-empty'],
  ['Whiteboard with swim lanes', 'board-whiteboard-lanes'],
  ['White board without swim lanes', 'board-whiteboard-plain'],
  ['Long wood bench', 'board-long-bench'],
  ['Workbench', 'board-workbench'],
  ['Table', 'board-table'],
  ['Wood round table', 'board-round-table'],
  ['Wood Night Stand', 'board-night-stand'],
  ['Wood Long Table', 'board-long-table'],
  ['Wood Coffee Table', 'board-coffee-table'],
  ['Various Different Charts and diagrams', 'board-charts'],
];
const CANVASES = [
  'Notebook', 'Gallery', 'Folder', 'Glass', 'Mirror',
  'Swimlane vertical', 'Swimlane horizontal', 'Name Photo Description',
  'Portfolio', 'Collection', 'Diary', 'Journal',
  'Kanban Board widget', 'Table', 'Calendar Widget', 'Chart',
];

function ocrBoxes(file) {
  try {
    const out = execFileSync(PY, [join(HERE, 'ocr.py'), file], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000 });
    return JSON.parse(out.trim().split('\n').pop()).boxes || [];
  } catch (e) {
    note(`ocr failed ${file}: ${e.message?.slice(0, 180)}`);
    return null;
  }
}

function linesOf(boxes) {
  const rows = [];
  for (const b of boxes) {
    let row = rows.find((r) => Math.abs(r.y - b[2]) < 36);
    if (!row) { row = { y: b[2], parts: [] }; rows.push(row); }
    row.parts.push(b);
  }
  return rows.map((r) => {
    r.parts.sort((a, c) => a[1] - c[1]);
    const text = r.parts.map((p) => p[0]).join(' ');
    const xs = r.parts.flatMap((p) => [p[1]]);
    return { text, x: xs.reduce((s, v) => s + v, 0) / xs.length, y: r.y };
  });
}

function findPhrase(boxes, phrase) {
  if (!boxes) return null;
  const want = norm(phrase);
  // A chip is its own box. Take the lowest exact match so the kind chip
  // wins when the same word is also a view chip on the row above.
  const exact = boxes.filter((b) => {
    const n = norm(b[0]);
    if (n === want) return true;
    // A title clipped by the object edge ("otebook") still names that object.
    return want.length > 5 && n.length >= want.length - 2 && (want.endsWith(n) || n.endsWith(want.slice(1)));
  });
  if (exact.length) {
    exact.sort((a, b) => b[2] - a[2]);
    return { text: exact[0][0], x: exact[0][1], y: exact[0][2] };
  }
  if (want.length <= 6) return null;
  const lines = linesOf(boxes);
  for (let i = 0; i < lines.length; i++) {
    const blob = norm(lines.slice(i, i + 2).map((l) => l.text).join(' '));
    if (blob.includes(want) && blob.length <= want.length + 8) return lines[i];
  }
  return null;
}

async function newPage(browser) {
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: DSF });
  await ctx.route(/^https:\/\/davidebri1\.github\.io\/collider-app\//, async (route) => {
    let p = decodeURIComponent(new URL(route.request().url()).pathname.replace(/^\/collider-app\//, '/'));
    if (p === '/' || p === '') p = '/index.html';
    const f = join(ROOT, p);
    if (!f.startsWith(ROOT) || !existsSync(f) || statSync(f).isDirectory()) return route.fulfill({ status: 404, body: 'missing ' + p });
    return route.fulfill({ status: 200, body: readFileSync(f), headers: { 'content-type': MIME[extname(f)] || 'application/octet-stream', 'cache-control': 'no-store' } });
  });
  const page = await ctx.newPage();
  const net = [];
  page.on('response', async (r) => {
    const q = r.request();
    if (!/\/api\/p\?u=/.test(r.url()) || q.method() !== 'POST') return;
    let text = '';
    try {
      const j = await r.json();
      const m = j?.choices?.[0]?.message || {};
      text = (m.content || m.reasoning_content || '').trim();
    } catch { try { text = (await r.text()).slice(0, 300); } catch {} }
    net.push({ status: r.status(), url: r.url().slice(0, 180), text: text.slice(0, 400) });
  });
  page.on('console', (m) => { if (m.text().includes('[chain]')) net.push({ chain: m.text().slice(0, 300) }); });
  page._net = net;
  return { ctx, page };
}

async function boot(page, q) {
  await page.goto(APP + q, { waitUntil: 'load', timeout: 120000 });
  await page.waitForLoadState('networkidle', { timeout: 20000 }).catch(() => {});
  for (let i = 0; i < 80; i++) {
    if (await page.evaluate(() => !!document.querySelector('flt-glass-pane, flutter-view'))) break;
    await sleep(250);
  }
  await sleep(5000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await sleep(800);
}

let shotN = 0;
async function shot(page, name, { keep = false } = {}) {
  const f = join(OUT, `${String(++shotN).padStart(2, '0')}_${name}.png`);
  await page.screenshot({ path: f });
  if (keep) {
    copyFileSync(f, join(ART, `${name}.png`));
    const dim = execFileSync('python3', ['-c', `from struct import unpack;d=open(${JSON.stringify(f)},'rb').read(24);w,h=unpack('>II', d[16:24]);print(w,h)`], { encoding: 'utf8' }).trim();
    note(`shot ${name} ${dim}`);
  }
  return f;
}

const labels = (page) => page.evaluate(() => {
  const out = [];
  const walk = (e) => {
    const l = (e.getAttribute?.('aria-label') || '').trim() || (e.tagName === 'FLT-SEMANTICS' && e.childElementCount === 0 ? (e.textContent || '').trim() : '');
    if (l) { const r = e.getBoundingClientRect(); if (r.width > 0 && r.height > 0) out.push({ label: l.split('\n')[0].trim(), x: r.x, y: r.y, w: r.width, h: r.height }); }
    for (const c of e.children || []) walk(c);
    if (e.shadowRoot) for (const c of e.shadowRoot.children) walk(c);
  };
  walk(document.body);
  return out;
});

async function clickLabel(page, name) {
  const all = await labels(page);
  const hits = all.filter((l) => l.label === name);
  hits.sort((a, b) => a.w * a.h - b.w * b.h);
  const l = hits[0];
  if (!l) return false;
  const x = l.x + Math.min(l.w, 140) / 2;
  const y = l.y + Math.min(l.h, 32) / 2;
  if (y < 70 || y > 900 || x < 0 || x > W) {
    note(`label ${name} at ${x.toFixed(0)},${y.toFixed(0)} is outside the pane — not clicking`);
    return false;
  }
  await page.mouse.click(x, y);
  note(`click label ${name} @ ${x.toFixed(0)},${y.toFixed(0)}`);
  return true;
}

async function clickPainted(page, phrase, { scrolls = 8, exactNote = '' } = {}) {
  for (let i = 0; i < scrolls; i++) {
    const f = await shot(page, `seek-${norm(phrase).slice(0, 24)}`);
    const hit = findPhrase(ocrBoxes(f), phrase);
    if (hit) {
      const x = hit.x / DSF, y = hit.y / DSF;
      // Stay inside the centred pane. A click on the wallpaper scrim dismisses Smart Gen.
      if (x > 55 && x < 385 && y > 110 && y < 830) {
        await page.mouse.click(x, y);
        note(`click painted "${phrase}" @ ${x.toFixed(0)},${y.toFixed(0)} (${hit.text})${exactNote}`);
        return true;
      }
      note(`"${phrase}" painted at ${x.toFixed(0)},${y.toFixed(0)} outside the pane — scrolling`);
    }
    await page.mouse.move(W / 2, 520);
    await page.mouse.wheel(0, i < scrolls - 1 ? 320 : -500);
    await sleep(450);
  }
  note(`MISS painted "${phrase}"`);
  return false;
}

async function openMenu(page) {
  if (await clickLabel(page, 'Board menu')) { await sleep(700); return true; }
  return clickPainted(page, 'Board menu', { scrolls: 1 });
}

async function inPane(page) {
  const all = await labels(page);
  return all.some((l) => l.label === 'Board menu' || l.label === 'Boards' || l.label === 'Add a canvas');
}

const browser = await chromium.launch({
  executablePath: process.env.CHROME || '/usr/bin/google-chrome',
  headless: true,
  args: ['--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage', '--hide-scrollbars'],
});

const report = { shots: [], steps: [], provider: [] };
try {
  const { page } = await newPage(browser);
  await boot(page, '?app=smartgen&sg=canvas');
  if (!(await inPane(page))) {
    note('pane not up after boot');
    await shot(page, 'boot-fail', { keep: true });
  }

  for (const [label, file] of BOARDS) {
    if (!(await inPane(page))) {
      await boot(page, '?app=smartgen&sg=canvas');
    }
    const opened = await openMenu(page);
    if (!opened) { note(`could not open menu for ${label}`); await shot(page, file + '-no-menu', { keep: true }); continue; }
    await sleep(400);
    // Scroll the kind list back to the top before searching, so a previous
    // wheel does not start past the chip.
    await page.mouse.move(W / 2, 480);
    await page.mouse.wheel(0, -2400);
    await sleep(300);
    const hit = await clickPainted(page, label, { scrolls: 7 });
    await sleep(900);
    if (!(await inPane(page))) {
      note(`left Smart Gen while choosing ${label}`);
      await shot(page, file + '-left', { keep: true });
      await boot(page, '?app=smartgen&sg=canvas');
      continue;
    }
    // Kind selection closes the menu. If it is still open, the click missed.
    const still = (await labels(page)).some((l) => l.label === 'Add a canvas');
    if (still) {
      note(`menu still open after ${label} (hit=${hit})`);
      await clickLabel(page, 'Close');
      await sleep(400);
    }
    await shot(page, file, { keep: true });
    report.shots.push(file);
  }

  // Canvases sit on the desk.
  await openMenu(page);
  await page.mouse.wheel(0, -2400);
  await clickPainted(page, 'Desk', { scrolls: 6 });
  await sleep(600);

  async function addCanvas(name) {
    if (!(await openMenu(page))) return false;
    await sleep(300);
    if (!(await clickLabel(page, 'Add a canvas'))) {
      if (!(await clickPainted(page, 'Add a canvas', { scrolls: 2 }))) return false;
    }
    await sleep(700);
    await page.mouse.move(W / 2, 480);
    await page.mouse.wheel(0, -2000);
    await sleep(200);
    const ok = await clickPainted(page, name, { scrolls: 6 });
    await sleep(800);
    return ok;
  }

  async function addNote() {
    if (!(await openMenu(page))) return false;
    await sleep(200);
    if (!(await clickLabel(page, 'New card'))) {
      if (!(await clickPainted(page, 'New card', { scrolls: 2 }))) return false;
    }
    await sleep(600);
    const ok = (await clickLabel(page, 'Note')) || (await clickPainted(page, 'Note', { scrolls: 3 }));
    await sleep(800);
    // The editor covers the board. Its back control is an arrow under the
    // view chips, on the left of the pane — the word "Back" is not painted.
    if (!(await clickLabel(page, 'Back'))) {
      const desk = await paintedPoint(page, 'Desk');
      const y = desk ? Math.min(desk.y + 58, 280) : 230;
      await page.mouse.click(72, y);
      note(`clicked back arrow @ 72,${y.toFixed(0)}`);
    }
    await sleep(500);
    return ok;
  }

  async function editTitle(page, from, to) {
    const f = await shot(page, 'before-edit');
    const hit = findPhrase(ocrBoxes(f), from);
    if (!hit) { note(`edit miss ${from}`); return false; }
    await page.mouse.click(hit.x / DSF, hit.y / DSF);
    await sleep(300);
    await page.keyboard.press('Control+A');
    await page.keyboard.type(to, { delay: 25 });
    await page.keyboard.press('Enter');
    await sleep(400);
    note(`edited ${from} -> ${to}`);
    return true;
  }

  async function backToBoard(page) {
    if (await inPane(page)) return;
    note('left the pane; reopening the saved board');
    await boot(page, '?app=smartgen&sg=canvas');
  }
  async function paintedPoint(page, phrase) {
    const f = await shot(page, 'at');
    const hit = findPhrase(ocrBoxes(f), phrase);
    if (!hit) return null;
    const x = hit.x / DSF, y = hit.y / DSF;
    if (x < 55 || x > 385 || y < 110 || y > 830) return null;
    return { x, y };
  }
  async function dragPointer(page, from, to, label) {
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    await sleep(150);
    await page.mouse.move(to.x, to.y, { steps: 12 });
    await page.mouse.up();
    await sleep(500);
    note(`${label} (${from.x.toFixed(0)},${from.y.toFixed(0)}) -> (${to.x.toFixed(0)},${to.y.toFixed(0)})`);
  }

  // Pointer workflow on Notebook + Gallery.
  await addCanvas('Notebook');
  await backToBoard(page);
  await addNote();
  await backToBoard(page);
  await editTitle(page, 'Note', 'Field note');
  await shot(page, 'canvas-notebook', { keep: true });
  await addCanvas('Gallery');
  await backToBoard(page);
  await shot(page, 'canvas-gallery-before-drag', { keep: true });

  // Move the notebook by its header. Prefer the semantics handle; the painted
  // title is the same header when the accessibility node is missing.
  const move = (await labels(page)).find((l) => l.label === 'Move Notebook');
  if (move) {
    await dragPointer(page, { x: move.x + 24, y: move.y + Math.min(move.h, 16) / 2 }, { x: move.x + 80, y: move.y + 48 }, 'moved notebook');
  } else {
    const title = await paintedPoint(page, 'Notebook');
    if (title) await dragPointer(page, title, { x: title.x + 55, y: title.y + 45 }, 'moved notebook by its title');
    else note('MISS move notebook');
  }
  await shot(page, 'pointer-move', { keep: true });

  const rz = (await labels(page)).find((l) => l.label === 'Resize Notebook');
  if (rz) {
    const x = rz.x + Math.min(rz.w, 12) / 2;
    const y = rz.y + Math.min(rz.h, 12) / 2;
    await dragPointer(page, { x, y }, { x: x + 36, y: y + 32 }, 'resized notebook');
  } else {
    const title = await paintedPoint(page, 'Notebook');
    if (title) await dragPointer(page, { x: title.x + 130, y: title.y + 110 }, { x: title.x + 165, y: title.y + 145 }, 'resized from the book corner');
    else note('MISS Resize Notebook');
  }
  await shot(page, 'pointer-resize', { keep: true });

  await editTitle(page, 'Field note', 'Moved note');
  await shot(page, 'pointer-edit', { keep: true });

  const drag = (await labels(page)).find((l) => l.label === 'Drag Moved note' || l.label === 'Drag Field note' || l.label.startsWith('Drag '));
  const gal = await paintedPoint(page, 'Gallery');
  if (drag && gal) {
    const x = drag.x + Math.min(drag.w, 12) / 2;
    const y = drag.y + Math.min(drag.h, 16) / 2;
    await dragPointer(page, { x, y }, { x: gal.x, y: gal.y + 40 }, 'dragged card toward Gallery');
  } else if (gal) {
    const noteAt = await paintedPoint(page, 'Moved note') || await paintedPoint(page, 'Note');
    if (noteAt) await dragPointer(page, { x: noteAt.x - 18, y: noteAt.y }, { x: gal.x, y: gal.y + 40 }, 'dragged card from its grip');
    else note('MISS card to drag');
  } else note('MISS gallery target');
  await shot(page, 'pointer-drag', { keep: true });

  await sleep(1500);
  await boot(page, '?app=smartgen&sg=canvas');
  await shot(page, 'pointer-reload', { keep: true });
  const re = await shot(page, 'reload-ocr');
  const reBoxes = ocrBoxes(re) || [];
  const reText = reBoxes.map((b) => b[0]).join(' | ');
  note(`reload ocr: ${reText.slice(0, 400)}`);
  report.reloadText = reText;

  // Remove Gallery after the reload proved it was still there.
  if (await clickLabel(page, 'Remove Gallery')) {
    await sleep(500);
    note('removed gallery');
  } else note('MISS Remove Gallery');
  await shot(page, 'pointer-remove', { keep: true });

  async function deleteOpenCard(page) {
    await page.mouse.move(W / 2, 500);
    await page.mouse.wheel(0, -2000);
    await sleep(200);
    for (let i = 0; i < 6; i++) {
      if (await clickLabel(page, 'Delete card')) return true;
      if (await clickPainted(page, 'Delete card', { scrolls: 1 })) return true;
      await page.mouse.move(W / 2, 500);
      await page.mouse.wheel(0, 400);
      await sleep(250);
    }
    return false;
  }

  // One canvas at a time, each with a card, then remove it so the next shot is that object.
  for (const name of CANVASES) {
    if (!(await inPane(page))) await boot(page, '?app=smartgen&sg=canvas');
    // Drop leftover canvases so the new one is the one on screen.
    for (let n = 0; n < 6; n++) {
      const left = (await labels(page)).find((l) => l.label.startsWith('Remove '));
      if (!left) break;
      await clickLabel(page, left.label);
      await sleep(300);
    }
    const added = await addCanvas(name);
    await backToBoard(page);
    if (!added) { await shot(page, `canvas-${norm(name)}-miss`, { keep: true }); continue; }
    await addNote();
    await backToBoard(page);
    const slug = `canvas-${norm(name)}`;
    await shot(page, slug, { keep: true });
    report.shots.push(slug);
    // Open the card and delete it so later surfaces are not covered by leftovers.
    const titled = await shot(page, 'card-seek');
    const card = findPhrase(ocrBoxes(titled), 'Note');
    if (card) {
      await page.mouse.dblclick(card.x / DSF, card.y / DSF);
      await sleep(700);
      if (await deleteOpenCard(page)) note(`deleted card on ${name}`);
      else if (await clickLabel(page, 'Back')) note(`could not delete card on ${name}`);
      await sleep(400);
    }
  }

  // In-browser provider call on the same origin. Does not change Worker CORS.
  const ask = await newPage(browser);
  await boot(ask.page, '?ask=' + encodeURIComponent('Reply with the single word QUINCE'));
  const t0 = Date.now();
  while (Date.now() - t0 < 90000 && ask.page._net.filter((n) => n.status).length === 0) await sleep(2000);
  await sleep(3000);
  await shot(ask.page, 'provider-ask', { keep: true });
  report.provider = ask.page._net;
  note(`provider events ${ask.page._net.length}`);
  await ask.ctx.close();
} catch (e) {
  note(`FATAL ${e.stack || e}`);
} finally {
  await browser.close();
  report.steps = log;
  writeFileSync(join(OUT, 'report.json'), JSON.stringify(report, null, 1));
  writeFileSync(join(ART, 'report.json'), JSON.stringify(report, null, 1));
  console.log('wrote', OUT, 'and', ART);
}
