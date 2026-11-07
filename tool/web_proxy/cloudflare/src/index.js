// Collider Wisp relay on Cloudflare Containers (needs the Workers Paid plan).
// The Worker answers /healthz itself, refuses any Origin but the Pages app,
// and forwards everything else (the /wisp/ WebSocket) to one container that
// runs ../Dockerfile (wisp_server.mjs). The container sleeps after 10 idle
// minutes and starts again on the next connection (a few seconds).
import { Container, getContainer, switchPort } from '@cloudflare/containers';

const APP_ORIGIN = 'https://davidebri1.github.io';

export class WispContainer extends Container {
  defaultPort = 8080;
  sleepAfter = '10m';
  enableInternet = true;
  envVars = { HOST: '0.0.0.0', PORT: '8080', ALLOWED_ORIGINS: APP_ORIGIN };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/healthz') return new Response('ok', { headers: { 'content-type': 'text/plain' } });
    // A private relay for the app, not an open proxy.
    if ((request.headers.get('Origin') || '') !== APP_ORIGIN) return new Response('forbidden', { status: 403 });
    return getContainer(env.WISP, 'wisp').fetch(switchPort(request, 8080));
  },
};
