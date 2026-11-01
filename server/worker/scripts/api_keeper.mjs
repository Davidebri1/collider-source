/** Local account API keeper for captures/tests. Port 9103. DEV_AUTH always on. */
import http from 'node:http';
const PORT = Number(process.env.PORT || 9103);
const users = new Map();
const byEmail = new Map();
const records = new Map();
const blobs = new Map();

function ensure(uid) {
  if (!records.has(uid)) records.set(uid, new Map());
  if (!blobs.has(uid)) blobs.set(uid, new Map());
}

async function body(req) {
  const c = [];
  for await (const x of req) c.push(x);
  return Buffer.concat(c);
}

const srv = http.createServer(async (req, res) => {
  const origin = req.headers.origin || '*';
  const cors = {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Updated-At',
    'Access-Control-Allow-Methods': 'GET,PUT,POST,DELETE,OPTIONS',
    Vary: 'Origin',
  };
  if (req.method === 'OPTIONS') { res.writeHead(204, cors); return res.end(); }
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const path = url.pathname;
  const json = (s, b) => { res.writeHead(s, { 'Content-Type': 'application/json', ...cors }); res.end(JSON.stringify(b)); };
  const auth = () => {
    const h = req.headers.authorization || '';
    const m = /^Bearer\s+(.+)$/i.exec(h);
    return m ? users.get(m[1]) : null;
  };

  if (path === '/health') return json(200, { ok: true, service: 'collider-keeper' });
  if (path === '/auth/dev' && req.method === 'POST') {
    const j = JSON.parse((await body(req)).toString() || '{}');
    const email = (j.email || 'user@collider.app').toLowerCase();
    let userId = byEmail.get(email);
    if (!userId) { userId = `u_${email}`; byEmail.set(email, userId); }
    ensure(userId);
    const token = `tok_${email}_${Math.random().toString(36).slice(2)}`;
    const u = {
      userId, email, displayName: j.name || email, provider: 'dev',
      accessToken: token, expiresAt: new Date(Date.now() + 864e5).toISOString(),
    };
    users.set(token, u);
    return json(200, u);
  }
  if (path === '/auth/me') {
    const u = auth();
    return u ? json(200, u) : json(401, { error: 'unauthorized' });
  }
  if (path === '/auth/signout' && req.method === 'POST') {
    const h = req.headers.authorization || '';
    const m = /^Bearer\s+(.+)$/i.exec(h);
    if (m) users.delete(m[1]);
    res.writeHead(204, cors); return res.end();
  }
  if (path === '/v1/records' && req.method === 'GET') {
    const u = auth(); if (!u) return json(401, { error: 'unauthorized' });
    const since = Number(url.searchParams.get('since') || 0);
    return json(200, { items: [...records.get(u.userId).values()].filter((r) => r.updatedAtMs > since) });
  }
  const rm = /^\/v1\/records\/([^/]+)\/([^/]+)$/.exec(path);
  if (rm) {
    const u = auth(); if (!u) return json(401, { error: 'unauthorized' });
    const collection = decodeURIComponent(rm[1]);
    const id = decodeURIComponent(rm[2]);
    const key = `${collection}:${id}`;
    const map = records.get(u.userId);
    if (req.method === 'PUT') {
      const j = JSON.parse((await body(req)).toString() || '{}');
      const updatedAtMs = Number(j.updatedAtMs) || Date.now();
      const cur = map.get(key);
      if (cur && cur.updatedAtMs > updatedAtMs) return json(200, { ok: true, skipped: true });
      map.set(key, { collection, id, data: j.data || {}, updatedAtMs, deleted: !!j.deleted });
      return json(200, { ok: true });
    }
    if (req.method === 'DELETE') {
      map.set(key, { collection, id, data: {}, updatedAtMs: Date.now(), deleted: true });
      res.writeHead(204, cors); return res.end();
    }
  }
  if (path === '/v1/blobs' && req.method === 'GET') {
    const u = auth(); if (!u) return json(401, { error: 'unauthorized' });
    const since = Number(url.searchParams.get('since') || 0);
    const items = [...blobs.get(u.userId).entries()].filter(([, v]) => v.updatedAtMs > since)
      .map(([id, v]) => ({ id, updatedAtMs: v.updatedAtMs, deleted: !!v.deleted, sizeBytes: v.bytes?.length || 0 }));
    return json(200, { items });
  }
  const bm = /^\/v1\/blobs\/(.+)$/.exec(path);
  if (bm) {
    const u = auth(); if (!u) return json(401, { error: 'unauthorized' });
    const id = decodeURIComponent(bm[1]);
    const map = blobs.get(u.userId);
    if (req.method === 'PUT') {
      const buf = await body(req);
      const updatedAtMs = Number(req.headers['x-updated-at'] || Date.now());
      const cur = map.get(id);
      if (cur && cur.updatedAtMs > updatedAtMs) return json(200, { ok: true, skipped: true });
      map.set(id, { bytes: buf, updatedAtMs, deleted: false });
      return json(200, { ok: true });
    }
    if (req.method === 'GET') {
      const v = map.get(id);
      if (!v || v.deleted) return json(404, { error: 'not found' });
      res.writeHead(200, { 'Content-Type': 'application/octet-stream', ...cors });
      return res.end(v.bytes);
    }
    if (req.method === 'DELETE') {
      map.set(id, { bytes: null, updatedAtMs: Date.now(), deleted: true });
      res.writeHead(204, cors); return res.end();
    }
  }
  json(404, { error: 'not found' });
});

srv.listen(PORT, '127.0.0.1', () => console.log(`keeper on ${PORT}`));
