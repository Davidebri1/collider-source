// Collider proxy: forwards OpenAI-compatible calls to NVIDIA / OpenCode with server-held keys.
const UP = {
  nvidia: ['https://integrate.api.nvidia.com/v1', ['NVIDIA_KEY', 'NVIDIA_KEY2', 'NVIDIA_KEY3']],
  opencode: ['https://opencode.ai/zen/v1', ['OPENCODE_KEY']],
};
const OK = /^https:\/\/davidebri1\.github\.io$|^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
module.exports = async (req, res) => {
  const o = req.headers.origin || '';
  if (OK.test(o)) { res.setHeader('Access-Control-Allow-Origin', o); res.setHeader('Vary', 'Origin'); }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'content-type, authorization');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (o && !OK.test(o)) return res.status(403).json({ error: { message: 'origin not allowed' } });
  const u = UP[req.query.u];
  if (!u || req.method !== 'POST') return res.status(400).json({ error: { message: 'bad route' } });
  const body = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || {});
  let last;
  for (const k of u[1].map(n => process.env[n]).filter(Boolean)) {
    const r = await fetch(u[0] + '/chat/completions', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + k }, body });
    last = { s: r.status, t: await r.text() };
    if (r.status !== 401 && r.status !== 403 && r.status !== 429) break;
  }
  if (!last) return res.status(500).json({ error: { message: 'no key configured' } });
  res.status(last.s).setHeader('Content-Type', 'application/json');
  res.send(last.t);
};
