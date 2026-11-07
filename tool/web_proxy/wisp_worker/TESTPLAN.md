# Free Worker Wisp — deployed test plan

This is a plan. It is not a test that has been run, and it is not evidence that a Worker relay works. The local Node server in `tool/web_proxy/wisp_server.mjs` is a different program.

## What to deploy

`tool/web_proxy/wisp_worker/` on the Workers **Free** plan. It speaks the same Wisp packets as `web/proxy/libcurl/index.mjs` and opens TCP with `cloudflare:sockets` `connect()`. It does not use Cloudflare Containers.

## Cloudflare destinations

Official TCP sockets documentation (https://developers.cloudflare.com/workers/runtime-apis/tcp-sockets/) says outbound `connect()` is blocked for:

- private addresses, including localhost
- port 25
- **Cloudflare IP ranges**

A site whose DNS answers with a Cloudflare address (orange-cloud proxy, many `*.pages.dev` hosts, and other Cloudflare-fronted sites) cannot be opened as a raw TCP socket from the Worker. `fetch()` can still request those hosts as HTTP, but it is not a byte tunnel, and the browser transport here does its own TLS through Wisp. So GitHub, Wikipedia, or any other host that happens to sit behind Cloudflare will fail on this relay even when the Worker itself is healthy. That is a platform block, not something this relay routes around.

Free-plan connection count is small (the platform table has listed 6 simultaneous outgoing connections per request). The plan below is how to measure that on a real deploy. It has not been measured here.

## Steps, after the Cloudflare connector is signed in

1. `npx wrangler deploy` from this directory on the free plan. No container, no paid flag.
2. Note the `wss://<name>.<subdomain>.workers.dev/wisp/` URL.
3. Put that URL in `web/proxy/config.js` as `self.COLLIDER_WISP_URL` and rebuild. Do not treat an empty config as this relay.
4. From the Pages origin only, open the in-app browser to `https://example.com` (not on Cloudflare) and record whether the page paints.
5. Repeat for a host that resolves to a Cloudflare IP. Expect the socket to fail. Record the close, not a workaround.
6. Open several subresources at once (a page with many images) and record when new sockets stop. That number is the measured connection limit. Do not copy the “about 6” figure in as a result of this plan.

## Local packet check

`node tool/web_proxy/wisp_worker/packet_test.mjs` checks the packet bytes against the client layout. It does not open a socket and does not deploy.
