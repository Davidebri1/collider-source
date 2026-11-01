# Account sync — deploy (dashboard only)

**Do not create or extract API tokens.** David forbids that. Deploy uses **Cloudflare Workers Builds** (Git integration). Cloudflare creates and holds the build credential itself when you connect Git in the dashboard — you never paste a token.

Agents signed into David’s Cloudflare account do every step below as a dashboard click (or Google Cloud Console click). No `wrangler` login, no API tokens, no secret scraping.

GitHub Pages (`https://davidebri1.github.io/collider-app/`) stays a **permanent** second host. Cloudflare Worker is the primary address. Both must keep working.

---

## Dual hosting (permanent)

| Host | Role |
|------|------|
| **Cloudflare Worker** `https://collider.ebridavid.workers.dev` (custom domain later) | Primary: static app + account API, same origin |
| **GitHub Pages** `https://davidebri1.github.io/collider-app/` | Permanent second host — existing build-release-web → Pages pipeline unchanged |

Flutter default `COLLIDER_API_BASE` = Worker URL (absolute). Pages calls that URL; Worker CORS allows `https://davidebri1.github.io`. Same-origin on the Worker needs no CORS.

Do **not** retire GitHub Pages.

---

## What the repo already has

| Path | Purpose |
|------|---------|
| `server/worker/` | Worker source + `wrangler.toml` |
| `server/worker/migrations/0001_init.sql` | D1 schema (applied on deploy via `npm run deploy`) |
| `server/worker/scripts/fetch_web_dist.sh` | Downloads `collider-9.2.0-web.zip` from the `v9.2.0-smartgen` GitHub release into `dist/` (no Flutter on the build image) |
| `server/worker/package.json` | `build` = fetch zip; `deploy` = `wrangler d1 migrations apply DB --remote && wrangler deploy` |

Bump `COLLIDER_WEB_RELEASE_TAG` / `COLLIDER_WEB_ZIP_ASSET` as build variables when a newer web zip ships.

---

## A. Cloudflare dashboard — create storage

### A1. D1 database

1. Cloudflare dashboard → **Workers & Pages** → **D1** → **Create database**
2. Name: `collider-account` → Create
3. Open the database → copy **Database ID**
4. Paste it into `server/worker/wrangler.toml` replacing `REPLACE_WITH_D1_ID` (commit on `account-sync` before connecting Builds, or edit via dashboard binding later)

### A2. R2 bucket

1. **R2** → **Create bucket**
2. Name: `collider-account-blobs` → Create  
   (Binding name in wrangler is `BLOBS`; bucket name must match `wrangler.toml`)

### A3. KV namespace

1. **Workers & Pages** → **KV** → **Create a namespace**
2. Title: `collider-sessions` (any clear name)
3. Copy the **Namespace ID**
4. Paste into `wrangler.toml` replacing `REPLACE_WITH_KV_ID`

---

## B. Cloudflare dashboard — create / connect the Worker

### B1. Create Worker (if `collider` does not exist yet)

1. **Workers & Pages** → **Create** → **Worker**
2. Name: `collider` → Deploy stub (you will replace it with Git Builds)

### B2. Connect Workers Builds (Git) — preferred path

1. Open Worker **collider** → **Settings** → **Builds** (or **Workers Builds** / Connect to Git)
2. Connect **GitHub** → authorize Cloudflare’s GitHub app for the repo that contains `server/worker` (e.g. `Davidebri1/collider-source` or wherever this branch lives)
3. **Repository**: that repo  
4. **Production branch**: `account-sync` (until merged; then the long-lived branch you ship from)  
5. **Root directory**: `server/worker`  
6. **Build command**: `npm run build`  
   - Runs `scripts/fetch_web_dist.sh` → pulls the release web zip into `dist/`  
7. **Deploy command**: `npm run deploy`  
   - Applies D1 migrations remotely, then `wrangler deploy`  
8. Save / Enable builds  

Cloudflare attaches its own build token automatically. **Do not** add a custom API token. **Do not** create tokens in My Profile → API Tokens for this.

### B3. Bindings (if not already from wrangler.toml on first deploy)

Worker → **Settings** → **Bindings**:

| Type | Variable name | Resource |
|------|---------------|----------|
| D1 | `DB` | `collider-account` |
| R2 | `BLOBS` | `collider-account-blobs` |
| KV | `SESSIONS` | the KV namespace from A3 |

Assets come from `[assets]` in `wrangler.toml` (`./dist`).

---

## C. Runtime secrets (dashboard)

Worker → **Settings** → **Variables and Secrets** → **Add** → type **Secret**:

| Name | How to get the value |
|------|----------------------|
| `SESSION_SECRET` | Cloudflare does **not** generate this. On any trusted machine (David’s), run `openssl rand -base64 32`, copy the output, paste as the secret. Agents must not invent a weak value or store it in the repo. |
| `GOOGLE_CLIENT_ID` | From Google Cloud Console (section E below) — the OAuth **Web client** client ID string |
| `APPLE_CLIENT_ID` | Optional until iOS; Apple Services ID |
| `DEV_AUTH` | **Do not set** in production |

Optional plain text var: `KEYS_UPSTREAM` = `https://collider-keys.ebridavid.workers.dev`

---

## D. Build variables (optional, Workers Builds)

Worker → Builds → Variables (build-time only), if you need a newer zip:

| Name | Example |
|------|---------|
| `COLLIDER_WEB_RELEASE_TAG` | `v9.2.0-smartgen` |
| `COLLIDER_WEB_ZIP_ASSET` | `collider-9.2.0-web.zip` |
| `COLLIDER_WEB_ZIP_URL` | full URL override |

Default script URL (no vars needed for the first ship):

`https://github.com/Davidebri1/collider-source/releases/download/v9.2.0-smartgen/collider-9.2.0-web.zip`

---

## E. Google Cloud Console — OAuth Web client

Needed for “Continue with Google” in production (ID token audience).

1. [Google Cloud Console](https://console.cloud.google.com/) → select or create a project for Collider  
2. **APIs & Services** → **OAuth consent screen** → External (or Internal) → fill app name / support email → Save  
3. **APIs & Services** → **Credentials** → **Create credentials** → **OAuth client ID**  
4. Application type: **Web application**  
5. Name: `Collider Web`  
6. **Authorized JavaScript origins** (both hosts — permanent):  
   - `https://collider.ebridavid.workers.dev`  
   - `https://davidebri1.github.io`  
   - (Later: any custom domain you add for the Worker)  
7. Authorized redirect URIs: leave empty for GIS ID-token / One Tap style, or add GIS redirects if you use a redirect flow  
8. Create → copy **Client ID**  
9. Paste that Client ID into Cloudflare Worker secret `GOOGLE_CLIENT_ID` (section C)

Do **not** put the client secret in the Flutter app or in this Worker for ID-token verify (JWKS uses the client ID as audience only).

---

## F. First production checklist (browser agent)

1. A1–A3: D1, R2, KV created; IDs in `wrangler.toml` committed  
2. B2: Git connected; root `server/worker`; build `npm run build`; deploy `npm run deploy`  
3. C: `SESSION_SECRET` + `GOOGLE_CLIENT_ID` secrets set  
4. Trigger a build (push to the production branch, or **Retry deployment** in Builds)  
5. Open `https://collider.ebridavid.workers.dev/health` → OK  
6. Open `https://collider.ebridavid.workers.dev/` → Flutter app loads  
7. From a browser on `https://davidebri1.github.io`, confirm a fetch to `https://collider.ebridavid.workers.dev/health` succeeds (CORS)  
8. Confirm GitHub Pages still loads and is unchanged  
9. Google OAuth origins include both hosts (E)

---

## Local verify only (ports ≥ 9100 — never 8790 / 8791)

```bash
cd server/worker
npm install
DEV_AUTH=1 npx wrangler dev --port 9100 --local
# Flutter: --dart-define=COLLIDER_API_BASE=http://127.0.0.1:9100
```

Local D1: `npx wrangler d1 migrations apply DB --local`

---

## Why not GitHub Action + API token?

David forbids creating or extracting API tokens. Workers Builds connects Git in the dashboard and deploys without anyone minting a `CLOUDFLARE_API_TOKEN`. The Flutter SDK is not on Cloudflare’s image, so the build step **fetches the existing release web zip** instead of compiling Flutter there.
