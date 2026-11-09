#!/usr/bin/env node
/**
 * Canvas objects and pointer workflow on a local build, intercepted at
 * https://davidebri1.github.io/collider-app/. Viewport 440×956 @2x.
 */
import { createRequire } from 'module';
import { execFileSync } from 'child_process';
import { mkdirSync, writeFileSync, readFileSync, existsSync, statSync, copyFileSync } from 'fs';
import { join, extname, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const PW = process.env.PLAYWRIGHT_CORE || '/tmp/pw/node_modules/playwright-core';
const { chromium } = require(PW);
const HERE = dirname(fileURLToPath(import.meta.url));
const PY = process.env.OCR_PYTHON || '/tmp/ocrvenv/bin/python';
const APP = 'https://davidebri1.github.io/collider-app/';
const ROOT = resolve(process.env.ROOT || 'build/web');
const OUT = resolve(process.env.OUT || '/tmp/sg-objects');
const ART = resolve(process.env.ART || '/opt/cursor/artifacts/smartgen-qa');
const DSF = 2, W = 440, H = 956;
mkdirSync(OUT, { recursive: true });
mkdirSync(ART, { recursive: true });
const MIME = { '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const norm = (s) => (s || '').toLowerCase().replace(/[^a-z0-9]+/g, '');
const log = [];
const note = (m) => { log.push(m); console.log(m); };
const CANVASES = ['Notebook', 'Gallery', 'Folder', 'Glass', 'Mirror', 'Swimlane vertical', 'Swimlane horizontal', 'Name Photo Description', 'Portfolio', 'Collection', 'Diary', 'Journal', 'Kanban Board widget', 'Table', 'Calendar Widget', 'Chart'];

function ocrBoxes(file) {
  try {
    const out = execFileSync(PY, [join(HERE, 'ocr.py'), file], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000 });
    return JSON.parse(out.trim().split('\n').pop()).boxes || [];
  } catch (e) { note('ocr ' + e.message?.slice(0, 120)); return []; }
}
function findPhrase(boxes, phrase) {
  const want = norm(phrase);
  const exact = boxes.filter((b) => {
    const n = norm(b[0]);
    if (n === want) return true;
    // Library labels truncate ("Swimlane horizo…", "Name Photo Des…").
    // Truncated library labels ("Swimlane horizo", "Name Photo Des").
    // A shorter painted word must not steal a longer name ("Calendar" vs "Calendar Widget").
    if (want.length > 8 && n.length >= 10 && n.startsWith(want.slice(0, 10))) return true;
    return want.length > 5 && n.length >= want.length - 2 && (want.endsWith(n) || n.endsWith(want.slice(1)));
  });
  if (!exact.length) return null;
  exact.sort((a, b) => b[2] - a[2]);
  return { text: exact[0][0], x: exact[0][1] / DSF, y: exact[0][2] / DSF };
}
const inside = (p) => p && p.x > 55 && p.x < 385 && p.y > 110 && p.y < 845;

async function newPage(browser) {
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: DSF });
  await ctx.route(/^https:\/\/davidebri1\.github\.io\/collider-app\//, async (route) => {
    let p = decodeURIComponent(new URL(route.request().url()).pathname.replace(/^\/collider-app\//, '/'));
    if (p === '/' || p === '') p = '/index.html';
    const f = join(ROOT, p);
    if (!f.startsWith(ROOT) || !existsSync(f) || statSync(f).isDirectory()) return route.fulfill({ status: 404, body: 'missing' });
    return route.fulfill({ status: 200, body: readFileSync(f), headers: { 'content-type': MIME[extname(f)] || 'application/octet-stream', 'cache-control': 'no-store' } });
  });
  const page = await ctx.newPage();
  page._net = [];
  page.on('response', async (r) => {
    const q = r.request();
    if (!/\/api\/p\?u=/.test(r.url()) || q.method() !== 'POST') return;
    let text = '';
    try { const j = await r.json(); const m = j?.choices?.[0]?.message || {}; text = (m.content || m.reasoning_content || '').trim(); } catch {}
    page._net.push({ status: r.status(), url: r.url().slice(0, 160), text: text.slice(0, 300) });
  });
  page.on('console', (m) => { if (m.text().includes('[chain]')) page._net.push({ chain: m.text().slice(0, 240) }); });
  return { ctx, page };
}
async function boot(page) {
  await page.goto(APP + '?app=smartgen&sg=canvas', { waitUntil: 'load', timeout: 120000 });
  await page.waitForLoadState('networkidle', { timeout: 20000 }).catch(() => {});
  for (let i = 0; i < 80; i++) {
    if (await page.evaluate(() => !!document.querySelector('flt-glass-pane, flutter-view'))) break;
    await sleep(250);
  }
  await sleep(4500);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await sleep(600);
}
let shotN = 0;
async function shot(page, name, keep = false) {
  const f = join(OUT, `${String(++shotN).padStart(2, '0')}_${name}.png`);
  await page.screenshot({ path: f });
  if (keep) copyFileSync(f, join(ART, `${name}.png`));
  return f;
}
const labels = (page) => page.evaluate(() => {
  const out = [];
  const walk = (e) => {
    const l = (e.getAttribute?.('aria-label') || '').trim() || (e.tagName === 'FLT-SEMANTICS' && e.childElementCount === 0 ? (e.textContent || '').trim() : '');
    if (l) { const r = e.getBoundingClientRect(); if (r.width > 0 && r.height > 0 && r.width < 400) out.push({ label: l.split('\n')[0].trim(), x: r.x, y: r.y, w: r.width, h: r.height }); }
    for (const c of e.children || []) walk(c);
    if (e.shadowRoot) for (const c of e.shadowRoot.children) walk(c);
  };
  walk(document.body);
  return out;
});
async function clickLabel(page, name) {
  const hits = (await labels(page)).filter((l) => l.label === name);
  hits.sort((a, b) => a.w * a.h - b.w * b.h);
  const l = hits[0];
  if (!l) return false;
  const x = l.x + Math.min(l.w, 120) / 2;
  const y = l.y + Math.min(l.h, 28) / 2;
  if (x < 55 || x > 385 || y < 110 || y > 845) { note(`label ${name} @ ${x.toFixed(0)},${y.toFixed(0)} outside`); return false; }
  await page.mouse.click(x, y);
  note(`label ${name} @ ${x.toFixed(0)},${y.toFixed(0)}`);
  return true;
}
async function clickPainted(page, phrase, scrolls = 8) {
  for (let i = 0; i < scrolls; i++) {
    const hit = findPhrase(ocrBoxes(await shot(page, 'seek')), phrase);
    if (hit && inside(hit)) { await page.mouse.click(hit.x, hit.y); note(`painted ${phrase} @ ${hit.x.toFixed(0)},${hit.y.toFixed(0)} (${hit.text})`); return true; }
    if (hit) note(`${phrase} at ${hit.x.toFixed(0)},${hit.y.toFixed(0)} outside`);
    await page.mouse.move(W / 2, 500);
    await page.mouse.wheel(0, hit && hit.y < 110 ? -280 : 300);
    await sleep(350);
  }
  note('MISS ' + phrase);
  return false;
}
async function openMenu(page) {
  if (await clickLabel(page, 'Board menu')) { await sleep(500); return true; }
  return false;
}
async function editorOpen(page) {
  const text = (ocrBoxes(await shot(page, 'ed')) || []).map((b) => b[0]).join(' ');
  return /Add date|in To Do/.test(text);
}
async function leaveEditor(page) {
  for (const y of [210, 228, 196]) {
    if (!(await editorOpen(page))) return true;
    await page.mouse.click(74, y);
    await sleep(450);
    note('back arrow ' + y);
  }
  return !(await editorOpen(page));
}
async function drag(page, a, b, label) {
  // The semantics layer turns a press into a tap and drops the move. Let the
  // pointer hit the Flutter canvas so a drag is a drag.
  await page.evaluate(() => {
    document.querySelectorAll('flt-semantics-host, flt-semantics, flt-semantics-placeholder').forEach((e) => { e.style.pointerEvents = 'none'; });
  });
  await page.mouse.move(a.x, a.y);
  await page.mouse.down();
  await sleep(200);
  await page.mouse.move(b.x, b.y, { steps: 16 });
  await page.mouse.up();
  await sleep(500);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await sleep(300);
  note(`${label} ${a.x.toFixed(0)},${a.y.toFixed(0)} -> ${b.x.toFixed(0)},${b.y.toFixed(0)}`);
}

const results = [];
const record = (id, ok, evidence, shot = '') => {
  results.push({ id, result: ok ? 'pass' : 'fail', shot, evidence });
  note(`${ok ? 'PASS' : 'FAIL'} ${id} — ${evidence}`);
};
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
const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', headless: true, args: ['--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage', '--hide-scrollbars'] });
try {
  const { page } = await newPage(browser);
  await boot(page);

  async function addCanvas(name) {
    if (!(await openMenu(page))) return false;
    if (!(await clickLabel(page, 'Add a canvas'))) return false;
    await sleep(400);
    if (!(await clickLabel(page, 'Search'))) return false;
    await sleep(200);
    await page.keyboard.type(name, { delay: 12 });
    await page.keyboard.press('Enter');
    await sleep(700);
    note('search-add ' + name);
    const placed = (await labels(page)).some((l) => l.label === `Move ${name}` || l.label === `Remove ${name}` || l.label === `Resize ${name}` || l.label === name);
    if (!placed) note('MISS placed ' + name);
    return placed;
  }
  function boxOf(list, name) {
    const hits = list.filter((l) => l.label === name);
    hits.sort((a, b) => a.w * a.h - b.w * b.h);
    return hits[0] || null;
  }
  async function addNote(page) {
    if (!(await openMenu(page))) return false;
    if (!(await clickLabel(page, 'New card'))) return false;
    await sleep(400);
    const ok = (await clickLabel(page, 'Note')) || (await clickPainted(page, 'Note', 3));
    await sleep(600);
    const left = await leaveEditor(page);
    note('left editor ' + left);
    return ok && left;
  }
  async function closeCanvases(page) {
    for (let n = 0; n < 12; n++) {
      const hit = (await labels(page)).find((l) => l.label.startsWith('Remove ') && inside({ x: l.x + Math.min(l.w, 16) / 2, y: l.y + Math.min(l.h, 16) / 2 }));
      if (!hit) break;
      await page.mouse.click(hit.x + Math.min(hit.w, 16) / 2, hit.y + Math.min(hit.h, 16) / 2);
      await sleep(300);
      note('closed ' + hit.label);
    }
  }
  async function fresh(page) {
    await page.evaluate(async () => {
      localStorage.clear();
      const dbs = indexedDB.databases ? await indexedDB.databases() : [];
      await Promise.all(dbs.filter((d) => d.name).map((d) => new Promise((res) => {
        const req = indexedDB.deleteDatabase(d.name);
        req.onsuccess = req.onerror = req.onblocked = () => res();
      })));
    });
    await boot(page);
  }

  const only = (process.env.ONLY || '').split(',').map((s) => s.trim()).filter(Boolean);
  const wantBoards = !only.length || only.includes('boards');
  if (wantBoards) {
    await fresh(page);
    for (const [name, file] of BOARDS) {
      if (!(await openMenu(page))) { record(`board ${name}`, false, 'board menu did not open', ''); continue; }
      await sleep(300);
      const ok = await clickPainted(page, name, 8);
      const shotName = ok ? file : `${file}-miss`;
      await shot(page, shotName, true);
      record(`board ${name}`, ok, ok ? `selected by pointer; ${shotName}.png is 880x1912` : `painted label not clicked`, `${shotName}.png`);
    }
  }
  if (!only.length || only.includes('pointer')) {
  await fresh(page);
  const created = await addCanvas('Notebook');
  const noted = await addNote(page);
  await shot(page, 'canvas-notebook', true);
  record('create notebook', created && noted, `canvas placed=${created} note added=${noted}`, 'canvas-notebook.png');

  const noteAt = findPhrase(ocrBoxes(await shot(page, 'note-at')), 'Note');
  let edited = false;
  if (noteAt && inside(noteAt)) {
    await page.mouse.click(noteAt.x, noteAt.y);
    await sleep(500);
    await page.keyboard.press('Control+A');
    await page.keyboard.type('Moved note', { delay: 20 });
    await page.keyboard.press('Enter');
    await sleep(400);
  }
  const editShot = await shot(page, 'pointer-edit', true);
  const editText = (ocrBoxes(editShot) || []).map((b) => b[0]).join(' ');
  edited = /Moved note/.test(editText);
  record('inline-edit', edited, `ocr="${editText.slice(0, 180)}"`, 'pointer-edit.png');

  const beforeMove = boxOf(await labels(page), 'Move Notebook');
  let moved = false;
  if (!beforeMove) note('MISS Move Notebook');
  else {
    await drag(page, { x: beforeMove.x + 24, y: beforeMove.y + Math.min(beforeMove.h, 18) / 2 }, { x: beforeMove.x + 70, y: beforeMove.y + 90 }, 'move notebook by its header');
    const afterMove = boxOf(await labels(page), 'Move Notebook');
    moved = !!afterMove && (afterMove.y - beforeMove.y > 30 || afterMove.x - beforeMove.x > 20);
    note(`move result ${beforeMove.x},${beforeMove.y} -> ${afterMove ? afterMove.x + ',' + afterMove.y : 'gone'}`);
    record('move', moved, `${Math.round(beforeMove.x)},${Math.round(beforeMove.y)} -> ${afterMove ? Math.round(afterMove.x) + ',' + Math.round(afterMove.y) : 'gone'}`, 'pointer-move.png');
  }
  if (!beforeMove) record('move', false, 'Move Notebook handle missing', 'pointer-move.png');
  await shot(page, 'pointer-move', true);

  await addCanvas('Gallery');
  await shot(page, 'canvas-gallery', true);

  const beforeSize = boxOf(await labels(page), 'Resize Notebook');
  let resized = false;
  if (!beforeSize) record('resize', false, 'Resize Notebook handle missing', 'pointer-resize.png');
  else {
    const ax = beforeSize.x + beforeSize.w / 2, ay = beforeSize.y + beforeSize.h / 2;
    await drag(page, { x: ax, y: ay }, { x: ax + 50, y: ay + 70 }, 'resize notebook');
    const afterSize = boxOf(await labels(page), 'Resize Notebook');
    const bx = afterSize ? afterSize.x + afterSize.w / 2 : ax;
    const by = afterSize ? afterSize.y + afterSize.h / 2 : ay;
    resized = Math.abs(bx - ax) > 20 || Math.abs(by - ay) > 20;
    record('resize', resized, `${Math.round(ax)},${Math.round(ay)} -> ${Math.round(bx)},${Math.round(by)}`, 'pointer-resize.png');
  }
  await shot(page, 'pointer-resize', true);

  const grip = boxOf(await labels(page), 'Drag Moved note') || boxOf(await labels(page), 'Drag Note');
  const gallery = boxOf(await labels(page), 'Move Gallery');
  let dragged = false;
  if (!grip || !gallery) record('cross-canvas drag', false, 'grip or gallery missing', 'pointer-drag.png');
  else {
    const from = { x: grip.x + Math.min(grip.w, 28) / 2, y: grip.y + Math.min(grip.h, 22) / 2 };
    const to = { x: gallery.x + 36, y: gallery.y + 80 };
    await drag(page, from, to, 'drag card to gallery');
    const afterGrip = boxOf(await labels(page), 'Drag Moved note') || boxOf(await labels(page), 'Drag Note');
    dragged = !!afterGrip && afterGrip.x > grip.x + 40;
    record('cross-canvas drag', dragged, `grip ${Math.round(grip.x)},${Math.round(grip.y)} -> ${afterGrip ? Math.round(afterGrip.x) + ',' + Math.round(afterGrip.y) : 'gone'}`, 'pointer-drag.png');
  }
  await shot(page, 'pointer-drag', true);

  await sleep(1200);
  await boot(page);
  await shot(page, 'pointer-reload', true);
  const reText = (ocrBoxes(await shot(page, 'reload-read')) || []).map((b) => b[0]).join(' | ');
  record('reload', /Moved note/.test(reText), `local reload only, not cross-device. ocr="${reText.slice(0, 220)}"`, 'pointer-reload.png');

  await closeCanvases(page);
  const left = (await labels(page)).some((l) => l.label === 'Move Notebook' || l.label === 'Move Gallery');
  await shot(page, 'pointer-remove', true);
  record('remove', !left, left ? 'a canvas handle is still present' : 'Move Notebook and Move Gallery are gone', 'pointer-remove.png');
  }

  const expectWord = {
    'Notebook': /Note/, 'Gallery': /Note/, 'Folder': /Note|Folder/, 'Glass': /Note/, 'Mirror': /Note/,
    'Swimlane vertical': /To Do/, 'Swimlane horizontal': /To Do|Doing/, 'Name Photo Description': /Name/,
    'Portfolio': /Piece/, 'Collection': /[1-4]/, 'Diary': /Nov/, 'Journal': /Nov/,
    'Kanban Board widget': /To Do/, 'Table': /Note/, 'Calendar Widget': /\b30\b/, 'Chart': /Note/,
  };
  const todo = only.length ? CANVASES.filter((n) => only.includes(n)) : CANVASES;
  for (const name of todo) {
    await fresh(page);
    const file = `canvas-${norm(name)}`;
    if (!(await addCanvas(name))) {
      await shot(page, `${file}-miss`, true);
      record(`canvas ${name}`, false, 'not created', `${file}-miss.png`);
      continue;
    }
    await addNote(page);
    const placed = (await labels(page)).some((l) => l.label === `Move ${name}`);
    const shotFile = await shot(page, file, true);
    const text = (ocrBoxes(shotFile) || []).map((b) => b[0]).join(' ');
    const want = expectWord[name];
    const saw = !want || want.test(text);
    record(`canvas ${name}`, placed && saw, `placed=${placed} ocr="${text.slice(0, 160)}"`, `${file}.png`);
  }

  const ask = await newPage(browser);
  await ask.page.goto(APP + '?ask=' + encodeURIComponent('Reply with the single word QUINCE'), { waitUntil: 'load', timeout: 120000 });
  await sleep(4000);
  const t0 = Date.now();
  while (Date.now() - t0 < 80000 && ask.page._net.filter((n) => n.status).length === 0) await sleep(2000);
  await shot(ask.page, 'provider-ask', true);
  const quince = ask.page._net.some((n) => n.status === 200 && /QUINCE/.test(n.text || ''));
  record('in-browser provider', quince, JSON.stringify(ask.page._net).slice(0, 300), 'provider-ask.png');
  writeFileSync(join(ART, 'provider.json'), JSON.stringify(ask.page._net, null, 1));
  await ask.ctx.close();
} catch (e) {
  note('FATAL ' + (e.stack || e));
  record('run', false, String(e.stack || e).slice(0, 500), '');
} finally {
  await browser.close();
  const passed = results.filter((r) => r.result === 'pass').length;
  const failed = results.filter((r) => r.result === 'fail').length;
  const report = { at: new Date().toISOString(), source: 'written by this run only', passed, failed, entries: results };
  writeFileSync(join(OUT, 'report.json'), JSON.stringify(report, null, 1));
  writeFileSync(join(ART, 'report.json'), JSON.stringify(report, null, 1));
  writeFileSync(join(ART, 'objects-log.json'), JSON.stringify(log, null, 1));
  console.log(`\nreport ${passed} pass / ${failed} fail -> ${join(ART, 'report.json')}`);
}
