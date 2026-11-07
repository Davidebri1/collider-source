// Wisp server (wisp-js by Mercury Workshop): carries the browser's proxied
// connections. For local runs and the e2e; production needs one hosted
// somewhere reachable over wss:// (see STATUS.md "Web finish").
//   PORT=8899 node tool/web_proxy/wisp_server.mjs
import http from 'node:http';
import { server as wisp, logging } from '@mercuryworkshop/wisp-js/server';

logging.set_level(logging.WARN);
// WISP_ALLOW_PRIVATE=1 only for this box: its DNS answers every name with the
// egress tunnel's 198.18.0.1, which wisp-js otherwise refuses as private.
Object.assign(wisp.options, { allow_udp_streams: false, allow_loopback_ips: false, allow_private_ips: process.env.WISP_ALLOW_PRIVATE === '1' });
const port = Number(process.env.PORT || 8899);
if (port === 8790 || port === 8791) throw new Error('8790/8791 are reserved');
const s = http.createServer((_q, r) => { r.writeHead(404); r.end(); });
s.on('upgrade', (req, sock, head) => {
  if ((req.url || '').endsWith('/wisp/')) wisp.routeRequest(req, sock, head);
  else sock.end();
});
s.listen(port, '127.0.0.1', () => console.log(`wisp on ws://127.0.0.1:${port}/wisp/`));
