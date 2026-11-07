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

The app already points at this URL (`lib/main.dart:73`, `COLLIDER_ACCOUNT_API`).
AccountSync pings `/health`, and it syncs only after a sign-in.
`AccountSync.signInWithIdToken` exists, but no screen calls it yet, because the
web build has no Google Sign-In button that returns an ID token. Until one is
added, the app keeps using its local copy (which survives a reload) and the
Worker has no users.
