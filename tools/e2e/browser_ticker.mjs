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
 * Env: CHROME (default /usr/bin/google-chrome), PLAYWRIGHT_CORE (path to
 * playwright-core), TICKER_WAIT_S (default 150).
 */
import { createRequire } from 'module';
import { mkdirSync, writeFileSync, readFileSync, existsSync, statSync } from 'fs';
import { join, extname, resolve } from 'path';

const require = createRequire(import.meta.url);
const PW = process.env.PLAYWRIGHT_CORE || '/usr/local/lib/pnpm/5/.pnpm/playwright-core@1.59.1/node_modules/playwright-core';
const { chromium } = require(PW);

const APP = 'https://davidebri1.github.io/collider-app/';
const ROOT = process.env.ROOT ? resolve(process.env.ROOT) : null;
const OUT = resolve(process.env.OUT || 'e2e-out');
const WAIT = Number(process.env.TICKER_WAIT_S || 150) * 1000;
const W = 440, H = 956;
mkdirSync(OUT, { recursive: true });

const MIME = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.webp': 'image/webp', '.mp4': 'video/mp4' };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const checks = [];
const check = (name, ok, detail = '') => { checks.push({ name, ok: !!ok, detail }); console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`); };
const net = [], consoleLines = [], replies = [];
let shotN = 0;

async function newPage(browser) {
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  if (ROOT) {
    await ctx.route(/^https:\/\/davidebri1\.github\.io\/collider-app\//, async (route) => {
      let p = decodeURIComponent(new URL(route.request().url()).pathname.replace(/^\/collider-app\//, '/'));
      if (p === '/' || p === '') p = '/index.html';
      const f = join(ROOT, p);
      if (!f.startsWith(ROOT) || !existsSync(f) || statSync(f).isDirectory()) return route.fulfill({ status: 404, body: 'missing' });
      return route.fulfill({ status: 200, body: readFileSync(f), headers: { 'content-type': MIME[extname(f)] || 'application/octet-stream', 'cache-control': 'no-store' } });
    });
  }
  const page = await ctx.newPage();
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
  await page.goto(APP + q, { waitUntil: 'networkidle', timeout: 120000 });
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

const shot = async (page, name) => { const f = `${String(++shotN).padStart(2, '0')}_${name}.png`; await page.screenshot({ path: join(OUT, f) }); return f; };

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

/** The browser frame(s): title and base address of the markup on screen. */
const frames = (page) => page.evaluate(() => {
  const out = [];
  const walk = (e) => {
    if (e.tagName === 'IFRAME') {
      const sd = e.getAttribute('srcdoc') || '';
      out.push({ src: e.src || '', title: ((sd.match(/<title[^>]*>([^<]*)/i) || [])[1] || '').trim(), base: (sd.match(/<base href="([^"]*)"/) || [])[1] || '', bytes: sd.length });
    }
    for (const c of e.children || []) walk(c);
    if (e.shadowRoot) for (const c of e.shadowRoot.children) walk(c);
  };
  walk(document.body);
  return out;
});

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

async function browserChecks(browser) {
  const { ctx, page } = await newPage(browser);
  await boot(page, '?browser=1', { semantics: false });
  let fr = await waitFrame(page, (f) => f.bytes > 1000);
  await shot(page, 'browser_home');
  check('browser: home page renders', fr.some((f) => f.bytes > 1000), JSON.stringify(fr.map((f) => f.title)));

  const sites = [
    { typed: 'wikipedia.org', want: /Wikipedia/i, base: /^https:\/\/www\.wikipedia\.org\// },
    { typed: 'github.com', want: /GitHub/i, base: /^https:\/\/github\.com\// },
    { typed: 'bbc.com', want: /BBC/i, base: /^https:\/\/www\.bbc\.com\//, knownBlocked: true },
  ];
  for (const s of sites) {
    await typeAddress(page, s.typed);
    fr = await waitFrame(page, (f) => s.base.test(f.base) && s.want.test(f.title));
    await sleep(2500);
    const f = await shot(page, `browser_${s.typed}`);
    const ok = fr.some((x) => s.base.test(x.base) && s.want.test(x.title));
    const proxied = net.filter((r) => r.url.includes('/page?url=') && r.url.includes(encodeURIComponent(s.typed))).map((r) => r.status);
    if (s.knownBlocked && !ok) {
      check(`browser: ${s.typed} (page proxy answers ${proxied.join(',') || 'nothing'}; shows "could not be loaded")`, proxied.every((x) => x !== 200), `${f}`);
    } else {
      check(`browser: ${s.typed} shows ${s.typed}`, ok, `${f} frame=${JSON.stringify(fr.map((x) => x.title.slice(0, 50)))} proxy=${proxied}`);
    }
  }

  // Links: open Wikipedia, tap the "English" link inside the page.
  await typeAddress(page, 'wikipedia.org');
  await waitFrame(page, (f) => /^https:\/\/www\.wikipedia\.org\//.test(f.base));
  await sleep(3000);
  let wf = null;
  for (const x of page.frames()) {
    if (x === page.mainFrame()) continue;
    try { if (/www\.wikipedia\.org/.test(await x.evaluate(() => document.baseURI))) wf = x; } catch {}
  }
  let linkOk = false, detail = '';
  if (wf) {
    try {
      const a = await wf.evaluate(() => {
        const l = [...document.links].find((x) => /\/\/en\.wikipedia\.org\/?$/.test(x.href) && x.getBoundingClientRect().height > 0);
        if (!l) return null;
        l.scrollIntoView({ block: 'center' });
        const r = l.getBoundingClientRect();
        return { x: r.x + r.width / 2, y: r.y + r.height / 2, href: l.href };
      });
      if (a) {
        const box = await (await wf.frameElement()).boundingBox();
        await page.mouse.click(box.x + a.x, box.y + a.y);
        fr = await waitFrame(page, (f) => /^https:\/\/en\.wikipedia\.org\//.test(f.base), 30000);
        await sleep(2500);
        linkOk = fr.some((f) => /^https:\/\/en\.wikipedia\.org\//.test(f.base));
        detail = `clicked ${a.href} -> frame ${JSON.stringify(fr.map((f) => f.base + ' | ' + f.title.slice(0, 40)))}`;
      } else detail = 'English link not found';
    } catch (e) { detail = String(e).slice(0, 200); }
  } else detail = 'no srcdoc frame';
  await shot(page, 'browser_link_en_wikipedia');
  check('browser: a link inside the page opens its page in the browser', linkOk, detail);

  // Back returns to the page before the link.
  if (linkOk) {
    // Back: the arrow at the left end of the address capsule.
    const b = await frameBox(page);
    await page.mouse.click(b.x + 26, b.y - 33);
    fr = await waitFrame(page, (f) => /^https:\/\/www\.wikipedia\.org\//.test(f.base), 30000);
    await sleep(2000);
    await shot(page, 'browser_back');
    check('browser: Back returns to the previous page', fr.some((f) => /^https:\/\/www\.wikipedia\.org\//.test(f.base)), JSON.stringify(fr.map((f) => f.base)));
  }

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
  // Wait until no provider call has finished for 20 s (after at least 40 s), or WAIT runs out.
  const t0 = Date.now();
  while (Date.now() - t0 < WAIT) {
    await sleep(2000);
    const lastAt = net.filter((r) => /\/api\/p\?u=/.test(r.url)).map((r) => Date.parse(r.t)).pop() || t0;
    if (Date.now() - lastAt > 20000 && Date.now() - t0 > 40000) break;
  }
  await sleep(3000);
  await shot(page, `ticker_${tag}_answered`);
  const mine = replies.slice(rmark);

  // Tap-to-expand: tap the GLM 5.3 Flash row (it is on in both runs) and read
  // the conversation that opens above the ticker.
  await page.keyboard.press('Escape'); // the composer keeps focus after a send
  await sleep(600);
  let expanded = null;
  if (await tapAt(page, 'GLM 5.3 Flash')) {
    await sleep(2000);
    const l = (await labels(page)).map((x) => x.label);
    if (l.includes('Copy answer')) {
      expanded = { lines: l.filter((x) => /\d:\d\d (AM|PM)/.test(x) && !/^GLM 5\.3 Flash/.test(x)).map((x) => x.replace(/\s+/g, ' ').slice(0, 200)) };
    }
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
    } else check(`ticker: ${row} answers`, false, summary || 'never asked');
  }
  // Consensus agent 1 (headcount/essence) and 2 (chains) ran on real replies.
  const cons = all.filter((r) => r.agent && /minimax-m3\.1-flash/i.test(r.model) && r.status === 200 && /RATIO:/i.test(r.text));
  check('ticker: consensus agent 1 (MiniMax M3.1 Flash) returns a headcount', cons.length > 0, cons[0]?.text.replace(/\s+/g, ' ').slice(0, 120));
  const chains = all.filter((r) => r.agent && /deepseek/i.test(r.model) && r.status === 200 && /CHAIN/i.test(r.text));
  check('ticker: consensus agent 2 (DeepSeek V4.1 Flash) returns logical chains', chains.length > 0, chains[0]?.text.replace(/\s+/g, ' ').slice(0, 120));
  for (const [tag, r] of [['A', a], ['B', b]]) {
    check(`ticker run ${tag}: rows switched on (${r.toggled.length}/${tag === 'A' ? 6 : 4})`, r.toggled.length === (tag === 'A' ? 6 : 4), r.toggled.join(', '));
    check(`ticker run ${tag}: tapping a row opens its conversation`, !!r.expanded && r.expanded.lines.some((x) => /canberra/i.test(x)), JSON.stringify(r.expanded?.lines || []).slice(0, 300));
    check(`ticker run ${tag}: consensus card shows a headcount and opens`, !!r.consensus && /^\d+\/\d+ /.test(r.consensus.card) && /canberra/i.test(r.consensus.card), JSON.stringify(r.consensus || {}).slice(0, 400));
    check(`ticker run ${tag}: Global History lists the conversation`, r.hist.includes('Global History') && r.hist.some((l) => l.includes('capital of Australia')), '');
  }
  check('ticker: no request to davidebri1.github.io/api or collider.ebridavid.workers.dev for chat',
    !net.some((r) => /github\.io\/api\/(ask|reply|job|models)|collider\.ebridavid\.workers\.dev\/api/.test(r.url)));
  return needKey;
}

const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', headless: true, args: ['--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage', '--hide-scrollbars'] });
let needKey = [];
try {
  if (process.env.ONLY !== 'ticker') await browserChecks(browser);
  if (process.env.ONLY !== 'browser') needKey = await tickerChecks(browser);
} finally {
  await browser.close();
  writeFileSync(join(OUT, 'network.json'), JSON.stringify(net, null, 1));
  writeFileSync(join(OUT, 'console.txt'), consoleLines.join('\n'));
  const fail = checks.filter((c) => !c.ok);
  writeFileSync(join(OUT, 'report.json'), JSON.stringify({ target: ROOT ? `build ${ROOT}` : APP, at: new Date().toISOString(), passed: checks.length - fail.length, failed: fail.length, checks, needKey }, null, 1));
  console.log(`\n${checks.length - fail.length}/${checks.length} passed -> ${OUT}`);
  process.exitCode = fail.length ? 1 : 0;
}
