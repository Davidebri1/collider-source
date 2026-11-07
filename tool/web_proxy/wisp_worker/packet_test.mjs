import assert from 'node:assert/strict';
import { packet, parse, CREDIT } from './src/packet.js';

const hello = packet(3, 0, new Uint8Array(new Uint32Array([CREDIT]).buffer));
const back = parse(hello.buffer);
assert.equal(back.type, 3);
assert.equal(back.streamId, 0);
assert.equal(new DataView(back.payload.buffer, back.payload.byteOffset, back.payload.byteLength).getUint32(0, true), CREDIT);

const host = new TextEncoder().encode('example.com');
const body = new Uint8Array(3 + host.length);
body[0] = 1;
new DataView(body.buffer).setUint16(1, 443, true);
body.set(host, 3);
const connect = parse(packet(1, 7, body).buffer);
assert.equal(connect.streamId, 7);
assert.equal(connect.payload[0], 1);
assert.equal(new DataView(connect.payload.buffer, connect.payload.byteOffset, connect.payload.byteLength).getUint16(1, true), 443);
assert.equal(new TextDecoder().decode(connect.payload.subarray(3)), 'example.com');
assert.equal(parse(new Uint8Array([1, 2])), null);
console.log('wisp packet layout ok');
