/**
 * Free-plan Wisp relay for the Scramjet/libcurl browser transport.
 * Packet layout: ./packet.js. TCP: cloudflare:sockets connect(). No containers.
 * Not a deployment. See ../TESTPLAN.md.
 */
import { connect } from 'cloudflare:sockets';
import { CREDIT, packet, parse, u8 } from './packet.js';

const APP_ORIGIN = 'https://davidebri1.github.io';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/healthz') {
      return new Response('ok', { headers: { 'content-type': 'text/plain' } });
    }
    const origin = request.headers.get('Origin') || '';
    if (origin !== APP_ORIGIN) return new Response('forbidden', { status: 403 });
    if (url.pathname !== '/wisp/' || request.headers.get('Upgrade') !== 'websocket') {
      return new Response('not found', { status: 404 });
    }
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    server.accept();
    if ('binaryType' in server) server.binaryType = 'arraybuffer';
    const streams = new Map();
    server.send(packet(3, 0, u8(CREDIT, 4)));
    server.addEventListener('message', (event) => {
      const msg = parse(event.data);
      if (!msg) return;
      if (msg.type === 1) openStream(server, streams, msg).catch(() => {});
      else if (msg.type === 2) writeStream(streams, msg);
      else if (msg.type === 4) closeStream(streams, msg.streamId);
    });
    server.addEventListener('close', () => {
      for (const id of [...streams.keys()]) closeStream(streams, id);
    });
    return new Response(null, { status: 101, webSocket: client });
  },
};

async function openStream(ws, streams, msg) {
  const payload = msg.payload;
  if (payload.length < 3) return;
  const streamType = payload[0];
  const port = new DataView(payload.buffer, payload.byteOffset, payload.byteLength).getUint16(1, true);
  const host = new TextDecoder().decode(payload.subarray(3));
  if (streamType !== 1) {
    ws.send(packet(4, msg.streamId, u8(0x03, 1)));
    return;
  }
  let socket;
  try {
    socket = connect({ hostname: host, port });
    await socket.opened;
  } catch {
    ws.send(packet(4, msg.streamId, u8(0x03, 1)));
    return;
  }
  const writer = socket.writable.getWriter();
  streams.set(msg.streamId, { socket, writer });
  ws.send(packet(3, msg.streamId, u8(CREDIT, 4)));
  pump(ws, msg.streamId, socket, streams);
}

async function pump(ws, streamId, socket, streams) {
  const reader = socket.readable.getReader();
  try {
    while (streams.has(streamId)) {
      const { value, done } = await reader.read();
      if (done) break;
      if (value && value.byteLength) ws.send(packet(2, streamId, value));
    }
  } catch {
    /* destination closed or blocked */
  }
  if (streams.has(streamId)) {
    ws.send(packet(4, streamId, u8(0x02, 1)));
    closeStream(streams, streamId);
  }
}

function writeStream(streams, msg) {
  const s = streams.get(msg.streamId);
  if (!s) return;
  s.writer.write(msg.payload).catch(() => {});
}

function closeStream(streams, streamId) {
  const s = streams.get(streamId);
  if (!s) return;
  streams.delete(streamId);
  s.writer.close().catch(() => {});
  try {
    s.socket.close();
  } catch {
    /* already closed */
  }
}
