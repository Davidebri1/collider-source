/** Wisp bytes shared with web/proxy/libcurl/index.mjs. No sockets. */

export const CREDIT = 32;

export function u8(n, size) {
  const b = new Uint8Array(size);
  const v = new DataView(b.buffer);
  if (size === 1) v.setUint8(0, n);
  else if (size === 2) v.setUint16(0, n, true);
  else if (size === 4) v.setUint32(0, n, true);
  return b;
}

export function packet(type, streamId, payload) {
  const out = new Uint8Array(5 + payload.length);
  out[0] = type;
  out.set(u8(streamId, 4), 1);
  out.set(payload, 5);
  return out;
}

export function parse(buf) {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  if (bytes.length < 5) return null;
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  return {
    type: bytes[0],
    streamId: view.getUint32(1, true),
    payload: bytes.subarray(5),
  };
}
