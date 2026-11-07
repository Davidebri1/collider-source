# AccountSync Worker: `https://collider.ebridavid.workers.dev`

`src/index.js` is one file that implements exactly the API that
`lib/core/account_sync/account_sync_client.dart` calls (the list is at the
top of the file). It stores everything in **D1** (users, sessions, records,
blob metadata) and the file bytes in **Workers KV** (up to 25 MiB each).
Both are on the **Workers Free plan**, so no card is needed. It doesn't use R2,
because R2 needs a payment method on file.

Free-plan limits that apply (Cloudflare docs, checked 2026-11-07):
- Workers: 100,000 requests a day.
- KV: 1,000 writes and 100,000 reads a day, 1 GB stored, 25 MiB per value. KV is eventually
  consistent: a file saved on one device can take up to about 60 s to show up
  on another.
- D1: 5 GB stored.

Tested locally with `wrangler dev` (`npm run dev`, then `npm run test:api`): 20/20.

## Dashboard steps (no wrangler login, no API tokens)

A browser agent signed in to David's Cloudflare account (`ebridavid`) does the following.

1. Open https://dash.cloudflare.com and sign in. If Cloudflare asks, pick the
   account whose workers.dev subdomain is `ebridavid` (the one that already
   has `collider-keys`).
2. **Create the database.** In the left sidebar, open **Storage & databases > D1 SQL database**.
   Select **Create Database**, name it `collider-account`, leave the location
   as it is, and select **Create**.
3. In `collider-account`, select **Console**. Paste the whole of
   `tool/worker/schema.sql` and select **Execute**. Open **Tables**: you should see
   `users`, `records`, `blob_meta` and `sessions`.
4. **Create the KV namespace.** Open **Storage & databases > Workers KV**, select
   **Create instance**, name it `collider-account-blobs`, and select **Create**.
5. **Create the Worker.** Open **Workers & Pages**, select **Create application**,
   then **Start with Hello World! > Get started**. Name it **`collider`** (this
   name gives the URL `collider.ebridavid.workers.dev`) and select **Deploy**.
6. Select **Edit code** (the `</>` icon). Delete everything in `worker.js`, paste
   the whole of `tool/worker/src/index.js`, and select **Deploy**.
7. **Bind the database.** Back on the Worker, open the **Bindings** tab and select **Add binding**.
   Choose **D1 database > Add binding**, set Variable name to `DB`, pick
   `collider-account`, and select **Add binding**.
8. **Bind the KV namespace.** Select **Add binding** again. Choose **KV namespace > Add binding**, set
   Variable name to `BLOBS`, pick `collider-account-blobs`, and select **Add binding**.
9. **Add the Google client ID** (needed only for Google sign-in). Open **Settings > Variables and Secrets** and select **Add**.
   Set Type to Text, Name to `GOOGLE_CLIENT_ID`, and Value to the OAuth Web client ID from
   Google Cloud Console > APIs & Services > Credentials. Select **Deploy**. Do **not** add
   `DEV_AUTH` in production.
10. **Check it.** Open `https://collider.ebridavid.workers.dev/health`. It should show
    `{"ok":true,"service":"collider"}`.

With wrangler instead (only if David prefers a terminal): put the D1 id and KV id into
`wrangler.toml`, then run `npx wrangler d1 migrations apply DB --remote && npx wrangler deploy`
from `tool/worker`.

## What the app still needs

The app already points at this URL (`lib/main.dart`, `COLLIDER_ACCOUNT_API`).
AccountSync pings `/health`, and it syncs only after a sign-in.
Continue with Google calls `signInWithIdToken` with a Google Identity Services
ID token. It does not call `/auth/dev`. Dev sign-in stays on the Worker for
the local API test only (`DEV_AUTH=1`).

This Worker is not deployed. `collider.ebridavid.workers.dev` was not created
by this change. A local reload is not cross-device sync.

## Google sign-in and calendar (David's setup, not done here)

1. In Google Cloud Console, create an OAuth client of type **Web** for Collider.
   Authorized JavaScript origin: `https://davidebri1.github.io`.
   No client secret belongs in the app.
2. Enable the **Google Calendar API** on that project.
3. Put the client id in `web/account_config.js` as `COLLIDER_GOOGLE_CLIENT_ID`
   (it ships empty). Rebuild is not required if that file is replaced on the host.
4. Continue with Google then asks Google for an ID token and the account Worker
   verifies it (`POST /auth/google`). Calendar Sync asks for an access token
   with scope `https://www.googleapis.com/auth/calendar.events` and talks to
   Google Calendar from the browser. Export still downloads an `.ics` file.
   Export is not sync.
5. The account Worker must be deployed (steps above) and `GOOGLE_CLIENT_ID`
   on the Worker must be the same client id, or sign-in returns 401/503.
   Apple sign-in still needs an Apple Services ID (`COLLIDER_APPLE_CLIENT_ID`);
   the Apple button does not sign in until that exists.
