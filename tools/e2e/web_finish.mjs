/**
 * Web finish (Nov 7) checks, called from browser_ticker.mjs (ONLY=finish):
 *  - every screen at 440x956 (device scale 2): nothing cut off at the pane or screen edge;
 *  - Smart Gen names follow briefs/smart-gen-docs (boards = work areas, canvases sit on them);
 *  - attachments (image, PDF, DOCX) reach the models and the replies use their contents;
 *  - MiniMax answering 402: consensus, summaries and Genie answer from the next entry of
 *    David's Oct 11 list (the app logs "[chain] <role> answered by n/9 …").
 */
import { execFileSync } from 'child_process';
import { join } from 'path';
import { ocr, painted } from './backup_features.mjs';

export const SCREENS = [
  ['home', ''],
  ['browser', '?browser=1'],
  ['smartgen', '?app=smartgen'],
  ['smartgen_canvas', '?app=smartgen&sg=canvas'],
  ['smartgen_genie', '?app=smartgen&sg=genie'],
  ['files', '?app=files'],
  ['themes', '?app=themes'],
  ['market', '?app=market'],
  ['premium', '?app=premium'],
  ['music', '?app=music'],
  ['consensus', '?app=consensus'],
  ['apps', '?app=apps'],
  ['settings', '?settings=1'],
];

/** Panes (labelled nodes at least 160 wide or tall) that run past the screen edge. Chips in a
 *  sideways-scrolling row are left out: being partly off screen is how such a row scrolls. */
async function cutOff(h, page) {
  const out = [];
  for (const l of await h.labels(page)) {
    if (l.w < 2 || l.h < 2 || (l.w < 160 && l.h < 160)) continue;
    if (l.x + l.w < 0 || l.x > h.W) continue;
    if (l.x < -1 || l.x + l.w > h.W + 1 || l.y + l.h > h.H + 1) out.push(`${l.label.replace(/\s+/g, ' ').slice(0, 40)} @${Math.round(l.x)},${Math.round(l.y)} ${Math.round(l.w)}x${Math.round(l.h)}`);
  }
  return out;
}

export async function screensTour(h, only = null) {
  const { page, ctx } = await h.newPage(h.browser);
  for (const [name, q] of SCREENS) {
    if (only && !only.includes(name)) continue;
    await h.boot(page, q);
    await h.sleep(2500);
    const f = await h.shot(page, `screen_${name}`);
    const cut = await cutOff(h, page);
    h.check(`screen ${name}: nothing cut off at 440x956`, cut.length === 0, `${f}${cut.length ? ' CUT ' + JSON.stringify(cut.slice(0, 8)) : ''}`);
  }
  await ctx.close();
}

export async function webFinishChecks(h) {
  const parts = (process.env.FINISH || 'screens,names,attach,fallback').split(',');
  if (parts.includes('screens')) await screensTour(h, process.env.SCREENS ? process.env.SCREENS.split(',') : null);
  if (parts.includes('names')) await smartGenNames(h);
  if (parts.includes('attach')) await attachments(h);
  if (parts.includes('fallback')) await fallback402(h);
}

const FILES = process.env.ATTACH_DIR || '/workspace/webfinish/files';

/** Waits until no provider call has started or finished for [quiet] ms (or [max] passes). */
async function settle(h, page, max = 150000, quiet = 12000) {
  const t0 = Date.now();
  let last = Date.now(), n = h.net.length;
  while (Date.now() - t0 < max) {
    await h.sleep(1000);
    if (h.net.length !== n) { n = h.net.length; last = Date.now(); }
    if (Date.now() - t0 > 25000 && Date.now() - last > quiet) break;
  }
}

async function sendFromComposer(h, page, text) {
  const send = (await h.labels(page)).find((l) => l.label === 'Send');
  await page.mouse.click(h.W / 2, (send?.y ?? 820) + 12);
  await h.sleep(300);
  await page.keyboard.type(text, { delay: 8 });
  await page.keyboard.press('Enter');
}

/** (5) An image, a PDF and a DOCX attached with the composer's + reach the models. */
async function attachments(h) {
  const { page, ctx } = await h.newPage(h.browser);
  const sent = [];
  page.on('request', (q) => { if (/\/api\/p\?u=/.test(q.url()) && q.method() === 'POST') sent.push({ u: new URL(q.url()).searchParams.get('u'), body: q.postData() || '' }); });
  await h.boot(page);
  const chooser = page.waitForEvent('filechooser', { timeout: 15000 }).catch(() => null);
  await h.tapAt(page, 'More');
  const fc = await chooser;
  if (fc) await fc.setFiles([join(FILES, 'photo.png'), join(FILES, 'note.pdf'), join(FILES, 'brief.docx')]);
  await h.sleep(2500);
  const fChips = await h.shot(page, 'attach_chips');
  let [ok, d] = painted(h.OUT, fChips, ['photo.png', 'note.pdf', 'brief.docx']);
  h.check('attachments: image, PDF and DOCX are attached in the composer', !!fc && ok, d);
  const mark = h.replies.length;
  await sendFromComposer(h, page, 'Using the three attached files: what word is in the picture, what fruit is in the PDF, and what mountain is in the document? Answer in one line.');
  await h.sleep(4000);
  await settle(h, page);
  await h.sleep(3000);
  const fAns = await h.shot(page, 'attach_answered');
  const bodies = sent.map((x) => x.body);
  h.check('attachments: the PDF text (TANGERINE) is sent to the models', bodies.some((b) => b.includes('TANGERINE')), `${sent.length} requests`);
  h.check('attachments: the DOCX text (KILIMANJARO) is sent to the models', bodies.some((b) => b.includes('KILIMANJARO')), '');
  const asImage = sent.filter((x) => /"image_url"/.test(x.body) && /data:image\/png;base64,/.test(x.body));
  const described = sent.filter((x) => /\[Attached image, described:/.test(x.body));
  h.check('attachments: the image goes as an image to vision models and as a description to the rest', asImage.length > 0, `as image: ${asImage.map((x) => x.u + ':' + (JSON.parse(x.body).model || '')).join(', ')}; described: ${described.length}`);
  const mine = h.replies.slice(mark).filter((r) => r.status === 200);
  const txt = mine.map((r) => r.text).join('\n');
  const hit = (re) => mine.filter((r) => re.test(r.text)).map((r) => r.model);
  h.check('attachments: replies name the picture word (PELICAN)', /pelican/i.test(txt), JSON.stringify(hit(/pelican/i)));
  h.check('attachments: replies name the PDF fruit (TANGERINE)', /tangerine/i.test(txt), JSON.stringify(hit(/tangerine/i)));
  h.check('attachments: replies name the DOCX mountain (KILIMANJARO)', /kilimanjaro/i.test(txt), JSON.stringify(hit(/kilimanjaro/i)));
  const words = (ocr(join(h.OUT, fAns)) || []).join(' ');
  h.check('attachments: the answer on screen uses the files (OCR)', /pelica|tangerin|kilimanjar/i.test(words), `${fAns} ocr=${words.slice(0, 220)}`);
  await ctx.close();
}

const chainLines = (h, from) => h.consoleLines.slice(from).filter((l) => l.includes('[chain]'));

/** (8) MiniMax answers 402: consensus, summaries and Genie answer from the next entry of the list. */
async function fallback402(h) {
  const { page, ctx } = await h.newPage(h.browser);
  const forced = [];
  await ctx.route(/\/api\/p\?u=minimax\b/, (route) => { forced.push(route.request().url()); route.fulfill({ status: 402, body: JSON.stringify({ error: { message: 'insufficient balance (e2e: forced 402)' } }), headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*' } }); });
  const c0 = h.consoleLines.length;
  await h.boot(page);
  await sendFromComposer(h, page, 'What is the capital of Australia? Answer in one sentence.');
  // Each role answers (or fails through all 9 entries); a hung entry is dropped after 40 s.
  const t0 = Date.now();
  const done = (role) => chainLines(h, c0).some((l) => new RegExp(`\\[chain\\] ${role} (answered by|9/9 )`).test(l));
  while (Date.now() - t0 < 420000 && !['consensus', 'summary', 'chains'].every(done)) await h.sleep(2000);
  await h.sleep(6000);
  const fT = await h.shot(page, 'fallback_ticker_answered');
  const lines = chainLines(h, c0);
  const answered = (role) => lines.filter((l) => new RegExp(`\\[chain\\] ${role} answered by`).test(l));
  h.check('fallback: MiniMax direct was forced to 402', forced.length > 0, `${forced.length} MiniMax call(s) answered 402`);
  for (const role of ['consensus', 'summary', 'chains']) {
    const a = answered(role);
    h.check(`fallback: ${role} answers with MiniMax at 402`, a.length > 0 && a.every((l) => !/answered by 1\//.test(l)), (a[0] || 'no answer') + ' | ' + lines.filter((l) => l.includes(`] ${role} `) && l.includes('failed')).slice(0, 4).join(' | '));
  }
  // The consensus card on screen (top of the ticker) reads Canberra.
  const top = (await h.labels(page)).find((x) => /^\d+\/\d+\n/.test(x.label));
  h.check('fallback: the consensus card shows the answer (Canberra)', !!top && /canberra/i.test(top.label), (top?.label || '').replace(/\s+/g, ' ').slice(0, 160));
  let [ok, d] = painted(h.OUT, fT, ['Canberra']);
  h.check('fallback: the answer is painted on screen (OCR)', ok, d);
  // Genie (Smart Gen), same list.
  const c1 = h.consoleLines.length;
  await h.boot(page, '?app=smartgen&sg=canvas'); // makes the first board, so Genie has one to edit
  await h.sleep(1500);
  await h.boot(page, '?app=smartgen&sg=genie');
  await h.sleep(1500);
  await h.tapAt(page, 'Message Genie');
  await h.sleep(500);
  await page.keyboard.type('Add a card called Pack umbrella to To Do.', { delay: 8 });
  await page.keyboard.press('Enter');
  const g0 = Date.now();
  while (Date.now() - g0 < 300000 && !chainLines(h, c1).some((l) => /\[chain\] genie (answered by|9\/9 )/.test(l))) await h.sleep(2000);
  await h.sleep(4000);
  const fG = await h.shot(page, 'fallback_genie_answered');
  const g = chainLines(h, c1).filter((l) => /\[chain\] genie answered by/.test(l));
  h.check('fallback: Genie answers with MiniMax at 402', g.length > 0 && g.every((l) => !/answered by 1\//.test(l)), (g[0] || 'no answer') + ' | ' + chainLines(h, c1).filter((l) => l.includes('genie') && l.includes('failed')).slice(0, 4).join(' | '));
  [ok, d] = painted(h.OUT, fG, ['Pack umbrella']);
  h.check('fallback: Genie\'s change is painted on screen (OCR "Pack umbrella")', ok, d);
  await ctx.close();
}

/** (2) Smart Gen names: the board-kind choices are the spec's work areas; canvas names are the spec's. */
async function smartGenNames(h) {
  const { page, ctx } = await h.newPage(h.browser);
  await h.boot(page, '?app=smartgen&sg=canvas');
  await h.sleep(1500);
  const fV = await h.shot(page, 'names_views');
  const lab = (await h.labels(page)).map((l) => l.label).join(' | ');
  h.check('names: no old names (Photo album, Portfolio desk) on the Smart Gen screen', !/Photo album|Portfolio desk/.test(lab), lab.slice(0, 300));
  await h.tapAt(page, 'Board menu');
  await h.sleep(1200);
  // The menu scrolls; bring "Board kind" up.
  for (let i = 0; i < 8; i++) {
    const bk = (await h.labels(page)).find((l) => l.label === 'Board kind');
    if (bk && bk.y < h.H - 260) break;
    await page.mouse.move(h.W / 2, 600); await page.mouse.wheel(0, 240); await h.sleep(600);
  }
  const fK = await h.shot(page, 'names_board_kind');
  const all = (await h.labels(page)).map((l) => l.label);
  const want = ['Kanban Board with Swim lanes', 'Whiteboard', 'Long wood bench', 'Workbench', 'Desk', 'Wood round table', 'Wood Coffee Table'];
  const missing = want.filter((w) => !all.includes(w));
  const wrong = ['notebook', 'portfolio', 'corkboard', 'clipboard', 'ledger', 'binder', 'slate'].filter((w) => all.includes(w));
  h.check('names: Board kind offers the spec\'s work areas, not canvas objects', missing.length === 0 && wrong.length === 0, `${fK} missing=${JSON.stringify(missing)} wrong=${JSON.stringify(wrong)}`);
  const [ok, d] = painted(h.OUT, fK, ['Board kind', 'Workbench']);
  h.check('names: Board kind choices are painted (OCR)', ok, d);
  await ctx.close();
}
