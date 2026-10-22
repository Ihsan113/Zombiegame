'use strict';
// Constants mirrored from the stable LAN/offline scripts/game.gd, in the server's
// canonical 960x540 world. All client actions use normalized coordinates.
const WIDTH = 960, HEIGHT = 540;
const ARENA_TOP = HEIGHT * 0.520 + 22;
const ARENA_BOTTOM = HEIGHT * 0.865 - 40;
const PI = Math.PI;
const clamp = (v, a, b) => Math.max(a, Math.min(b, Number.isFinite(v) ? v : a));
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const laneY = y => clamp(y, ARENA_TOP, ARENA_BOTTOM);
const fromRatio = (x, y, pad) => ({x:clamp(clamp(Number(x), 0, 1)*WIDTH,pad,WIDTH-pad), y:laneY(clamp(Number(y),0,1)*HEIGHT)});
const wrapAngle = rad => ((rad + PI) % (2*PI) + 2*PI) % (2*PI) - PI;
function aimGrenade(p, xRatio, yRatio) {
  const aimed = fromRatio(xRatio,yRatio,30);
  let dx=aimed.x-p.x,dy=aimed.y-p.y,mag=Math.hypot(dx,dy);
  if (mag<1){dx=p.face<0?-1:1;dy=0;mag=1;}
  dx/=mag;dy/=mag;
  const range=clamp(mag,WIDTH*.065,WIDTH*.30);
  const target={x:clamp(p.x+dx*range,30,WIDTH-30),y:laneY(p.y+dy*range)};
  const actual=distance(p,target);
  return {start:{x:p.x+dx*18,y:p.y+dy*18-9},target,
    travel:.38+(.82-.38)*clamp(actual/(WIDTH*.30),0,1),
    height:clamp(actual*.3,44,116)};
}
function canPlaceWall(p,pos,walls){
  const d=distance(p,pos);
  if(d<82||d>WIDTH*.145||pos.x<44||pos.x>WIDTH-44||pos.y<ARENA_TOP||pos.y>ARENA_BOTTOM)return false;
  return !walls.some(w=>Math.abs(w.x-pos.x)<64&&Math.abs(w.y-pos.y)<60);
}
function canPlaceTurret(p,pos,turrets,walls){
  const d=distance(p,pos);
  if(d<48||d>WIDTH*.22||pos.x<35||pos.x>WIDTH-35||pos.y<ARENA_TOP||pos.y>ARENA_BOTTOM)return false;
  if(turrets.some(t=>distance(t,pos)<54))return false;
  if(walls.some(w=>distance(w,pos)<62))return false;
  return true;
}
function turretAngle(t,aim){
  const face=t.face<0?-1:1;
  const heading=Math.atan2(aim.y-(t.y-1.2),aim.x-t.x);
  return clamp(wrapAngle(heading-(face<0?PI:0)),-PI/2,PI/2);
}
function turretMuzzle(t){
  const face=t.face<0?-1:1;
  const relative=clamp(t.angle||0,-PI/2,PI/2);
  const angle=(face<0?PI:0)+relative;
  // EXACT same muzzle model as stable GDScript: pivot -1.2 px,
  // 43.5 px along the rotated barrel and +8.3 px normal offset.
  return {x:t.x+Math.cos(angle)*43.5+Math.sin(relative)*8.3,
          y:t.y-1.2+Math.sin(angle)*43.5-Math.cos(relative)*8.3};
}
module.exports={WIDTH,HEIGHT,ARENA_TOP,ARENA_BOTTOM,clamp,distance,laneY,fromRatio,aimGrenade,
  canPlaceWall,canPlaceTurret,turretAngle,turretMuzzle};
