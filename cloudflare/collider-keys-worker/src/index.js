/**
 * Collider keys Worker — OpenAI-compatible chat proxy.
 * Holds provider keys as Worker secrets; browser never sees them.
 * CORS: https://davidebri1.github.io only.
 *
 * POST /api/p?u=crazyrouter|nvidia|opencode|commandcode|minimax
 * Body: { model, messages, max_tokens? }  (OpenAI chat completions shape)
 * No Vercel route (revoked; may return later as a secret only).
 */

const ALLOW_ORIGIN = 'https://davidebri1.github.io';

const PROVIDERS = {
  crazyrouter: {
    base: 'https://crazyrouter.com/v1',
    keyEnv: 'CRAZYROUTER_KEY',
  },
  nvidia: {
    base: 'https://integrate.api.nvidia.com/v1',
    keyEnv: 'NVIDIA_KEY',
  },
  opencode: {
    base: 'https://opencode.ai/zen/v1',
    keyEnv: 'OPENCODE_KEY',
  },
  commandcode: {
    baseEnv: 'COMMANDCODE_BASE',
    baseDefault: 'https://api.commandcode.ai/provider/v1',
    keyEnv: 'COMMANDCODE_KEY',
  },
  minimax: {
    base: 'https://api.minimax.io/v1',
    keyEnv: 'MINIMAX_KEY',
  },
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': ALLOW_ORIGIN,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  });
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin') || '';

    if (request.method === 'OPTIONS') {
      if (origin && origin !== ALLOW_ORIGIN) {
        return new Response(null, { status: 403 });
      }
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    if (origin && origin !== ALLOW_ORIGIN) {
      return json(403, { error: 'origin not allowed' });
    }

    const url = new URL(request.url);
    if (request.method === 'GET' && (url.pathname === '/' || url.pathname === '/health')) {
      return json(200, { ok: true, service: 'collider-keys' });
    }

    if (request.method !== 'POST' || url.pathname !== '/api/p') {
      return json(404, { error: 'not found' });
    }

    const u = (url.searchParams.get('u') || '').toLowerCase();
    if (u === 'vercel' || u === 'vc') {
      return json(501, { error: 'vercel route disabled' });
    }
    const cfg = PROVIDERS[u];
    if (!cfg) {
      return json(400, { error: 'unknown provider', u });
    }

    const key = env[cfg.keyEnv] || '';
    if (!key) {
      return json(503, { error: 'provider key not configured', provider: u });
    }

    const base = cfg.base || env[cfg.baseEnv] || cfg.baseDefault;
    if (!base) {
      return json(503, { error: 'provider base not configured', provider: u });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json(400, { error: 'invalid json' });
    }

    const upstream = `${String(base).replace(/\/$/, '')}/chat/completions`;
    let upstreamRes;
    try {
      upstreamRes = await fetch(upstream, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify(body),
      });
    } catch (e) {
      return json(502, { error: 'upstream unreachable', provider: u });
    }

    const text = await upstreamRes.text();
    return new Response(text, {
      status: upstreamRes.status,
      headers: {
        'Content-Type': upstreamRes.headers.get('Content-Type') || 'application/json',
        ...corsHeaders(),
      },
    });
  },
};
