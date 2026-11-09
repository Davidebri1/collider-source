import assert from 'node:assert/strict';
import { googleClaimsOk, devAuthAllowed } from './src/index.js';

const now = Date.UTC(2026, 10, 7);
const good = {
  aud: 'client',
  iss: 'https://accounts.google.com',
  sub: 'user',
  exp: Math.floor(now / 1000) + 60,
};
assert.equal(googleClaimsOk(good, 'client', now), true);
assert.equal(googleClaimsOk({ ...good, aud: ['other', 'client'] }, 'client', now), true);
assert.equal(googleClaimsOk({ ...good, aud: 'other' }, 'client', now), false);
assert.equal(googleClaimsOk({ ...good, iss: 'https://evil.example' }, 'client', now), false);
assert.equal(googleClaimsOk({ ...good, exp: Math.floor(now / 1000) - 5 }, 'client', now), false);
assert.equal(googleClaimsOk({ ...good, sub: '' }, 'client', now), false);
assert.equal(googleClaimsOk(good, '', now), false);

const prod = { url: 'https://collider.ebridavid.workers.dev/auth/dev' };
assert.equal(devAuthAllowed(prod, { DEV_AUTH: '1' }), false);
assert.equal(devAuthAllowed({ url: 'http://127.0.0.1:9300/auth/dev' }, { DEV_AUTH: '1' }), true);
assert.equal(devAuthAllowed({ url: 'http://127.0.0.1:9300/auth/dev' }, {}), false);
console.log('account claims ok');
