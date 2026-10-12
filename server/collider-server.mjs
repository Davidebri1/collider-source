// Collider server.
//
// Serves the built Flutter web app (app/) and the API the app calls at its own
// origin. Without this, every /api/* request falls through to index.html, the
// client fails to parse it, ColliderApi.online stays false, and the composer
// refuses to send. That is why the app said "no server" while looking fine.
//
// Keys live here, never in the browser bundle. A provider with no key configured
// is simply absent from the roster, so the client never offers a model that
// cannot answer.
//
// Two things make this work on a machine with no keys at all:
//   1. Pollinations' OpenAI-compatible text endpoint needs no key, and is the
//      last attempt on every text route.
//   2. NVIDIA can be reached through the upstream Collider proxy, which holds
//      that key. COLLIDER_UPSTREAM_PROXY points at it.

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import { networkInterfaces } from 'node:os';

const HERE = fileURLToPath(new URL('.', import.meta.url));
const WEB_ROOT = process.env.COLLIDER_WEB_ROOT || join(HERE, '..', 'app');
const PORT = Number(process.env.PORT || 28700);
const UPSTREAM = (process.env.COLLIDER_UPSTREAM_PROXY || 'https://vproxy-sepia.vercel.app').replace(/\/+$/, '');

// Keys may live in the environment or in server/keys.local.json (gitignored).
// The file wins, because it is the one place a new machine needs to be told.
try {
  const raw = await readFile(join(HERE, 'keys.local.json'), 'utf8');
  for (const [k, v] of Object.entries(JSON.parse(raw))) if (v) process.env[k] = String(v);
} catch { /* no key file; environment only */ }

// ---------------------------------------------------------------- providers

const PROVIDERS = {
  nvidia: {
    base: 'https://integrate.api.nvidia.com/v1',
    keys: ['NVIDIA_KEY', 'NVIDIA_KEY2', 'NVIDIA_KEY3'],
    // Falls back to the upstream proxy, which holds the key for us.
    viaUpstream: 'nvidia',
  },
  opencode: {
    base: 'https://opencode.ai/zen/v1',
    keys: ['OPENCODE_KEY'],
    viaUpstream: 'opencode',
  },
  commandcode: { base: 'https://api.commandcode.ai/provider/v1', keys: ['COMMANDCODE_KEY'] },
  minimax: { base: 'https://api.minimax.io/v1', keys: ['MINIMAX_KEY'] },
  // CrazyRouter carries almost the whole roster under bare slugs, so it is the
  // broadest single key we can hold. It is tried last for any model that has a
  // better-matched provider, and first when nothing else is configured.
  crazyrouter: {
    base: 'https://crazyrouter.com/v1',
    keys: ['CRAZYROUTER_KEY'],
    // CrazyRouter wants `glm-5.3`, not `z-ai/glm-5.3`.
    slug: (remote) => remote.replace(/^[^/]+\//, ''),
  },
  openrouter: { base: 'https://openrouter.ai/api/v1', keys: ['OPENROUTER_KEY'] },
  // Keyless. Note the path: Pollinations publishes /openai, not /chat/completions.
  pollinations: { base: 'https://text.pollinations.ai', path: '/openai', keys: [] },
};

/** The roster the client knows about, and how to actually reach each model.
 *  Order is the order we try. Keyless Pollinations is appended at call time. */
const MODELS = [
  // free
  { id: 'free/glm-5-3-flash', label: 'GLM 5.3 Flash', provider: 'Z.ai', color: '#6EA8FF', tier: 'free',
    tries: [['nvidia', 'z-ai/glm-5.3-flash'], ['opencode', 'glm-5.3-flash']] },
  { id: 'free/laguna-s-2-1', label: 'Laguna S 2.1', provider: 'Poolside', color: '#4FD1C5', tier: 'free',
    tries: [['commandcode', 'poolside/laguna-s-2.1-free'], ['openrouter', 'poolside/laguna-s-2.1']] },
  { id: 'free/laguna-xs-2-1', label: 'Laguna XS 2.1', provider: 'Poolside', color: '#7DE3D8', tier: 'free',
    tries: [['nvidia', 'poolside/laguna-xs-2.1']] },
  { id: 'free/ling-3-1-flash', label: 'Ling 3.1 Flash', provider: 'inclusionAI', color: '#B794F4', tier: 'free',
    tries: [['commandcode', 'inclusionai/ling-3.1-flash:free'], ['openrouter', 'inclusionai/ling-3.1-flash']] },
  { id: 'free/nemotron-3-5-lightning', label: 'Nemotron 3.5 Lightning', provider: 'NVIDIA', color: '#76D672', tier: 'free',
    tries: [['nvidia', 'nvidia/nemotron-3.5-lightning-30b-a3b']] },
  { id: 'free/pollinations-openai', label: 'Pollinations OpenAI', provider: 'Pollinations', color: '#8EE878', tier: 'free',
    tries: [['pollinations', 'openai']] },
  // pro
  { id: 'pro/glm-5-3', label: 'GLM 5.3', provider: 'Z.ai', color: '#3D7BFF', tier: 'pro',
    tries: [['nvidia', 'z-ai/glm-5.3'], ['opencode', 'glm-5.3'], ['commandcode', 'zai-org/GLM-5.3']] },
  { id: 'pro/deepseek-4-1-flash', label: 'DeepSeek V4.1 Flash', provider: 'DeepSeek', color: '#5B8CFF', tier: 'pro',
    tries: [['nvidia', 'deepseek-ai/deepseek-v4.1-flash'], ['opencode', 'deepseek-v4.1-flash']] },
  { id: 'pro/minimax-m3', label: 'minimax M3', provider: 'minimax', color: '#FF9E6B', tier: 'pro',
    tries: [['minimax', 'minimax-M3'], ['commandcode', 'minimaxAI/minimax-M3'], ['opencode', 'minimax-m3']] },
  { id: 'pro/mimo-v2-6-flash', label: 'MiMo V2.6 Flash', provider: 'Xiaomi', color: '#FF7A45', tier: 'pro',
    tries: [['commandcode', 'xiaomi/mimo-v2.6-flash']] },
  { id: 'pro/nemotron-3-ultra', label: 'Nemotron 3 Ultra', provider: 'NVIDIA', color: '#9BE15D', tier: 'pro',
    tries: [['nvidia', 'nvidia/nemotron-3-ultra-550b-a55b']] },
  // elite
  { id: 'elite/kimi-k3', label: 'Kimi K3', provider: 'Moonshot AI', color: '#4BE6B1', tier: 'elite',
    tries: [['nvidia', 'moonshotai/kimi-k3'], ['opencode', 'kimi-k3']] },
];

// coding-category ids mirror their general counterpart on the client side
const CODE_ALIAS = {
  'code-free/glm-5-3-flash': 'free/glm-5-3-flash',
  'code-free/laguna-s-2-1': 'free/laguna-s-2-1',
  'code-free/laguna-xs-2-1': 'free/laguna-xs-2-1',
  'code-free/ling-3-1-flash': 'free/ling-3-1-flash',
  'code-free/nemotron-3-5-lightning': 'free/nemotron-3-5-lightning',
  'code-pro/glm-5-3': 'pro/glm-5-3',
  'code-pro/deepseek-4-1-flash': 'pro/deepseek-4-1-flash',
  'code-pro/minimax-m3': 'pro/minimax-m3',
  'code-pro/mimo-v2-6-flash': 'pro/mimo-v2-6-flash',
  'code-pro/nemotron-3-ultra': 'pro/nemotron-3-ultra',
  'code-elite/kimi-k3': 'elite/kimi-k3',
};

const keyCount = (p) => PROVIDERS[p].keys.filter((n) => process.env[n]).length;

/** A provider is reachable if it has a key here, or the upstream proxy can
 *  stand in for it, or it is keyless. */
function providerUsable(p) {
  const def = PROVIDERS[p];
  if (def.keys.length === 0) return true;          // keyless by design
  if (keyCount(p) > 0) return true;                // we hold a key
  return Boolean(def.viaUpstream && UPSTREAM);      // the upstream proxy stands in
}

const liveRoster = () => MODELS.filter((m) => m.tries.some(([p]) => providerUsable(p)));

// ------------------------------------------------------------------ calls

const stripThink = (t) =>
  String(t || '').replaceAll(/<think>[\s\S]*?<\/think>/g, '').replace(/^[\s\S]*?<\/think>/g, '').trim();

/** One OpenAI-compatible chat call. Providers differ in three ways only: the
 *  path they expose, whether they want a bearer token, and what they do with
 *  the model id. Everything else is identical, so it lives in one place. */
async function postChat(url, body, headers) {
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body,
    signal: AbortSignal.timeout(90_000),
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`${r.status}: ${text.slice(0, 200)}`);
  const out = stripThink(JSON.parse(text)?.choices?.[0]?.message?.content);
  if (!out) throw new Error('empty answer');
  return out;
}

async function callProvider(provider, remote, messages, { maxTokens } = {}) {
  const def = PROVIDERS[provider];
  const wireRemote = def.slug ? def.slug(remote) : remote;
  const body = JSON.stringify({
    model: wireRemote,
    messages,
    ...(maxTokens ? { max_tokens: maxTokens } : {}),
  });
  const path = def.path || '/chat/completions';

  // Keyless by design: go straight out, with no token at all.
  if (def.keys.length === 0) return postChat(def.base + path, body, {});

  // Try each configured key. Auth and quota failures mean "try the next one";
  // anything else is a real answer from the provider and we stop there.
  let hard = null;
  for (const name of def.keys) {
    const key = process.env[name];
    if (!key) continue;
    try {
      return await postChat(def.base + path, body, { Authorization: `Bearer ${key}` });
    } catch (e) {
      if (/^(401|403|429):/.test(e.message)) continue;
      hard = e;
      break;
    }
  }
  if (hard) throw new Error(`provider ${hard.message}`);

  // No usable key here: ask the upstream Collider proxy, which holds one.
  if (def.viaUpstream && UPSTREAM) {
    const r = await fetch(`${UPSTREAM}/api/p?u=${def.viaUpstream}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: 'https://davidebri1.github.io' },
      body,
      signal: AbortSignal.timeout(90_000),
    });
    const text = await r.text();
    if (!r.ok) throw new Error(`upstream ${r.status}: ${text.slice(0, 200)}`);
    const out = stripThink(JSON.parse(text)?.choices?.[0]?.message?.content);
    if (!out) throw new Error('empty answer');
    return out;
  }

  throw new Error('no-key');
}

/** Walks a model's attempts, then CrazyRouter (which covers almost the whole
 *  roster), then keyless Pollinations. A request degrades to a weaker answer
 *  rather than to nothing. */
async function callModel(modelId, messages, opts = {}) {
  const base = CODE_ALIAS[modelId] || modelId;
  const m = MODELS.find((x) => x.id === base);
  const tries = m ? m.tries : [['pollinations', 'openai']];
  let firstErr;
  for (const [p, remote] of tries) {
    if (!providerUsable(p)) { firstErr ??= new Error('no-key'); continue; }
    try {
      return { text: await callProvider(p, remote, messages, opts), via: `${p}/${remote}` };
    } catch (e) { firstErr ??= e; }
  }
  // CrazyRouter as the broad backstop, whichever model we were after.
  if (m && providerUsable('crazyrouter')) {
    for (const [, remote] of m.tries) {
      try {
        return { text: await callProvider('crazyrouter', remote, messages, opts), via: `crazyrouter/${remote}` };
      } catch (e) { firstErr ??= e; }
    }
  }
  try {
    return { text: await callProvider('pollinations', 'openai', messages, opts), via: 'pollinations/openai (fallback)' };
  } catch (e) { firstErr ??= e; }
  throw firstErr ?? new Error('no-key');
}

// -------------------------------------------------------------- consensus

// Contract authority: docs/Consensus Agent.md (Consensus Agent) and
// docs/PRD-XLSX-EXTRACT.txt row R17/R41.
//
// Three fields only, exactly as the agent spec's Recap section names them:
//   Consensus Ratio      - a COUNT of responses sharing a sentiment over total
//                          responses. Never a percent. R17: "The score is a
//                          count, never a percent."
//   Consensus Summary     - the winning sentiment reproduced VERBATIM from a
//                          member response. Not composed, not paraphrased.
//   Logical Chain Table  - per response: chain count and max chain length,
//                          plus grouping, plus a row for the consensus summary
//                          carrying the max chain length of its members.
//
// There is no DISSENT and no NEED. Those were invented. Accuracy, confidence,
// and judgement are explicitly out of scope: "you are only recording reality,
// not advising."
const CONSENSUS_SYSTEM =
  'You are the Collider consensus recorder. Several models each independently answered one message. ' +
  'You record what is there. You do not advise, rank, or evaluate correctness.\n\n' +
  'Work in this order.\n' +
  '1. From the user message, derive the need and the intent of the message.\n' +
  '2. For each response, simplify it to its base minimal distinction or sentiment: the actionable portion that serves the derived need.\n' +
  '3. Group the responses by that sentiment. Resolve democratically: the sentiment with the most members is the consensus.\n' +
  '4. Count the logical chain depth of each response. A logical chain is a sequential clarification or simplification that extends logic and serves the need. An explicit chain reads until the next clause is not logically dependent on the previous. Implicit chains count too: a definition, statement, or narrative element that directly supports a logical conclusion, whether evidentiary after the point or preemptive before it. A technical definition standing alone never extends beyond 1 no matter how many appear; it must attach to a larger logical point to extend. An apparent split is clarification and counts as the same chain. There is one prompt, one chain; anything outside that is ad libbing and does not count. Do not count words or characters, and do not use keyword or regex counting. Count meaning.\n' +
  '5. Report the maximum chain length for each response. Max length separates relevant and novel clarification from repetition.\n\n' +
  'Answer with exactly these lines and nothing else. Do not add commentary.\n' +
  'RATIO: <count of responses in the winning group>/<total responses>\n' +
  'SUMMARY: <the winning sentiment copied verbatim from a member response>\n' +
  'Then one GROUP line per sentiment group, in order of size, largest first:\n' +
  'GROUP: <sentiment> = <model name>, <model name>\n' +
  'Then one CHAIN line per response:\n' +
  'CHAIN: <model name> = <chain count> chains, max <max length>\n' +
  'Then one final line:\n' +
  'CONSENSUS_CHAIN: <chain count> chains, max <the largest max length among its members>';

/** Pull one labelled field out of the recorder's reply. */
const field = (text, label) => {
  const re = new RegExp(`^\\s*${label}:\\s*([\\s\\S]*?)(?=\\n\\s*[A-Z_]+:|$)`, 'im');
  return (text.match(re) || [, ''])[1].trim();
};

/**
 * Every line carrying a given label, in order. A group table or chain table
 * with more than one entry arrives as repeated lines, not one long line, so a
 * single-regex field() would silently drop every entry after the first.
 */
const fieldLines = (text, label) =>
  text
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => new RegExp(`^${label}:`, 'i').test(l))
    .map((l) => l.replace(new RegExp(`^${label}:\\s*`, 'i'), '').trim())
    .filter(Boolean);

/**
 * R16: "Incomplete shows an empty score." An unfinished shared send must render
 * an empty score, never a placeholder, a percent, or a "waiting" line.
 */
function consensusScore(ratio, total) {
  const n = Number(String(ratio).split('/')[0]);
  if (!Number.isFinite(n) || n <= 0 || !Number.isFinite(total)) return '';
  return `${n}/${total}`;
}

async function synthesise(prompt, answers, { excluded = [] } = {}) {
  // R41 isolation rule: only models still on the shared query are counted.
  // Excluded ones are reported as excluded, never dropped quietly.
  const excludedSet = new Set(excluded);
  const counted = answers.filter((a) => !excludedSet.has(a.model));
  const base = {
    status: 'done',
    ratio: '',
    score: '',
    summary: '',
    groups: [],
    chains: [],
    consensus_chain: '',
    excluded: answers.filter((a) => excludedSet.has(a.model)).map((a) => a.model),
  };
  if (counted.length === 0) return { ...base, status: 'empty' };
  // One response cannot disagree with itself. That is a real consensus.
  if (counted.length === 1) {
    return {
      ...base,
      ratio: `1/1`,
      score: consensusScore('1/1', 1),
      summary: essence(counted[0].text),
      groups: [{ sentiment: essence(counted[0].text), models: [counted[0].model] }],
    };
  }

  const body = counted.map((a) => `MODEL ${a.model}\n${a.text}`).join('\n\n');
  try {
    const { text } = await callModel('free/glm-5-3-flash', [
      { role: 'system', content: CONSENSUS_SYSTEM },
      {
        role: 'user',
        content:
          `MESSAGE\n${prompt}\n\n` +
          `RESPONSES (${counted.length})\n${body}\n\n` +
          `Models ${excludedSet.size ? `excluded from this shared query: ${[...excludedSet].join(', ')}` : ''}`,
      },
    ]);

    const ratio = field(text, 'RATIO');
    // One GROUP line per group, largest first. Split on the LAST "=" so a
    // sentiment containing "=" survives.
    const groups = fieldLines(text, 'GROUP')
      .map((line) => {
        const at = line.lastIndexOf('=');
        if (at < 1) return null;
        const sentiment = line.slice(0, at).trim();
        const models = line
          .slice(at + 1)
          .split(',')
          .map((m) => m.trim())
          .filter(Boolean);
        if (!sentiment || !models.length) return null;
        return { sentiment, models };
      })
      .filter(Boolean);

    // One CHAIN line per response.
    const chains = fieldLines(text, 'CHAIN')
      .map((line) => {
        const at = line.lastIndexOf('=');
        if (at < 1) return null;
        const model = line.slice(0, at).trim();
        const rest = line.slice(at + 1);
        const count = Number((rest.match(/(\d+)\s+chains?/i) || [])[1]);
        const max = Number((rest.match(/max\s+(\d+)/i) || [])[1]);
        if (!model || !Number.isFinite(count) || !Number.isFinite(max)) return null;
        return { model, chains: count, max };
      })
      .filter(Boolean);

    const total = counted.length;
    const winner = groups[0] || null;
    const winnerCount = winner ? winner.models.length : total;
    // Verbatim: take the summary from a member, never a composed line.
    const summary = winner
      ? essence(counted.find((a) => winner.models.includes(a.model))?.text) || field(text, 'SUMMARY')
      : field(text, 'SUMMARY');

    return {
      ...base,
      ratio: ratio || `${winnerCount}/${total}`,
      score: consensusScore(ratio || winnerCount, total),
      summary,
      groups,
      chains,
      consensus_chain: field(text, 'CONSENSUS_CHAIN'),
    };
  } catch (e) {
    // No recorder available. Report nothing rather than inventing a ratio.
    return {
      ...base,
      status: 'unavailable',
      error: String(e?.message || e),
    };
  }
}

const essence = (t) => String(t || '').replace(/\s+/g, ' ').trim().slice(0, 180);

// ------------------------------------------------------------------ state

/** In-memory jobs and history. Restarting the server forgets both, which is
 *  the right trade for a single-user local app and avoids a database. */
const jobs = new Map();
const history = [];

function prune() {
  const cut = Date.now() - 6 * 3600_000;
  for (const [id, j] of jobs) if (j.created * 1000 < cut) jobs.delete(id);
  while (history.length > 50) history.shift();
}

// -------------------------------------------------------------------- http

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.mjs': 'application/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.css': 'text/css',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp',
  '.gif': 'image/gif', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff': 'font/woff', '.woff2': 'font/woff2',
  '.mp4': 'video/mp4', '.webm': 'video/webm', '.mp3': 'audio/mpeg', '.wav': 'audio/wav',
  '.frag': 'text/plain', '.symbols': 'text/plain', '.map': 'application/json',
};

const json = (res, code, body) => {
  const b = JSON.stringify(body);
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(b), 'Cache-Control': 'no-store' });
  res.end(b);
};

const readBody = (req) =>
  new Promise((resolve, reject) => {
    const c = [];
    req.on('data', (d) => { c.push(d); if (c.length > 4e6) reject(new Error('body too large')); });
    req.on('end', () => {
      const raw = Buffer.concat(c).toString('utf8');
      if (!raw) return resolve({});
      try { resolve(JSON.parse(raw)); } catch { reject(new Error('bad json')); }
    });
    req.on('error', reject);
  });

async function serveStatic(req, res, pathname) {
  // normalize + containment: never escape WEB_ROOT
  const rel = normalize(decodeURIComponent(pathname)).replace(/^([/\\])+/, '');
  let file = join(WEB_ROOT, rel);
  if (!file.startsWith(WEB_ROOT)) return json(res, 403, { error: 'forbidden' });

  try {
    const s = await stat(file);
    if (s.isDirectory()) file = join(file, 'index.html');
  } catch {
    file = join(WEB_ROOT, 'index.html'); // SPA fallback
  }

  try {
    const buf = await readFile(file);
    const type = MIME[extname(file).toLowerCase()] || 'application/octet-stream';
    // Only fingerprinted, content-addressed files may be cached hard. The
    // entry bundle and the service worker are not fingerprinted, so caching
    // them pins the browser to a stale build until it expires.
    const rel = file.replace(/\\/g, '/');
    const fingerprinted = /\/assets\/(assets|fonts|shaders)\//.test(rel) || /\/canvaskit\//.test(rel);
    res.writeHead(200, {
      'Content-Type': type,
      'Content-Length': buf.length,
      'Cache-Control': fingerprinted ? 'public, max-age=86400' : 'no-store',
      // the app talks to itself, so it needs no cross-origin anything
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(buf);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('not found');
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const p = url.pathname;

  try {
    if (p === '/api/health') {
      return json(res, 200, {
        ok: true,
        webRoot: WEB_ROOT,
        upstream: UPSTREAM,
        models: liveRoster().length,
        keys: Object.fromEntries(Object.keys(PROVIDERS).map((k) => [k, keyCount(k)])),
      });
    }

    if (p === '/api/models') {
      return json(res, 200, {
        models: liveRoster().map((m) => ({
          id: m.id, label: m.label, provider: m.provider, color: m.color,
        })),
        search: true,
        keys: liveRoster().length,
      });
    }

    // What is actually configured, and what it buys. Never echoes a key value.
    if (p === '/api/keys') {
      return json(res, 200, {
        upstream: UPSTREAM,
        providers: Object.entries(PROVIDERS).map(([name, def]) => ({
          name,
          base: def.base,
          held: def.keys.filter((n) => process.env[n]).length,
          expects: def.keys,
          usable: providerUsable(name),
        })),
        models: MODELS.map((m) => ({
          id: m.id, label: m.label, tier: m.tier,
          routable: m.tries.some(([pr]) => providerUsable(pr)) || providerUsable('crazyrouter'),
        })),
      });
    }

    if (p === '/api/ask' && req.method === 'POST') {
      const { prompt = '', models = [], mode = 'chat', autosave = true, incognito = false, excluded = [] } = await readBody(req);
      if (!prompt.trim()) return json(res, 400, { error: 'empty prompt' });

      // R41: a direct reply to a subset takes those models out of consensus.
      // Those models are still selected and still answer — they are shown as
      // excluded, not dropped. So `excluded` is a subset of `models`; anything
      // outside the send cannot be excluded from it and is ignored.
      const excludedSet = new Set(
        (Array.isArray(excluded) ? excluded : [])
          .filter((m) => typeof m === 'string')
          .filter((m) => models.includes(m)),
      );

      const id = randomUUID();
      const job = {
        id, prompt, mode, stage: 'running', created: Date.now() / 1000,
        results: Object.fromEntries(models.map((m) => [m, { status: 'pending', text: '', essence: '' }])),
        consensus: { status: 'pending', ratio: '', score: '', summary: '', groups: [], chains: [], consensus_chain: '', excluded: [...excludedSet] },
        sources: [],
      };
      jobs.set(id, job);
      prune();

      const system = mode === 'code' || mode === 'coding'
        ? 'You are a precise software engineer. Answer with working code.'
        : 'You are Collider, a concise, direct assistant.';

      // Fan out. Each model is independent; failures are recorded per model so
      // one dead provider never sinks the whole answer.
      Promise.all(models.map(async (mid) => {
        try {
          const { text } = await callModel(mid, [
            { role: 'system', content: system },
            { role: 'user', content: prompt },
          ]);
          job.results[mid] = { status: 'done', text, essence: essence(text) };
        } catch (e) {
          job.results[mid] = { status: 'error', text: '', essence: '', error: String(e?.message || e) };
        }
      })).then(async () => {
        job.stage = 'consensus';
        const done = models
          .map((m) => ({ model: m, text: job.results[m]?.text || '' }))
          .filter((a) => a.text);
        if (done.length) job.consensus = await synthesise(prompt, done, { excluded: [...excludedSet] });
        job.stage = 'done';
        if (autosave && !incognito) {
          history.unshift({ id, prompt, mode, created: job.created, models, status: 'done' });
        }
      }).catch((e) => { job.stage = 'done'; job.consensus.error = String(e?.message || e); });

      return json(res, 200, { id });
    }

    if (p.startsWith('/api/job/')) {
      const job = jobs.get(p.slice('/api/job/'.length));
      if (!job) return json(res, 404, { error: 'no such job' });
      return json(res, 200, { ...job, status: job.stage === 'done' ? 'done' : 'pending' });
    }

    if (p === '/api/reply' && req.method === 'POST') {
      const { model, messages = [], mode = 'chat' } = await readBody(req);
      if (!model) return json(res, 400, { error: 'no model' });
      const { text } = await callModel(model, messages);
      return json(res, 200, { text, essence: essence(text) });
    }

    if (p === '/api/history') return json(res, 200, { sessions: history });

    // Server-side page fetch so the in-app browser is not blocked by CORS.
    if (p === '/api/page') {
      const target = url.searchParams.get('url') || '';
      if (!/^https?:\/\//i.test(target)) return json(res, 400, { error: 'bad url' });
      const r = await fetch(target, { headers: { 'User-Agent': 'Mozilla/5.0 Collider' }, signal: AbortSignal.timeout(30_000) });
      const type = r.headers.get('content-type') || '';
      if (!type.includes('html')) return json(res, 415, { error: 'not html' });
      const html = await r.text();
      return json(res, 200, { html });
    }

    if (p.startsWith('/api/')) return json(res, 404, { error: 'no such endpoint' });

    return await serveStatic(req, res, p);
  } catch (e) {
    return json(res, 500, { error: String(e?.message || e) });
  }
});

// Bind to every interface, not just loopback: the app has to be reachable from
// a phone on the same network, which is the only way to judge it as a user.
server.listen(PORT, '0.0.0.0', () => {
  const live = liveRoster();
  const nets = networkInterfaces();
  const lan = Object.values(nets).flat().find((n) => n && n.family === 'IPv4' && !n.internal);
  const held = Object.entries(Object.fromEntries(Object.keys(PROVIDERS).map((k) => [k, keyCount(k)]))).filter(([, v]) => v);
  console.log(`Collider server on http://localhost:${PORT}`);
  if (lan) console.log(`  on your network   http://${lan.address}:${PORT}   <- open this on the phone`);
  console.log(`  web root  ${WEB_ROOT}`);
  console.log(`  upstream  ${UPSTREAM}`);
  console.log(`  models    ${live.length}/${MODELS.length} routable`);
  console.log(`  keys      ${held.map(([k, v]) => `${k}x${v}`).join(' ') || 'none held here'}`);
});