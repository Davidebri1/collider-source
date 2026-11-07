# Hosting the Wisp relay (Collider in-app browser)

The browser's proxy (Scramjet) runs in the page; it needs one small always-reachable relay,
`wisp_server.mjs`, at a `wss://` address. Chosen host: **Google Cloud Run** (David's Google account).

## Why Cloud Run (checked Nov 7, 2026)
| Host | WebSocket | Free, no card | Sleeps when idle | Allows a proxy relay |
|---|---|---|---|---|
| Google Cloud Run | yes, up to 60 min per connection | free tier, but a billing account (card) is required | no sleep page; scales to zero, first connect ~1–3 s | general terms; this relay is locked to the app's origin, not public |
| Render free | yes | yes | yes: after 15 min idle, ~1 min to wake | AUP forbids proxies/VPNs |
| Koyeb free | yes | no (card + $29 hold) | yes: after 1 h idle | – |
| Fly.io | yes | no free tier (card after $1 trial) | no | "public proxies" disallowed |
| Railway | yes | Free plan: $1 credit/month (too little for browsing traffic) | no (Serverless off) | forbids proxies/VPNs |
| Deno Deploy | yes | yes | isolates scale to zero | forbids forward proxies and raw TCP to port 443 (needed here) |
| Hugging Face Spaces | yes | yes | after 48 h idle | content policy forbids proxies |
| Cloudflare Containers | yes | no (Workers Paid, $5/month) | – | – |
| Cloudflare Workers (wisp-server-workers) | yes | yes | no | about 6 connections at once, and can't reach sites hosted on Cloudflare |

No host is free *and* card-free *and* never-sleeping *and* permits a proxy relay. Cloud Run is
the closest: free-tier usage costs nothing, there is no sleep page, and David already has the
Google account. `ALLOWED_ORIGINS` (set in the Dockerfile) makes the relay refuse any page other
than `https://davidebri1.github.io`, so it is a private relay for Collider, not an open proxy.
Cloud Run's free egress is small (about 1 GiB/month in North America); after that it is cents per GB.

## Steps (a browser agent can follow; David signs in and enters the card himself)
Prerequisite: the branch with `tool/web_proxy/` is pushed to David's GitHub repo (David publishes).
1. Open https://console.cloud.google.com and sign in with David's Google account.
2. Top bar → project picker → **New project** → name `collider-wisp` → **Create** → select it.
3. **Billing** → link a billing account (David enters the card; the free tier is not charged).
   Then **Billing → Budgets & alerts → Create budget** → $1 → alerts at 50/90/100 %.
4. Go to https://console.cloud.google.com/run → **Deploy container** →
   **Continuously deploy from a repository (source or function)** → **Set up with Cloud Build**.
5. Repository provider **GitHub** → **Authenticate** (GitHub sign-in, install the Cloud Build app
   on the repo only) → pick the Collider repo → **Next**.
6. Branch: the branch David pushed (regex, e.g. `^main$`). Build type **Dockerfile**.
   Source location: `/tool/web_proxy/Dockerfile` → **Save**.
7. Service name `collider-wisp`; Region `us-east1`; Authentication **Allow public access**
   (the relay checks the page origin itself); Billing **Request-based**; Minimum instances `0`;
   Maximum instances `1`.
8. **Container(s), Volumes, Networking, Security** → Container port `8080`; Memory `256 MiB`;
   Request timeout `3600`. (The Dockerfile already sets HOST, PORT and ALLOWED_ORIGINS.)
9. **Create**. Wait for the green check; copy the URL, e.g. `https://collider-wisp-abc123-ue.a.run.app`.
10. Check: open `<URL>/healthz` → it shows `ok`.
11. In the app repo set `web/proxy/config.js` to
    `self.COLLIDER_WISP_URL = "wss://collider-wisp-abc123-ue.a.run.app/wisp/";`, rebuild
    (`tool/build_web.sh`) and publish. Until then the browser keeps using the current page proxy.

Command-line alternative (Cloud Shell, after steps 1–3):
`gcloud run deploy collider-wisp --source tool/web_proxy --region us-east1 --allow-unauthenticated --port 8080 --timeout 3600 --min-instances 0 --max-instances 1 --memory 256Mi`
