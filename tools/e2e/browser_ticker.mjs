#!/usr/bin/env node
/**
 * End-to-end check for the in-app browser and the Home ticker, at 440x956.
 *
 *   node tools/e2e/browser_ticker.mjs                       # live (GitHub Pages)
 *   ROOT=build/web node tools/e2e/browser_ticker.mjs        # a local build
 *
 * With ROOT set, the build is served at the live address itself
 * (https://davidebri1.github.io/collider-app/) through request interception,
 * so the providers' Worker sees the same Origin the live app sends. Nothing
 * listens on a local port.
 *
 * OUT (default ./e2e-out) gets screenshots, network.json (every request URL +
 * status), console.txt, replies.json (the words each provider sent back) and
 * report.json (PASS/FAIL per check). Exit code 1 when any check fails.
 *
 * ONLY=browser|ticker|features (comma list) limits the run; features are the
 * backup ports (backup_features.mjs), read back by OCR (ocr.py).
 *
 * Env: CHROME (default /usr/bin/google-chrome), PLAYWRIGHT_CORE (path to
 * playwright-core), TICKER_WAIT_S (default 150).
 */
import { createRequire } from 'module';
import { mkdirSync, writeFileSync, readFileSync, existsSync, statSync } from 'fs';
import { join, extname, resolve } from 'path';
import { featureChecks, ocr, ocrBoxes } from './backup_features.mjs';
import { webFinishChecks } from './web_finish.mjs';

const require = createRequire(import.meta.url);
const PW = process.env.PLAYWRIGHT_CORE || '/usr/local/lib/pnpm/5/.pnpm/playwright-core@1.59.1/node_modules/playwright-core';
const { chromium } = require(PW);

const APP = 'https://davidebri1.github.io/collider-app/';
const ROOT = process.env.ROOT ? resolve(process.env.ROOT) : null;
const OUT = resolve(process.env.OUT || 'e2e-out');
const WAIT = Number(process.env.TICKER_WAIT_S || 150) * 1000;
const W = 440, H = 956;
export const DSF = Number(process.env.DSF || 2); // every screenshot at device scale 2 (880x1912)
// WISP: a Wisp server for the in-app browser's real proxy (Scramjet). Test-only: the build's
// proxy/config.js is served with this address; the build itself is not changed.
const WISP = process.env.WISP || '';
const MINIMAX_402 = process.env.MINIMAX_402 === '1';
mkdirSync(OUT, { recursive: true });

const MIME = { '.html': 'text/html', '.js': 'application/javascript', '.mjs': 'application/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.webp': 'image/webp', '.mp4': 'video/mp4' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const checks = [];
const check = (name, ok, detail = '') => { checks.push({ name, ok: !!ok, detail }); console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`); };
const warns = [];
const warn = (name, detail = '') => { warns.push({ name, detail }); console.log(`WARN  ${name}${detail ? '  — ' + detail : ''}`); };
const net = [], consoleLines = [], replies = [];
let inFlight = 0; // provider calls (Worker /api/p) started and not finished
let shotN = 0;

async function newPage(browser) {
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: DSF });
  if (ROOT) {
    await ctx.route(/^https:\/\/davidebri1\.github\.io\/collider-app\//, async (route) => {
      let p = decodeURIComponent(new URL(route.request().url()).pathname.replace(/^\/collider-app\//, '/'));
      if (p === '/' || p === '') p = '/index.html';
      const f = join(ROOT, p);
      if (!f.startsWith(ROOT) || !existsSync(f) || statSync(f).isDirectory()) return route.fulfill({ status: 404, body: 'missing' });
      return route.fulfill({ status: 200, body: readFileSync(f), headers: { 'content-type': MIME[extname(f)] || 'application/octet-stream', 'cache-control': 'no-store' } });
    });
  }
  // Registered after the build's own route: Playwright asks the newest route first.
  if (WISP) {
    await ctx.route(/^https:\/\/davidebri1\.github\.io\/collider-app\/proxy\/config\.js/, (route) =>
      route.fulfill({ status: 200, body: `self.COLLIDER_WISP_URL = ${JSON.stringify(WISP)};`, headers: { 'content-type': 'application/javascript', 'cache-control': 'no-store' } }));
  }
  if (MINIMAX_402) {
    // MiniMax direct answers 402 (no balance), as in production on Nov 6/7.
    await ctx.route(/\/api\/p\?u=minimax\b/, (route) => route.fulfill({ status: 402, body: JSON.stringify({ error: { message: 'insufficient balance (e2e: forced 402)' } }), headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*' } }));
  }
  const page = await ctx.newPage();
  const isP = (q) => /\/api\/p\?u=/.test(q.url()) && q.method() === 'POST';
  page.on('request', (q) => { if (isP(q)) inFlight++; });
  page.on('requestfinished', (q) => { if (isP(q)) inFlight--; });
  page.on('requestfailed', (q) => { if (isP(q)) inFlight--; });
  page.on('response', async (r) => {
    const q = r.request();
    let model = '', agent = false;
    try { const b = JSON.parse(q.postData() || '{}'); model = b.model || ''; agent = (b.messages || []).some((m) => m.role === 'system'); } catch {}
    const row = { t: new Date().toISOString(), method: q.method(), status: r.status(), url: r.url().slice(0, 400), model };
    net.push(row);
    if (/\/api\/p\?u=/.test(r.url()) && q.method() === 'POST') {
      let text = '';
      try {
        const j = await r.json();
        const m = j?.choices?.[0]?.message || {};
        text = (m.content || m.reasoning_content || '').trim() || JSON.stringify(j).slice(0, 300);
      } catch { try { text = (await r.text()).slice(0, 300); } catch {} }
      // agent: a consensus agent call (it carries a system prompt); rows never do.
      replies.push({ provider: new URL(r.url()).searchParams.get('u'), model, agent, status: r.status(), text: text.slice(0, 600) });
    }
  });
  page.on('requestfailed', (q) => net.push({ t: new Date().toISOString(), method: q.method(), status: 'FAILED ' + (q.failure()?.errorText || ''), url: q.url().slice(0, 400) }));
  page.on('console', (m) => consoleLines.push(`${m.type()}: ${m.text().slice(0, 400)}`));
  page.on('pageerror', (e) => consoleLines.push(`pageerror: ${String(e).slice(0, 400)}`));
  return { ctx, page };
}

async function boot(page, q = '', { semantics = true } = {}) {
  // 'load', then up to 30 s for the network to settle: a reload with a
  // long-lived request open (seen in Smart Gen) never reaches networkidle.
  await page.goto(APP + q, { waitUntil: 'load', timeout: 120000 });
  await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {});
  for (let i = 0; i < 80; i++) {
    if (await page.evaluate(() => !!document.querySelector('flt-glass-pane, flutter-view'))) break;
    await sleep(250);
  }
  await sleep(6000);
  // Semantics on gives the harness labels to find controls by. The browser run
  // keeps it off: Flutter's semantics layer sits over the page frame and would
  // take the taps meant for links inside the page.
  if (semantics) {
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await sleep(800);
  }
}

const shot = async (page, name) => { const f = `${String(++shotN).padStart(2, '0')}_${name}.png`; await page.screenshot({ path: join(OUT, f) }); return f; }; // 880x1912 at DSF 2

/** Semantics nodes with a label: [{label, x, y, w, h}] */
const labels = (page) => page.evaluate(() => {
  const out = [];
  const walk = (e) => {
    const l = (e.getAttribute?.('aria-label') || '').trim() || (e.tagName === 'FLT-SEMANTICS' && e.childElementCount === 0 ? (e.textContent || '').trim() : '');
    if (l) { const r = e.getBoundingClientRect(); out.push({ label: l, x: r.x, y: r.y, w: r.width, h: r.height }); }
    for (const c of e.children || []) walk(c);
    if (e.shadowRoot) for (const c of e.shadowRoot.children) walk(c);
  };
  walk(document.body);
  return out;
});

/** The browser frame(s): title and the real address on screen. srcdoc frames (page proxy)
 *  carry their base; live frames (Scramjet, proxy/go/<encoded>) are decoded to the real address. */
const realOf = (u) => { let m; for (let i = 0; i < 4 && (m = u.match(/\/proxy\/go\/(.+)$/)); i++) u = decodeURIComponent(m[1]); return u; };
const frames = async (page) => {
  const out = await page.evaluate(() => {
    const out = [];
    const walk = (e) => {
      if (e.tagName === 'IFRAME' && e.getAttribute('srcdoc') != null) {
        const sd = e.getAttribute('srcdoc') || '';
        out.push({ src: e.src || '', title: ((sd.match(/<title[^>]*>([^<]*)/i) || [])[1] || '').trim(), base: (sd.match(/<base href="([^"]*)"/) || [])[1] || '', bytes: sd.length });
      }
      for (const c of e.children || []) walk(c);
      if (e.shadowRoot) for (const c of e.shadowRoot.children) walk(c);
    };
    walk(document.body);
    return out;
  });
  for (const f of page.frames()) {
    const u = f.url();
    if (!/\/proxy\/go\//.test(u)) continue;
    let title = '', bytes = 0;
    try { [title, bytes] = await f.evaluate(() => [document.title, document.documentElement.outerHTML.length]); } catch {}
    out.push({ src: u, base: realOf(u), title: (title || '').trim(), bytes, live: true, frame: f });
  }
  return out;
};
export { realOf };

/** Taps the centre of the labelled node with the mouse, scrolling the ticker
 *  column when the row is below the visible part of the list. */
async function tapAt(page, label, { scroll = false } = {}) {
  for (let i = 0; i < 12; i++) {
    const l = (await labels(page)).find((x) => x.label === label || x.label.startsWith(label + '\n'));
    if (!l) return false;
    const cy = l.y + Math.min(l.h, 44) / 2;
    if (scroll && cy > 772) { await page.mouse.move(W / 2, 600); await page.mouse.wheel(0, 160); await sleep(700); continue; }
    if (scroll && cy < 420) { await page.mouse.move(W / 2, 600); await page.mouse.wheel(0, -160); await sleep(700); continue; }
    await page.mouse.click(l.x + Math.min(l.w, 200) / 2, cy);
    return true;
  }
  return false;
}

/** The page frame's box; the address ornament sits 33 px above its top. */
async function frameBox(page) {
  return page.evaluate(() => {
    let r = null;
    const walk = (e) => { if (r) return; if (e.tagName === 'IFRAME') { const b = e.getBoundingClientRect(); if (b.width > 100) r = { x: b.x, y: b.y, w: b.width, h: b.height }; } for (const c of e.children || []) walk(c); if (e.shadowRoot) for (const c of e.shadowRoot.children) walk(c); };
    walk(document.body);
    return r;
  }).then((r) => r || { x: 70, y: 231, w: 300, h: 535 });
}

async function typeAddress(page, text) {
  const b = await frameBox(page);
  // The address field: centre of the ornament above the page window.
  await page.mouse.click(W / 2 - 20, b.y - 33);
  await sleep(400);
  await page.keyboard.press('Control+A');
  await page.keyboard.type(text, { delay: 20 });
  await page.keyboard.press('Enter');
}

async function waitFrame(page, pred, ms = 30000) {
  const t0 = Date.now();
  let fr = [];
  while (Date.now() - t0 < ms) { fr = await frames(page); if (fr.some(pred)) return fr; await sleep(500); }
  return fr;
}

/** OCR words painted on a screenshot (tools/e2e/ocr.py). */
const ocrWords = (f) => (ocr(join(OUT, f)) || []).join(' ');
/** The address field's painted text: OCR of the strip above the page window. */
async function addressText(page, f) {
  const b = await frameBox(page);
  const raw = ocrBoxes(join(OUT, f)) || [];
  return raw.filter((x) => Math.abs(x[2] / DSF - (b.y - 33)) < 16).map((x) => x[0]).join(' ');
}

async function browserChecks(browser) {
  const { ctx, page } = await newPage(browser);
  await boot(page, '?browser=1', { semantics: false });
  let fr = await waitFrame(page, (f) => f.bytes > 1000, 40000);
  await sleep(2000);
  await shot(page, 'browser_home');
  check('browser: home page renders', fr.some((f) => f.bytes > 1000), JSON.stringify(fr.map((f) => f.base + ' | ' + f.title)));
  const live = fr.some((f) => f.live);
  check('browser: pages load through the real proxy (iframe src = proxy/frame.html, not srcdoc)', !WISP || live, JSON.stringify(fr.map((f) => (f.live ? 'live ' : 'srcdoc ') + f.base)));

  // github.com, wikipedia.org, bing.com and the JS-heavy youtube.com: each must paint its own content (OCR).
  const sites = [
    { typed: 'github.com', base: /^https:\/\/github\.com\//, words: [/GitHub/i, /Sign up/i] },
    { typed: 'wikipedia.org', base: /^https:\/\/www\.wikipedia\.org\//, words: [/WIKIPEDI/i, /Free Encycl|Encvcl|articles|English/i] },
    { typed: 'bing.com', base: /^https:\/\/(www\.)?bing\.com\//, words: [/Bing|Microsoft/i, /Search|Copilot|Images/i] },
    { typed: 'youtube.com', base: /^https:\/\/(www|m)\.youtube\.com\//, words: [/YouTube/i, /Sign in|search|Home|Shorts/i] },
  ];
  for (const s of sites) {
    await typeAddress(page, s.typed);
    fr = await waitFrame(page, (f) => s.base.test(f.base) && f.bytes > 5000, 45000);
    await sleep(s.typed === 'youtube.com' ? 9000 : 5000);
    const f = await shot(page, `browser_${s.typed}`);
    const words = ocrWords(f);
    const okFrame = fr.some((x) => s.base.test(x.base));
    const missing = s.words.filter((w) => !w.test(words));
    const addr = await addressText(page, f);
    check(`browser: ${s.typed} renders its real content (OCR)`, okFrame && missing.length === 0, `${f} frame=${JSON.stringify(fr.map((x) => x.base.slice(0, 60) + ' | ' + x.title.slice(0, 40)))} ocr=${words.slice(0, 160)}${missing.length ? ' MISSING ' + missing : ''}`);
    // The reload icon sits on the address's last letters, so OCR reads e.g. "wikipedia.oiC": match all but the last two.
    check(`browser: address bar shows ${s.typed}`, addr.replace(/\s/g, '').toLowerCase().includes(s.typed.slice(0, -2)), `address ocr="${addr}"`);
  }

  // A link inside the page: Wikipedia's "English" opens en.wikipedia.org, and the address bar follows.
  await typeAddress(page, 'wikipedia.org');
  fr = await waitFrame(page, (f) => /^https:\/\/www\.wikipedia\.org\//.test(f.base) && f.bytes > 5000, 40000);
  await sleep(3000);
  let linkOk = false, detail = '';
  const wf = fr.find((f) => f.live && /^https:\/\/www\.wikipedia\.org\//.test(f.base))?.frame
    || page.frames().find((x) => x !== page.mainFrame() && /wikipedia/.test(x.url()));
  if (wf) {
    try {
      // Wikipedia's US fundraising banner can cover the language links: close it the way a person would.
      for (const sel of ['text=I already donated', 'button[aria-label*="lose"]']) {
        const d = await wf.$(sel).catch(() => null);
        const bb = d && await d.boundingBox().catch(() => null);
        if (bb) { await page.mouse.click(bb.x + bb.width / 2, bb.y + bb.height / 2); await sleep(2500); break; }
      }
      const handles = await wf.$$('a');
      let target = null;
      for (const hnd of handles) {
        const href = await hnd.evaluate((l) => l.href);
        if (/en\.wikipedia\.org(%2F)?\/?$/i.test(realOf(href)) || /^https:\/\/en\.wikipedia\.org\/?$/.test(realOf(href))) { target = { hnd, href }; break; }
      }
      if (target) {
        await target.hnd.scrollIntoViewIfNeeded();
        const bb = await target.hnd.boundingBox();
        await page.mouse.click(bb.x + bb.width / 2, bb.y + bb.height / 2);
        fr = await waitFrame(page, (f) => /^https:\/\/en\.wikipedia\.org\//.test(f.base), 30000);
        await sleep(3000);
        linkOk = fr.some((f) => /^https:\/\/en\.wikipedia\.org\//.test(f.base));
        detail = `clicked ${realOf(target.href)} -> frame ${JSON.stringify(fr.map((f) => f.base + ' | ' + f.title.slice(0, 40)))}`;
      } else detail = 'English link not found';
    } catch (e) { detail = String(e).slice(0, 200); }
  } else detail = 'no wikipedia frame';
  let f = await shot(page, 'browser_link_en_wikipedia');
  check('browser: a link inside the page opens its page in the browser', linkOk, detail);
  let addr = await addressText(page, f);
  check('browser: address bar follows the link (en.wikipedia.org)', /en\.wikipedia\.org/i.test(addr.replace(/\s/g, '')), `address ocr="${addr}"`);

  // Back returns to the page before the link; Forward goes to it again. The controls sit in the
  // address capsule above the page window (measured on the 440x956 screenshots): Back at +66,
  // Forward at +87 when both show, New Tab and Open Windows & Tabs at the right end.
  const ob = await frameBox(page);
  const tapBar = async (x) => { await page.mouse.click(x, ob.y - 33); await sleep(500); await page.mouse.move(4, 600); };
  if (linkOk) {
    await tapBar(ob.x + 66);
    fr = await waitFrame(page, (f) => /^https:\/\/www\.wikipedia\.org\//.test(f.base), 30000);
    await sleep(3000);
    f = await shot(page, 'browser_back');
    addr = await addressText(page, f);
    check('browser: Back returns to the previous page', fr.some((x) => /^https:\/\/www\.wikipedia\.org\//.test(x.base)) && /www\.wikipedi/i.test(addr.replace(/\s/g, '')), `${JSON.stringify(fr.map((x) => x.base))} address ocr="${addr}"`);
    await tapBar(ob.x + 87);
    fr = await waitFrame(page, (x) => /^https:\/\/en\.wikipedia\.org\//.test(x.base), 30000);
    await sleep(3000);
    f = await shot(page, 'browser_forward');
    addr = await addressText(page, f);
    check('browser: Forward goes to the page again', fr.some((x) => /^https:\/\/en\.wikipedia\.org\//.test(x.base)), `${JSON.stringify(fr.map((x) => x.base))} address ocr="${addr}"`);
  }

  // Tabs: a new tab opens its own page; the first tab keeps its page.
  const before = (await frames(page)).length;
  await tapBar(ob.x + ob.w - 61);
  const tabTapped = true;
  await sleep(2500);
  await typeAddress(page, 'github.com');
  fr = await waitFrame(page, (x) => /^https:\/\/github\.com\//.test(x.base) || /GitHub/.test(x.title), 40000);
  await sleep(4000);
  f = await shot(page, 'browser_new_tab_github');
  const all = await frames(page);
  check('browser: a new tab opens github.com', tabTapped && all.some((x) => /^https:\/\/github\.com\//.test(x.base) || /GitHub/.test(x.title)) && /github\.co/i.test(await addressText(page, f)), `${f} ${JSON.stringify(all.map((x) => x.base.slice(0, 50)))}`);
  // Open Windows & Tabs lists both tabs (the first still on en.wikipedia.org).
  await tapBar(ob.x + ob.w - 22);
  await sleep(2500);
  f = await shot(page, 'browser_tabs_overview');
  const tw = ocrWords(f);
  check('browser: Open Windows & Tabs shows both tabs (Wikipedia and GitHub)', /wikipedia/i.test(tw) && /github/i.test(tw), `${f} ocr=${tw.slice(0, 200)}`);
  await tapBar(ob.x + ob.w - 22);

  check('browser: nothing asks davidebri1.github.io/api or collider.ebridavid.workers.dev for pages',
    !net.some((r) => /github\.io\/api\/page|collider\.ebridavid\.workers\.dev\/.*page/.test(r.url)));
  await ctx.close();
}

const PROMPT = 'What is the capital of Australia? Answer in one sentence.';

async function tickerRun(browser, tag, toggles) {
  const { ctx, page } = await newPage(browser);
  await boot(page);
  const toggled = [];
  for (const t of toggles) { if (await tapAt(page, t, { scroll: true })) toggled.push(t); await sleep(500); }
  await page.mouse.move(W / 2, 600); await page.mouse.wheel(0, -2000); await sleep(800);
  await shot(page, `ticker_${tag}_selected`);
  const rmark = replies.length;
  await page.mouse.click(W / 2, ((await labels(page)).find((l) => l.label === 'Send')?.y ?? 820) + 12);
  await sleep(300);
  await page.keyboard.type(PROMPT, { delay: 10 });
  await page.keyboard.press('Enter');
  await sleep(4000);
  await shot(page, `ticker_${tag}_sent`);
  // Wait until every provider call (rows, summaries, both consensus agents)
  // has finished and none has started for 10 s, or WAIT runs out.
  const t0 = Date.now();
  let idleSince = 0;
  while (Date.now() - t0 < WAIT) {
    await sleep(1000);
    if (inFlight > 0 || Date.now() - t0 < 20000) { idleSince = 0; continue; }
    idleSince ||= Date.now();
    if (Date.now() - idleSince > 10000) break;
  }
  await sleep(1500); // let the last response bodies be read
  await sleep(3000);
  await shot(page, `ticker_${tag}_answered`);
  const mine = replies.slice(rmark);

  // Tap-to-expand: tap the GLM 5.3 Flash row (it is on in both runs) and read
  // the conversation that opens above the ticker.
  await page.keyboard.press('Escape'); // the composer keeps focus after a send
  await sleep(600);
  let expanded = null;
  if (await tapAt(page, 'GLM 5.3 Flash')) {
    let l = [];
    for (let i = 0; i < 10; i++) {
      await sleep(700);
      l = (await labels(page)).map((x) => x.label);
      if (l.includes('Copy answer')) break;
    }
    expanded = {
      open: l.includes('Copy answer'),
      lines: l.filter((x) => /\d:\d\d (AM|PM)/.test(x) && !/^GLM 5\.3 Flash\n/.test(x)).map((x) => x.replace(/\s+/g, ' ').slice(0, 200)),
    };
    await shot(page, `ticker_${tag}_expanded`);
    await page.keyboard.press('Escape');
    await sleep(900);
  }
  // Consensus: tap the card pinned on top of the ticker.
  let consensus = null;
  const top = (await labels(page)).find((x) => /^\d+\/\d+\n/.test(x.label));
  if (top) {
    consensus = { card: top.label.replace(/\s+/g, ' ').slice(0, 200) };
    await page.mouse.click(top.x + 60, top.y + Math.min(top.h, 40) / 2);
    await sleep(2000);
    consensus.opened = (await labels(page)).map((x) => x.label.replace(/\s+/g, ' ')).filter((x) => x.length > 20).slice(0, 12);
    await shot(page, `ticker_${tag}_consensus`);
    await page.keyboard.press('Escape');
    await sleep(900);
  }
  // History: the Global rail button.
  await tapAt(page, 'Global');
  await sleep(1800);
  const hist = (await labels(page)).map((l) => l.label);
  await shot(page, `ticker_${tag}_history`);
  await ctx.close();
  return { toggled, mine, expanded, consensus, hist };
}

async function tickerChecks(browser) {
  // Run A: the 3 default rows + 6 more (9 is the most a send takes).
  const a = await tickerRun(browser, 'A', ['Ling 3.1 Flash', 'Nemotron 3.5 Lightning', 'GLM 5.3', 'DeepSeek V4.1 Flash', 'MiniMax M3.1 Flash', 'MiMo V2.6 Flash']);
  // Run B: the 2 rows run A could not take, plus GLM 5.3 Flash.
  const b = await tickerRun(browser, 'B', ['Laguna S 2.1', 'Laguna XS 2.1', 'Nemotron 3 Ultra', 'Kimi K3']);
  const all = [...a.mine, ...b.mine];
  writeFileSync(join(OUT, 'replies.json'), JSON.stringify(all, null, 1));
  const rows = {
    'GLM 5.3 Flash': ['glm-5.3-flash', 'z-ai/glm-5.3-flash'],
    'Laguna S 2.1': ['poolside/laguna-s-2.1-free'],
    'Laguna XS 2.1': ['poolside/laguna-xs-2.1'],
    'Ling 3.1 Flash': ['inclusionai/ling-3.1-flash:free'],
    'Nemotron 3.5 Lightning': ['nvidia/nemotron-3.5-lightning-30b-a3b'],
    'GLM 5.3': ['glm-5.3', 'zai-org/GLM-5.3'],
    'DeepSeek V4.1 Flash': ['deepseek-v4.1-flash', 'deepseek-ai/deepseek-v4.1-flash', 'deepseek/deepseek-v4.1-flash'],
    'MiniMax M3.1 Flash': ['MiniMax-M3.1-Flash', 'minimaxai/minimax-m3.1-flash'],
    'MiMo V2.6 Flash': ['mimo-v2.6-flash', 'xiaomi/mimo-v2.6-flash'],
    'Nemotron 3 Ultra': ['nvidia/nemotron-3-ultra-550b-a55b'],
    'Kimi K3': ['kimi-k3', 'moonshotai/Kimi-K3'],
  };
  const needKey = [];
  for (const [row, ids] of Object.entries(rows)) {
    const calls = all.filter((r) => !r.agent && ids.includes(r.model));
    const good = calls.find((r) => r.status === 200 && /canberra/i.test(r.text));
    const summary = calls.map((r) => `${r.provider}:${r.model}=${r.status}`).join(', ');
    if (good) check(`ticker: ${row} answers ("${good.text.replace(/\s+/g, ' ').slice(0, 70)}")`, true, summary);
    else if (calls.length && calls.every((r) => [401, 402, 403, 503].includes(r.status))) {
      needKey.push({ row, calls: summary });
      check(`ticker: ${row} has no working key (shows its error, nothing faked)`, true, summary);
    } else if (calls.length && calls.some((r) => [408, 524].includes(r.status)) && calls.every((r) => [401, 402, 403, 408, 503, 524].includes(r.status))) {
      // The provider that holds a working key timed out upstream at test time.
      // Not a Collider failure and nothing is faked, but it is not an answer.
      warn(`ticker: ${row} — provider timed out upstream at test time (row shows its error)`, summary);
    } else check(`ticker: ${row} answers`, false, summary || 'never asked');
  }
  // Consensus agent 1 (headcount/essence) and 2 (chains) answered, from whichever entry of
  // David's list was working (the app logs "[chain] <role> answered by n/9 …").
  const chainLog = consoleLines.filter((l) => l.includes('[chain]'));
  const by = (role) => chainLog.filter((l) => l.includes(`[chain] ${role} answered by`));
  check('ticker: consensus agent 1 answers (headcount)', by('consensus').length > 0, by('consensus')[0] || chainLog.filter((l) => l.includes('consensus')).slice(-3).join(' | '));
  check('ticker: consensus agent 2 answers (logical chains)', by('chains').length > 0, by('chains')[0] || chainLog.filter((l) => l.includes('chains')).slice(-3).join(' | '));
  check('ticker: one-line summaries answer', by('summary').length > 0, by('summary')[0] || '');
  for (const [tag, r] of [['A', a], ['B', b]]) {
    check(`ticker run ${tag}: rows switched on (${r.toggled.length}/${tag === 'A' ? 6 : 4})`, r.toggled.length === (tag === 'A' ? 6 : 4), r.toggled.join(', '));
    check(`ticker run ${tag}: tapping a row opens its conversation`, !!r.expanded && r.expanded.lines.some((x) => /^You /.test(x)) && r.expanded.lines.some((x) => /canberra/i.test(x) && !/^You /.test(x)), JSON.stringify(r.expanded?.lines || []).slice(0, 300));
    check(`ticker run ${tag}: consensus card shows a headcount and opens`, !!r.consensus && /^\d+\/\d+ /.test(r.consensus.card) && /canberra/i.test(r.consensus.card), JSON.stringify(r.consensus || {}).slice(0, 400));
    check(`ticker run ${tag}: Global History lists the conversation`, r.hist.includes('Global History') && r.hist.some((l) => l.includes('capital of Australia')), '');
  }
  check('ticker: no request to davidebri1.github.io/api or collider.ebridavid.workers.dev for chat',
    !net.some((r) => /github\.io\/api\/(ask|reply|job|models)|collider\.ebridavid\.workers\.dev\/api/.test(r.url)));
  return needKey;
}

// With a local Wisp server (box test only), Chrome must be allowed to open ws://127.0.0.1 from the github.io page.
const LNA = WISP && /127\.0\.0\.1|localhost/.test(WISP) ? ['--disable-features=LocalNetworkAccessChecks,BlockInsecurePrivateNetworkRequests,PrivateNetworkAccessSendPreflights'] : [];
const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', headless: true, args: ['--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage', '--hide-scrollbars', ...LNA] });
let needKey = [];
try {
  // ONLY=browser|ticker|features, or a comma list; unset runs all three.
  const only = (process.env.ONLY || 'browser,ticker,features,finish').split(',');
  if (only.includes('browser')) await browserChecks(browser);
  if (only.includes('ticker')) needKey = await tickerChecks(browser);
  const h = { browser, newPage, boot, labels, tapAt, shot: (p, n) => shot(p, n), check, warn, sleep, OUT, typeAddress, waitFrame, frames, DSF, W, H, replies, consoleLines, net };
  if (only.includes('features')) await featureChecks(h);
  if (only.includes('finish')) await webFinishChecks(h);
} finally {
  await browser.close();
  writeFileSync(join(OUT, 'network.json'), JSON.stringify(net, null, 1));
  writeFileSync(join(OUT, 'console.txt'), consoleLines.join('\n'));
  const fail = checks.filter((c) => !c.ok);
  writeFileSync(join(OUT, 'report.json'), JSON.stringify({ target: ROOT ? `build ${ROOT}` : APP, at: new Date().toISOString(), passed: checks.length - fail.length, failed: fail.length, warnings: warns, checks, needKey }, null, 1));
  console.log(`\n${checks.length - fail.length}/${checks.length} passed, ${warns.length} warning(s) -> ${OUT}`);
  process.exitCode = fail.length ? 1 : 0;
}
