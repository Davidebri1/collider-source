/**
 * Collider AccountSync Worker: collider.ebridavid.workers.dev
 *
 * Exactly the API lib/core/account_sync/account_sync_client.dart calls:
 *   GET    /health                          -> 200 {ok:true}
 *   POST   /auth/google  {id_token}         -> session (Google ID token, verified via JWKS)
 *   POST   /auth/apple   {id_token}         -> session (optional)
 *   POST   /auth/dev     {email, name?}     -> session (only when DEV_AUTH = "1")
 *   POST   /auth/signout                    -> 204
 *   GET    /auth/me                         -> session
 *   GET    /v1/records?since=ms             -> {items:[{collection,id,data,updatedAtMs,deleted}]}
 *   PUT    /v1/records/:collection/:id      -> 200 (last writer wins on updatedAtMs)
 *   DELETE /v1/records/:collection/:id?updatedAtMs=ms -> 204
 *   GET    /v1/blobs?since=ms               -> {items:[{id,updatedAtMs,deleted,sizeBytes}]}
 *   PUT    /v1/blobs/:id   (bytes, X-Updated-At) -> 200
 *   GET    /v1/blobs/:id                    -> bytes
 *   DELETE /v1/blobs/:id                    -> 204
 * session = {userId,email,displayName,provider,accessToken,expiresAt}
 *
 * Storage: D1 (binding DB: users, sessions, records, blob_meta) and KV
 * (binding BLOBS: blob bytes, 25 MiB each). Both are on the Workers Free
 * plan; no R2 (which needs a payment method). One file, so it can be pasted
 * into the dashboard editor. CORS: only https://davidebri1.github.io.
 */

const MAX_BLOB_BYTES = 25 * 1024 * 1024;

const GH_PAGES_ORIGIN = 'https://davidebri1.github.io';
const ALLOWED_ORIGINS = new Set([GH_PAGES_ORIGIN]);

function corsHeaders(request) {
  const origin = request.headers.get('Origin') || '';
  const h = {
    'Access-Control-Allow-Methods': 'GET, PUT, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Updated-At',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
  // Same-origin browser calls send Origin = this Worker's host — allow it.
  // Cross-origin: only the permanent GitHub Pages host.
  if (origin && (ALLOWED_ORIGINS.has(origin) || isSelfOrigin(request, origin))) {
    h['Access-Control-Allow-Origin'] = origin;
    h['Access-Control-Allow-Credentials'] = 'true';
  }
  return h;
}

function isSelfOrigin(request, origin) {
  try {
    return new URL(request.url).origin === origin;
  } catch {
    return false;
  }
}

function json(request, status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(request) },
  });
}

function empty(request, status) {
  return new Response(null, { status, headers: corsHeaders(request) });
}

function b64url(buf) {
  const bytes = buf instanceof ArrayBuffer ? new Uint8Array(buf) : buf;
  let s = '';
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlToBytes(s) {
  const pad = '='.repeat((4 - (s.length % 4)) % 4);
  const b64 = (s + pad).replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

const SESSION_DAYS = 30;

/** A random bearer token, stored in D1 with its expiry. */
async function mintSessionToken(env, userId) {
  const exp = Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000;
  const token = b64url(crypto.getRandomValues(new Uint8Array(32)));
  await env.DB.prepare('INSERT INTO sessions (token, user_id, expires_at_ms) VALUES (?, ?, ?)')
    .bind(token, userId, exp)
    .run();
  return { token, exp };
}

async function userFromAuth(request, env) {
  const h = request.headers.get('Authorization') || '';
  const m = /^Bearer\s+(.+)$/i.exec(h);
  if (!m) return null;
  const token = m[1].trim();
  const row = await env.DB.prepare('SELECT user_id, expires_at_ms FROM sessions WHERE token = ?').bind(token).first();
  if (!row || row.expires_at_ms < Date.now()) return null;
  return { userId: row.user_id, token, exp: row.expires_at_ms };
}

const PROD_HOSTS = new Set(['collider.ebridavid.workers.dev']);

/** Claims checks before the signature. Exported for the local audit test. */
export function googleClaimsOk(payload, clientId, nowMs = Date.now()) {
  if (!payload || typeof payload !== 'object') return false;
  const aud = payload.aud;
  const audOk = aud === clientId || (Array.isArray(aud) && aud.includes(clientId));
  if (!clientId || !audOk) return false;
  if (payload.iss !== 'https://accounts.google.com' && payload.iss !== 'accounts.google.com') return false;
  if (!payload.sub) return false;
  if ((payload.exp || 0) * 1000 <= nowMs) return false;
  if (payload.nbf && payload.nbf * 1000 > nowMs + 60_000) return false;
  return true;
}

/** Dev sign-in cannot run on the public host, even if DEV_AUTH was set. */
export function devAuthAllowed(request, env) {
  if (env.DEV_AUTH !== '1') return false;
  let host = '';
  try {
    host = new URL(request.url).hostname;
  } catch {
    return false;
  }
  if (PROD_HOSTS.has(host)) return false;
  return true;
}

/** Verify Google ID token (OIDC) — standard JWKS pattern. */
async function verifyGoogleIdToken(idToken, clientId) {
  const parts = idToken.split('.');
  if (parts.length !== 3) return null;
  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[0])));
  if (header.alg !== 'RS256') return null;
  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[1])));
  if (!googleClaimsOk(payload, clientId)) return null;
  const jwks = await (await fetch('https://www.googleapis.com/oauth2/v3/certs')).json();
  const jwk = (jwks.keys || []).find((k) => k.kid === header.kid);
  if (!jwk) return null;
  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const ok = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    b64urlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) return null;
  return {
    sub: payload.sub,
    email: payload.email || '',
    name: payload.name || payload.email || '',
  };
}

/** Verify Apple identity token (OIDC JWKS). */
async function verifyAppleIdToken(idToken, clientId) {
  const parts = idToken.split('.');
  if (parts.length !== 3) return null;
  const header = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[0])));
  if (header.alg !== 'RS256') return null;
  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(parts[1])));
  if (!clientId || payload.aud !== clientId) return null;
  if (payload.iss !== 'https://appleid.apple.com') return null;
  if (!payload.sub) return null;
  if ((payload.exp || 0) * 1000 < Date.now()) return null;
  const jwks = await (await fetch('https://appleid.apple.com/auth/keys')).json();
  const jwk = (jwks.keys || []).find((k) => k.kid === header.kid);
  if (!jwk) return null;
  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const ok = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    b64urlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) return null;
  return {
    sub: payload.sub,
    email: payload.email || '',
    name: payload.email || 'Apple',
  };
}

async function upsertUser(env, { provider, sub, email, name }) {
  const existing = await env.DB.prepare(
    'SELECT id, email, display_name, provider FROM users WHERE provider = ? AND provider_sub = ?',
  )
    .bind(provider, sub)
    .first();
  if (existing) {
    return {
      id: existing.id,
      email: existing.email,
      displayName: existing.display_name,
      provider: existing.provider,
    };
  }
  const id = crypto.randomUUID();
  await env.DB.prepare(
    'INSERT INTO users (id, email, display_name, provider, provider_sub, created_at_ms) VALUES (?, ?, ?, ?, ?, ?)',
  )
    .bind(id, email || '', name || '', provider, sub, Date.now())
    .run();
  return { id, email: email || '', displayName: name || '', provider };
}

function sessionBody(user, token, exp) {
  return {
    userId: user.id,
    email: user.email,
    displayName: user.displayName,
    provider: user.provider,
    accessToken: token,
    expiresAt: new Date(exp).toISOString(),
  };
}

async function handleAuth(request, env, path) {
  if (request.method === 'POST' && path === '/auth/google') {
    const body = await request.json().catch(() => null);
    const idToken = body?.id_token;
    if (!idToken) return json(request, 400, { error: 'id_token required' });
    const clientId = env.GOOGLE_CLIENT_ID || '';
    if (!clientId) return json(request, 503, { error: 'GOOGLE_CLIENT_ID not configured' });
    const claims = await verifyGoogleIdToken(idToken, clientId);
    if (!claims) return json(request, 401, { error: 'invalid id_token' });
    const user = await upsertUser(env, {
      provider: 'google',
      sub: claims.sub,
      email: claims.email,
      name: claims.name,
    });
    const { token, exp } = await mintSessionToken(env, user.id);
    return json(request, 200, sessionBody(user, token, exp));
  }

  if (request.method === 'POST' && path === '/auth/apple') {
    const body = await request.json().catch(() => null);
    const idToken = body?.id_token;
    if (!idToken) return json(request, 400, { error: 'id_token required' });
    const clientId = env.APPLE_CLIENT_ID || '';
    if (!clientId) return json(request, 503, { error: 'APPLE_CLIENT_ID not configured' });
    const claims = await verifyAppleIdToken(idToken, clientId);
    if (!claims) return json(request, 401, { error: 'invalid id_token' });
    const user = await upsertUser(env, {
      provider: 'apple',
      sub: claims.sub,
      email: claims.email,
      name: claims.name,
    });
    const { token, exp } = await mintSessionToken(env, user.id);
    return json(request, 200, sessionBody(user, token, exp));
  }

  // Local / staging only.
  if (request.method === 'POST' && path === '/auth/dev') {
    if (!devAuthAllowed(request, env)) return json(request, 404, { error: 'not found' });
    const body = await request.json().catch(() => null);
    const email = (body?.email || '').trim();
    if (!email) return json(request, 400, { error: 'email required' });
    const sub = `dev:${email.toLowerCase()}`;
    const user = await upsertUser(env, {
      provider: 'dev',
      sub,
      email,
      name: body?.name || email,
    });
    const { token, exp } = await mintSessionToken(env, user.id);
    return json(request, 200, sessionBody(user, token, exp));
  }

  if (request.method === 'POST' && path === '/auth/signout') {
    const auth = await userFromAuth(request, env);
    if (auth) await env.DB.prepare('DELETE FROM sessions WHERE token = ?').bind(auth.token).run();
    return empty(request, 204);
  }

  if (request.method === 'GET' && path === '/auth/me') {
    const auth = await userFromAuth(request, env);
    if (!auth) return json(request, 401, { error: 'unauthorized' });
    const row = await env.DB.prepare(
      'SELECT id, email, display_name, provider FROM users WHERE id = ?',
    )
      .bind(auth.userId)
      .first();
    if (!row) return json(request, 401, { error: 'unauthorized' });
    return json(request, 200, {
      userId: row.id,
      email: row.email,
      displayName: row.display_name,
      provider: row.provider,
      accessToken: auth.token,
      expiresAt: new Date(auth.exp).toISOString(),
    });
  }

  return json(request, 404, { error: 'not found' });
}

async function handleRecords(request, env, path, url) {
  const auth = await userFromAuth(request, env);
  if (!auth) return json(request, 401, { error: 'unauthorized' });
  const uid = auth.userId;

  if (request.method === 'GET' && path === '/v1/records') {
    const since = Number(url.searchParams.get('since') || '0') || 0;
    const { results } = await env.DB.prepare(
      'SELECT collection, id, data, updated_at_ms, deleted FROM records WHERE user_id = ? AND updated_at_ms > ? ORDER BY updated_at_ms ASC LIMIT 2000',
    )
      .bind(uid, since)
      .all();
    const items = (results || []).map((r) => ({
      collection: r.collection,
      id: r.id,
      data: JSON.parse(r.data || '{}'),
      updatedAtMs: r.updated_at_ms,
      deleted: !!r.deleted,
    }));
    return json(request, 200, { items });
  }

  const m = /^\/v1\/records\/([^/]+)\/([^/]+)$/.exec(path);
  if (!m) return json(request, 404, { error: 'not found' });
  const collection = decodeURIComponent(m[1]);
  const id = decodeURIComponent(m[2]);

  if (request.method === 'PUT') {
    const body = await request.json().catch(() => null);
    const updatedAtMs = Number(body?.updatedAtMs) || Date.now();
    const deleted = body?.deleted ? 1 : 0;
    const data = JSON.stringify(body?.data ?? {});
    // Last-writer-wins: ignore if existing is newer.
    const cur = await env.DB.prepare(
      'SELECT updated_at_ms FROM records WHERE user_id = ? AND collection = ? AND id = ?',
    )
      .bind(uid, collection, id)
      .first();
    if (cur && cur.updated_at_ms > updatedAtMs) {
      return json(request, 200, { ok: true, skipped: true });
    }
    await env.DB.prepare(
      `INSERT INTO records (user_id, collection, id, data, updated_at_ms, deleted)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id, collection, id) DO UPDATE SET
         data = excluded.data,
         updated_at_ms = excluded.updated_at_ms,
         deleted = excluded.deleted`,
    )
      .bind(uid, collection, id, data, updatedAtMs, deleted)
      .run();
    return json(request, 200, { ok: true });
  }

  if (request.method === 'DELETE') {
    const updatedAtMs = Number(url.searchParams.get('updatedAtMs') || Date.now());
    await env.DB.prepare(
      `INSERT INTO records (user_id, collection, id, data, updated_at_ms, deleted)
       VALUES (?, ?, ?, '{}', ?, 1)
       ON CONFLICT(user_id, collection, id) DO UPDATE SET
         updated_at_ms = excluded.updated_at_ms,
         deleted = 1`,
    )
      .bind(uid, collection, id, updatedAtMs)
      .run();
    return empty(request, 204);
  }

  return json(request, 405, { error: 'method not allowed' });
}

async function handleBlobs(request, env, path, url) {
  const auth = await userFromAuth(request, env);
  if (!auth) return json(request, 401, { error: 'unauthorized' });
  const uid = auth.userId;

  if (request.method === 'GET' && path === '/v1/blobs') {
    const since = Number(url.searchParams.get('since') || '0') || 0;
    const { results } = await env.DB.prepare(
      'SELECT id, updated_at_ms, deleted, size_bytes FROM blob_meta WHERE user_id = ? AND updated_at_ms > ? ORDER BY updated_at_ms ASC LIMIT 2000',
    )
      .bind(uid, since)
      .all();
    const items = (results || []).map((r) => ({
      id: r.id,
      updatedAtMs: r.updated_at_ms,
      deleted: !!r.deleted,
      sizeBytes: r.size_bytes,
    }));
    return json(request, 200, { items });
  }

  const m = /^\/v1\/blobs\/(.+)$/.exec(path);
  if (!m) return json(request, 404, { error: 'not found' });
  const id = decodeURIComponent(m[1]);
  const key = `${uid}/${id}`;

  if (request.method === 'PUT') {
    const updatedAtMs = Number(request.headers.get('X-Updated-At') || Date.now());
    const buf = await request.arrayBuffer();
    if (buf.byteLength > MAX_BLOB_BYTES) return json(request, 413, { error: 'blob larger than 25 MiB' });
    const cur = await env.DB.prepare(
      'SELECT updated_at_ms FROM blob_meta WHERE user_id = ? AND id = ?',
    )
      .bind(uid, id)
      .first();
    if (cur && cur.updated_at_ms > updatedAtMs) {
      return json(request, 200, { ok: true, skipped: true });
    }
    await env.BLOBS.put(`blob:${key}`, buf);
    await env.DB.prepare(
      `INSERT INTO blob_meta (user_id, id, updated_at_ms, deleted, size_bytes)
       VALUES (?, ?, ?, 0, ?)
       ON CONFLICT(user_id, id) DO UPDATE SET
         updated_at_ms = excluded.updated_at_ms,
         deleted = 0,
         size_bytes = excluded.size_bytes`,
    )
      .bind(uid, id, updatedAtMs, buf.byteLength)
      .run();
    return json(request, 200, { ok: true });
  }

  if (request.method === 'GET') {
    const obj = await env.BLOBS.get(`blob:${key}`, 'arrayBuffer');
    if (!obj) return json(request, 404, { error: 'not found' });
    return new Response(obj, {
      status: 200,
      headers: {
        'Content-Type': 'application/octet-stream',
        ...corsHeaders(request),
      },
    });
  }

  if (request.method === 'DELETE') {
    const updatedAtMs = Date.now();
    await env.BLOBS.delete(`blob:${key}`);
    await env.DB.prepare(
      `INSERT INTO blob_meta (user_id, id, updated_at_ms, deleted, size_bytes)
       VALUES (?, ?, ?, 1, 0)
       ON CONFLICT(user_id, id) DO UPDATE SET
         updated_at_ms = excluded.updated_at_ms,
         deleted = 1,
         size_bytes = 0`,
    )
      .bind(uid, id, updatedAtMs)
      .run();
    return empty(request, 204);
  }

  return json(request, 405, { error: 'method not allowed' });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    if (request.method === 'OPTIONS') {
      const origin = request.headers.get('Origin') || '';
      if (origin && !ALLOWED_ORIGINS.has(origin) && !isSelfOrigin(request, origin)) {
        return new Response(null, { status: 403 });
      }
      return empty(request, 204);
    }
    try {
      if (request.method === 'GET' && path === '/health') {
        return json(request, 200, { ok: true, service: 'collider' });
      }
      if (path.startsWith('/auth/')) return await handleAuth(request, env, path);
      if (path.startsWith('/v1/records')) return await handleRecords(request, env, path, url);
      if (path.startsWith('/v1/blobs')) return await handleBlobs(request, env, path, url);
      return json(request, 404, { error: 'not found' });
    } catch (e) {
      return json(request, 500, { error: 'server error' });
    }
  },
};
