/**
 * Checks for the features ported from the Nov 3 backups (FEATURES.md port
 * plan 1–3). Each one is driven by real taps and typing at 440x956, then the
 * page is reloaded in the same browser profile and checked again. Screens are
 * read twice: the accessibility labels Flutter publishes, and the pixels of
 * the screenshot itself (OCR, tools/e2e/ocr.py), so a label that is never
 * painted cannot pass.
 *
 * Called from browser_ticker.mjs (ONLY=features runs just these).
 */
import { execFileSync } from 'child_process';
import { writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const HERE = dirname(fileURLToPath(import.meta.url));
const PY = process.env.OCR_PYTHON || '/workspace/.ocrvenv/bin/python';

function ocrRaw(file) {
  try {
    const out = execFileSync(PY, [join(HERE, 'ocr.py'), file], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    return JSON.parse(out.trim().split('\n').pop());
  } catch (e) {
    return null;
  }
}
export const ocr = (file) => ocrRaw(file)?.lines || null;
/** [[text, x, y], …] in screenshot pixels (divide by the device scale for page points). */
export const ocrBoxes = (file) => ocrRaw(file)?.boxes || null;
/** Screen point of the painted text that starts with [prefix] (OCR). */
export const ocrFind = (file, prefix) => (ocrRaw(file)?.boxes || []).find((b) => b[0].replace(/\s/g, '').toLowerCase().startsWith(prefix.replace(/\s/g, '').toLowerCase()));
const squash = (s) => s.toLowerCase().replace(/[^a-z0-9:&/.]/g, '').replace(/:o\b/g, ':0');
/** Every wanted phrase is painted in the screenshot. Returns [ok, detail]. */
export function painted(OUT, file, wanted) {
  const lines = ocr(join(OUT, file));
  if (!lines) return [false, `${file}: OCR unavailable`];
  const all = squash(lines.join(' '));
  const missing = wanted.filter((w) => !all.includes(squash(w)));
  return [missing.length === 0, `${file} ocr=${JSON.stringify(lines).slice(0, 260)}${missing.length ? ' MISSING ' + JSON.stringify(missing) : ''}`];
}

export async function featureChecks(h) {
  await smartGenCards(h);
  await filesAttach(h);
  await browserSidebar(h);
}

async function tapL(h, page, label, wait = 900) {
  const ok = await h.tapAt(page, label);
  // Park the pointer off the pane so no hover tooltip covers what is read.
  await page.mouse.move(4, 600);
  await h.sleep(wait);
  return ok;
}
const has = async (h, page, label) => (await h.labels(page)).some((l) => l.label === label || l.label.startsWith(label + '\n') || l.label.includes(label));

/** Port 1 — AppFlowy: card title edit + persistence, private notes flip, statistics. */
async function smartGenCards(h) {
  const { page, ctx } = await h.newPage(h.browser);
  const { sleep, check, shot, OUT } = h;
  const type = async (t) => { await page.keyboard.type(t, { delay: 15 }); await sleep(400); };
  await h.boot(page, '?app=smartgen');
  await tapL(h, page, 'Create Project'); await tapL(h, page, 'Project name'); await type('Audit'); await tapL(h, page, 'Create', 1500);
  await tapL(h, page, 'Audit', 1500); await tapL(h, page, 'Create Board'); await tapL(h, page, 'Board Name'); await type('Main'); await tapL(h, page, 'Create', 1500);
  await tapL(h, page, 'Main', 2500);
  await tapL(h, page, 'Add Card', 800); await type('Audit note'); await page.keyboard.press('Enter'); await sleep(1500);
  // Card detail: rename it, write a private note.
  await tapL(h, page, 'Audit note', 2500);
  await page.mouse.click(220, 135); await sleep(700);
  await page.keyboard.press('Control+A'); await type('Audit note saved locally'); await page.keyboard.press('Enter'); await sleep(1200);
  await tapL(h, page, 'Private Notes (Revealed on 180° 3D Flip)', 700);
  await type('Catering confirmed for Friday');
  await sleep(800);
  const fDetail = await shot(page, 'sg_card_private_note');
  let [ok, d] = painted(OUT, fDetail, ['Audit note saved locally', 'Private Notes', 'Catering confirmed for Friday']);
  check('smart gen: card renamed and private note typed (detail screen)', ok, d);
  await tapL(h, page, 'Back', 2000);
  const fFront = await shot(page, 'sg_card_front');
  [ok, d] = painted(OUT, fFront, ['Audit note saved locally']);
  check('smart gen: board shows the renamed card with a flip control', ok && await has(h, page, 'Flip Card to Private Notes (3D)'), d);
  await tapL(h, page, 'Flip Card to Private Notes (3D)', 1200);
  const fBack = await shot(page, 'sg_card_flipped');
  [ok, d] = painted(OUT, fBack, ['Private Notes & Hidden Fields', 'Catering confirmed for Friday']);
  check('smart gen: flip shows the private note on the back of the card', ok, d);
  await tapL(h, page, 'Flip Back to Card Front', 1200);
  [ok, d] = painted(OUT, await shot(page, 'sg_card_flipped_back'), ['Audit note saved locally']);
  check('smart gen: flip back shows the card front', ok, d);
  // A second card in Doing, so the statistics have something to split.
  await page.mouse.move(220, 500); await page.mouse.wheel(360, 0); await sleep(1200);
  const doing = (await h.labels(page)).filter((l) => l.label.startsWith('Add Card')).sort((a, b) => Math.abs(a.x - 75) - Math.abs(b.x - 75));
  if (doing[0]) { await page.mouse.click(doing[0].x + doing[0].w / 2, doing[0].y + doing[0].h / 2); await sleep(800); await type('Second card'); await page.keyboard.press('Enter'); await sleep(1200); }
  await tapL(h, page, 'Board menu', 1200);
  await tapL(h, page, 'Workspace Statistics', 1500);
  const fStats = await shot(page, 'sg_statistics');
  const lab = (await h.labels(page)).map((l) => l.label).join(' | ');
  const statLines = ocr(join(OUT, fStats)) || [];
  [ok, d] = painted(OUT, fStats, ['Workspace Statistics', 'Total', 'Deadlines', 'By Column', 'To Do: 1', 'Doing: 1', 'Done: 0']);
  check('smart gen: Workspace Statistics counts this board\'s cards by column', ok && lab.includes('Close Statistics Panel'), d);
  check('smart gen: statistics total is 2 and deadlines 0', statLines.includes('2') && statLines.includes('0'), JSON.stringify(statLines));
  // Reload: same profile, everything above must come back from storage.
  await h.boot(page, '?app=smartgen');
  await tapL(h, page, 'Audit', 1500); await tapL(h, page, 'Main', 2500);
  const fRe = await shot(page, 'sg_after_reload');
  [ok, d] = painted(OUT, fRe, ['Audit note saved locally']);
  check('smart gen: after reload the renamed card is still on the board', ok, d);
  await tapL(h, page, 'Flip Card to Private Notes (3D)', 1200);
  [ok, d] = painted(OUT, await shot(page, 'sg_after_reload_flipped'), ['Private Notes & Hidden Fields', 'Catering confirmed for Friday']);
  check('smart gen: after reload the private note is still on the back', ok, d);
  await ctx.close();
}

/** Port 2 — SuperApp: import a real file, view its own text, attach it to the composer, send it. */
async function filesAttach(h) {
  const { page, ctx } = await h.newPage(h.browser);
  const { sleep, check, shot, OUT } = h;
  const name = 'import-proof.txt';
  const body = 'Collider import proof. The animal in this file is a narwhal.';
  const path = join(OUT, name);
  writeFileSync(path, body + '\n');
  await h.boot(page, '?app=files');
  const chooser = page.waitForEvent('filechooser', { timeout: 15000 }).catch(() => null);
  await tapL(h, page, 'Add files', 300);
  const fc = await chooser;
  if (fc) await fc.setFiles(path);
  await sleep(2500);
  let [ok, d] = painted(OUT, await shot(page, 'files_imported'), ['import-pro']);
  check('files: Upload imports a real local file', !!fc && ok && await has(h, page, name), d);
  // Reload with no accessibility layer: the tile is tapped with the pointer,
  // as a person would (the accessibility tap on a file tile does not open it).
  await h.boot(page, '?app=files', { semantics: false });
  const fList = await shot(page, 'files_after_reload');
  [ok, d] = painted(OUT, fList, ['import-pro']);
  check('files: after reload the imported file is still listed', ok, d);
  const at = ocrFind(join(OUT, fList), 'import-pro');
  if (at) await page.mouse.click(at[1] / (h.DSF || 1), at[2] / (h.DSF || 1) - 60);
  await sleep(1800);
  const fView = await shot(page, 'files_view_text');
  [ok, d] = painted(OUT, fView, [name, 'animal in this file is a narwhal']);
  check('files: the imported file opens with its own text (read from storage)', ok, d);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await sleep(1000);
  check('files: the viewer offers Attach to Message', await has(h, page, 'Attach to Message'), '');
  await tapL(h, page, 'Attach to Message', 1800);
  const fChip = await shot(page, 'composer_attachment_chip');
  [ok, d] = painted(OUT, fChip, [name]);
  check('files: Attach to Message returns to the composer with the file chip', ok && await has(h, page, name), d);
  // Send it: the file's text must reach the models.
  const sent = [];
  page.on('request', (q) => { if (/\/api\/p\?u=/.test(q.url()) && q.method() === 'POST') sent.push(q.postData() || ''); });
  await page.keyboard.type('Which animal does the attached file name? One word.', { delay: 10 });
  await sleep(400);
  await page.keyboard.press('Enter');
  const t0 = Date.now();
  while (Date.now() - t0 < 60000 && !sent.some((s) => s.includes('narwhal'))) await sleep(1000);
  check('files: sending carries the attached file\'s text to the models', sent.some((s) => s.includes('narwhal') && s.includes(name)), `${sent.length} provider request(s)`);
  await sleep(30000);
  [ok, d] = painted(OUT, await shot(page, 'composer_attachment_sent'), ['Narwhal']);
  check('files: the models answer from the attached file (consensus reads Narwhal)', ok, d);
  await ctx.close();
}

/** Port 3 — OCT24 checkpoint: browser sidebar (tabs, bookmarks, history). */
async function browserSidebar(h) {
  const { page, ctx } = await h.newPage(h.browser);
  const { sleep, check, shot, OUT } = h;
  await h.boot(page, '?browser=1');
  await h.waitFrame(page, (f) => f.bytes > 1000);
  for (const [typed, base] of [['wikipedia.org', /^https:\/\/www\.wikipedia\.org\//], ['github.com', /^https:\/\/github\.com\//]]) {
    await h.typeAddress(page, typed);
    await h.waitFrame(page, (f) => base.test(f.base));
    await sleep(2000);
  }
  await tapL(h, page, 'Sidebar', 1200);
  const fSide = await shot(page, 'browser_sidebar');
  let [ok, d] = painted(OUT, fSide, ['github.com', 'Bookmarks', 'History']);
  check('browser sidebar: opens with the tab, Bookmarks and History', ok, d);
  await tapL(h, page, 'Bookmarks', 1000);
  await tapL(h, page, 'github.com', 1000);
  const fBm = await shot(page, 'browser_bookmarked');
  [ok, d] = painted(OUT, fBm, ['Bookmarks', 'github.com']);
  check('browser sidebar: Bookmarks adds the page on screen', ok && (await h.labels(page)).filter((l) => l.label.includes('github.com')).length >= 2, d);
  await tapL(h, page, 'Bookmarks', 1000); // the back row
  await tapL(h, page, 'History', 1000);
  const fHist = await shot(page, 'browser_history');
  [ok, d] = painted(OUT, fHist, ['History', 'github.com', 'wikipedia.org']);
  check('browser sidebar: History lists the pages visited', ok, d);
  await tapL(h, page, 'wikipedia.org', 500);
  const fr = await h.waitFrame(page, (f) => /^https:\/\/www\.wikipedia\.org\//.test(f.base), 30000);
  await sleep(2000);
  await shot(page, 'browser_history_opened');
  check('browser sidebar: a History row opens that page through the proxy', fr.some((f) => /^https:\/\/www\.wikipedia\.org\//.test(f.base) && /Wikipedia/i.test(f.title)), JSON.stringify(fr.map((f) => f.base)));
  // Reload: bookmarks and history are kept.
  await h.boot(page, '?browser=1');
  await h.waitFrame(page, (f) => f.bytes > 1000);
  await tapL(h, page, 'Sidebar', 1200);
  await tapL(h, page, 'Bookmarks', 1000);
  [ok, d] = painted(OUT, await shot(page, 'browser_bookmarks_after_reload'), ['Bookmarks', 'github.com']);
  check('browser sidebar: after reload the bookmark is kept', ok, d);
  await tapL(h, page, 'Bookmarks', 1000);
  await tapL(h, page, 'History', 1000);
  [ok, d] = painted(OUT, await shot(page, 'browser_history_after_reload'), ['History', 'github.com', 'wikipedia.org']);
  check('browser sidebar: after reload the history is kept', ok, d);
  await ctx.close();
}
