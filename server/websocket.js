'use strict';
// RFC6455 WebSocket frames over the SAME HTTP port. No external npm dependencies.
const {createHash, timingSafeEqual} = require('node:crypto');
const {EventEmitter} = require('node:events');
const ACCEPT_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
class SocketPeer extends EventEmitter {
  constructor(socket, head = Buffer.alloc(0)) {
    super(); this.socket = socket; this.pending = Buffer.alloc(0); this.alive = true;
    this.fragmentOpcode = 0; this.fragments = []; this.fragmentLength = 0;
    socket.on('data', b => this._ingest(b));
    socket.on('close', () => this._finish());
    socket.on('error', () => this._finish());
    socket.on('end', () => this._finish());
    if (head.length) process.nextTick(() => this._ingest(head));
  }
  _finish() { if (!this.alive) return; this.alive = false; this.emit('close'); }
  _send(op, body) {
    if (!this.alive || this.socket.destroyed) return false;
    const data = Buffer.isBuffer(body) ? body : Buffer.from(body);
    const ext = data.length <= 125 ? 0 : (data.length <= 65535 ? 2 : 8);
    const header = Buffer.alloc(2 + ext);
    header[0] = 0x80 | op;
    header[1] = ext === 0 ? data.length : (ext === 2 ? 126 : 127);
    if (ext === 2) header.writeUInt16BE(data.length, 2);
    if (ext === 8) header.writeBigUInt64BE(BigInt(data.length), 2);
    this.socket.cork(); this.socket.write(header); this.socket.write(data); this.socket.uncork(); return true;
  }
  json(data) { return this._send(1, JSON.stringify(data)); }
  binary(bytes) { return this._send(2, bytes); }
  ping() { return this._send(9, Buffer.alloc(0)); }
  close(code = 1000) {
    if (!this.alive) return;
    const bytes = Buffer.alloc(2); bytes.writeUInt16BE(code);
    this._send(8, bytes); this.socket.end(); this._finish();
  }
  _ingest(data) {
    if (!this.alive) return;
    if (this.pending.length + data.length > 131072) return this.close(1009);
    this.pending = Buffer.concat([this.pending, data]);
    while (this.pending.length >= 2) {
      const b = this.pending; const fin = (b[0] & 128) !== 0;
      const opcode = b[0] & 15; const masked = (b[1] & 128) !== 0;
      if ((b[0] & 0x70) || !masked) return this.close(1002);
      let size = b[1] & 127, offset = 2;
      if (size === 126) { if (b.length < 4) return; size = b.readUInt16BE(2); offset = 4; }
      else if (size === 127) {
        if (b.length < 10) return;
        const big = b.readBigUInt64BE(2);
        if (big > 65536n) return this.close(1009);
        size = Number(big); offset = 10;
      }
      if (size > 65536) return this.close(1009);
      if (opcode >= 8 && (!fin || size > 125)) return this.close(1002);
      if (b.length < offset + 4 + size) return;
      const mask = b.subarray(offset, offset + 4);
      const body = Buffer.from(b.subarray(offset + 4, offset + 4 + size));
      for (let i = 0; i < size; i++) body[i] ^= mask[i & 3];
      this.pending = b.subarray(offset + 4 + size);
      if (opcode === 8) { this.close(); return; }
      if (opcode === 9) { this._send(10, body); continue; }
      if (opcode === 10) { this.emit('pong'); continue; }
      if (opcode === 1 || opcode === 2) {
        if (this.fragmentOpcode) return this.close(1002);
        if (fin) this.emit('message', body, opcode === 2);
        else { this.fragmentOpcode = opcode; this.fragments = [body]; this.fragmentLength = body.length; }
      } else if (opcode === 0 && this.fragmentOpcode) {
        this.fragments.push(body); this.fragmentLength += body.length;
        if (this.fragmentLength > 65536) return this.close(1009);
        if (fin) { this.emit('message', Buffer.concat(this.fragments), this.fragmentOpcode === 2); this.fragmentOpcode = 0; this.fragments = []; this.fragmentLength = 0; }
      } else return this.close(1002);
    }
  }
}
function upgrade(req, socket, head, onPeer) {
  const key = req.headers['sec-websocket-key'];
  if (req.method !== 'GET' || req.url !== '/ws' || req.headers.upgrade?.toLowerCase() !== 'websocket' ||
      !req.headers.connection?.toLowerCase().split(',').map(x => x.trim()).includes('upgrade') ||
      req.headers['sec-websocket-version'] !== '13' || typeof key !== 'string' ||
      !/^[\w+/]{22}==$/.test(key) || Buffer.from(key, 'base64').length !== 16) {
    socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n'); return;
  }
  const accept = createHash('sha1').update(key + ACCEPT_GUID).digest('base64');
  socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ' + accept + '\r\n\r\n');
  socket.setNoDelay(true); socket.setKeepAlive(true, 30000);
  onPeer(new SocketPeer(socket, head));
}
module.exports = {upgrade, SocketPeer};
