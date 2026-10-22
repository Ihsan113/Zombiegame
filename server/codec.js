'use strict';
// Identical little-endian layout to scripts/game.gd's _decode_snapshot (Godot StreamPeerBuffer).
const clamp = (x, lo, hi) => Math.min(hi, Math.max(lo, Number.isFinite(x) ? x : lo));
const u = (x, hi = 255) => Math.round(clamp(x, 0, hi));
const pos = x => u(x * 8, 65535);
function encode(room, clock) {
  const b = Buffer.alloc(1180); let n = 0;
  const u8 = x => { b.writeUInt8(u(x), n); n += 1; };
  const u16 = x => { b.writeUInt16LE(u(x, 65535), n); n += 2; };
  const u32 = x => { b.writeUInt32LE((x >>> 0), n); n += 4; };
  const flt = x => { b.writeFloatLE(Number.isFinite(x) ? x : 0, n); n += 4; };
  const pt = (x, y) => { u16(pos(x)); u16(pos(y)); };
  const players = [...room.players.values()].sort((a, z) => a.id - z.id).slice(0, 4);
  const zombies = room.zombies.slice(0, 40);
  const absoluteClock = Date.now(); // full epoch ms; wire clock remains uint32
  u8(0xB7); u8((room.gameOver ? 1 : 0) | (room.timedOut ? 2 : 0));
  u32(++room.snapSeq); u32(clock); u16(960); u16(540); flt(room.worldTime);
  u16(room.wave); u8(room.spawned); u8(room.kills); u8(room.total); flt(room.breakTimer); flt(room.waveLeft);
  u8(players.length);
  for (const p of players) {
    let flags = (p.face < 0 ? 1 : 0) | (p.walking ? 2 : 0);
    if (p.replacePending) flags |= 4 | ((p.pendingWeapon & 7) << 3);
    u32(p.id); pt(p.x, p.y); u8(p.hp * 2); u8(flags); u8(p.med); u8(p.gren); u8(p.wall); u8(p.turret);
    u8(p.shootT * 100); u8(p.hurtT * 100); u8(p.slot);
    u8(p.w1 > 0 ? p.w1 : 255); u8(p.m1); u16(p.r1);
    u8(p.w2 > 0 ? p.w2 : 255); u8(p.m2); u16(p.r2);
    u8(p.reload * 100); u32(p.ack);
  }
  u8(zombies.length);
  for (const z of zombies) {
    let flags = (z.face < 0 ? 1 : 0) | (z.walking ? 2 : 0) | (z.attacking ? 4 : 0) | ((z.attackType || 0) << 3);
    u32(z.id); u8(z.kind); pt(z.x, z.y); u8(z.kind === 4 ? z.hp / z.maxHp * 255 : z.hp * 20);
    u8(flags); u8(z.attackT * 100); u8(z.hitT * 100);
  }
  u8(Math.min(room.walls.length, 8));
  for (const w of room.walls.slice(0, 8)) { u32(w.id); pt(w.x, w.y); u8(w.hp); u8(w.maxHp); }
  u8(Math.min(room.turrets.length, 4));
  for (const t of room.turrets.slice(0, 4)) {
    u16(t.id); pt(t.x, t.y); u8(t.hp);
    u8(u(((clamp(t.angle, -Math.PI / 2, Math.PI / 2) + Math.PI / 2) / Math.PI) * 127, 127) | (t.face < 0 ? 128 : 0));
  }
  u8(Math.min(room.drops.length, 4));
  for (const d of room.drops.slice(0, 4)) {
    u32(d.id); pt(d.x, d.y); u16(pos(d.startY)); u16(pos(d.landY));
    flt(d.elapsed); flt(d.fall); flt(d.despawn); u8(d.landed ? 1 : 0);
    u8(Math.max(0, ['grenade', 'wall', 'medkit', 'weapon', 'ammo', 'turret'].indexOf(d.kind)));
    u8(['weapon', 'ammo'].includes(d.kind) ? d.weapon : d.qty);
  }
  u8(Math.min(room.grenades.length, 8));
  for (const g of room.grenades.slice(0, 8)) {
    u32(g.id); pt(g.sx, g.sy); pt(g.tx, g.ty); flt(g.elapsed); flt(g.travel); u8(g.height);
  }
  // Effects newer than 220ms sent redundantly; bounded to 1180 bytes.
  const effects = room.effects.filter(f => absoluteClock - f.born >= 0 && absoluteClock - f.born <= 220).slice(-24).reverse().slice(0, Math.min(24, Math.floor((1180 - n - 1) / 16)));
  u8(effects.length);
  for (const f of effects) {
    u16(f.id & 65535); u8(f.kind); pt(f.x, f.y); pt(f.x2, f.y2);
    u8(f.ttl * 100); u8(f.life * 100);
    let src = players.findIndex(p => p.id === f.src); u8(src < 0 ? 255 : src);
    u16(absoluteClock - f.born);
  }
  if (n > 1180) throw new Error(`snapshot too large: ${n}`);
  return b.subarray(0, n);
}
function decodeInput(bytes) {
  if (!Buffer.isBuffer(bytes) || bytes.length < 1) return null;
  const count = bytes[0]; if (count > 24 || bytes.length !== 1 + count * 8) return null;
  const cmds = [];
  for (let i = 0; i < count; i++) { const k = 1 + i * 8;
    cmds.push({seq: bytes.readUInt32LE(k), qx: bytes.readInt8(k + 4), qy: bytes.readInt8(k + 5), dt: bytes.readUInt16LE(k + 6) / 10000});
  }
  return cmds;
}
module.exports = {encode, decodeInput};
