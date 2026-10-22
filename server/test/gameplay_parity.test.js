'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const G=require('../geometry');
const {GameRoom}=require('../game');
const {encode}=require('../codec');

const closeEnough=(actual,expected,tolerance=.2)=>assert.ok(Math.abs(actual-expected)<tolerance,`${actual} not within ${tolerance} of ${expected}`);
function room(t){
  const game=new GameRoom('MATCH1',{info(){},error(){}});
  const events=[];
  const peer={alive:true, socket:{writableLength:0}, json(x){events.push(x);},binary(){},close(){this.alive=false;}};
  const player=game.add(peer,true);
  player.x=480;player.y=370;player.face=1;
  game.started=true;game.spawnTimer=1000;game.dropTimer=1000;
  t.after(()=>game.close());
  return {game,player,events};
}
test('LAN arena constants and placement rules mirror Godot 960x540',()=>{
  closeEnough(G.ARENA_TOP,302.8,.001);closeEnough(G.ARENA_BOTTOM,427.1,.001);
  const p={x:480,y:370};
  assert.equal(G.canPlaceWall(p,{x:580,y:370},[]),true);
  assert.equal(G.canPlaceWall(p,{x:560,y:370},[]),false,'wall <82 px from survivor');
  assert.equal(G.canPlaceWall(p,{x:620,y:370},[]),false,'wall >139.2 px from survivor');
  assert.equal(G.canPlaceWall(p,{x:580,y:370},[{x:520,y:370}]),false,'sprite footprints overlap');
  assert.equal(G.canPlaceWall(p,{x:584,y:370},[{x:520,y:370}]),true,'64 px side-by-side spacing allowed');
  assert.equal(G.canPlaceTurret(p,{x:670,y:370},[],[]),true,'190px turret valid in LAN');
  assert.equal(G.canPlaceTurret(p,{x:525,y:370},[],[]),false,'48px minimum turret distance');
  assert.equal(G.canPlaceTurret(p,{x:670,y:370},[{x:620,y:370}],[]),false);
  assert.equal(G.canPlaceTurret(p,{x:670,y:370},[],[{x:615,y:370}]),false);
});
test('grenade throw never silently rejects legal LAN 288px drag and has ballistic launch',t=>{
 const {game,player}=room(t);
 player.gren=3;
 game.action(player.id,{type:'grenade',x:(player.x+288)/960,y:player.y/540});
 assert.equal(player.gren,2);assert.equal(game.grenades.length,1);
 const g=game.grenades[0];
 closeEnough(g.tx,player.x+288,.01);closeEnough(g.sx,player.x+18,.01);
 closeEnough(g.sy,player.y-9,.01);assert.ok(g.travel>.6&&g.travel<.83);
 closeEnough(g.fuse-g.travel,.42,.001);
 game.tick(1/60);assert.ok(g.elapsed>0);
});
test('wall and turret placements use same LAN min/max and spacing; rejects send feedback',t=>{
 const {game,player,events}=room(t);
 game.action(player.id,{type:'wall',x:(480+100)/960,y:370/540});
 assert.equal(game.walls.length,1);assert.equal(player.wall,1);
 player.wallCd=0;
 game.action(player.id,{type:'wall',x:(480+112)/960,y:370/540});
 assert.equal(game.walls.length,1);assert.match(events.at(-1).message,/INVALID WALL/);
 player.turret=1;
 game.action(player.id,{type:'turret',x:(480+190)/960,y:370/540,face:-1});
 assert.equal(game.turrets.length,1);assert.equal(game.turrets[0].hp,180);
 assert.equal(game.turrets[0].face,-1);
});
test('turret projectiles originate at rotated PNG barrel for BOTH facing directions',t=>{
 const {game}=room(t);
 for(const facing of [-1,1]){
   game.turrets=[{id:65+facing,x:480,y:370,hp:180,face:facing,angle:0,cd:0,flash:0}];
   const turret=game.turrets[0];
   game.zombies=[{id:84,kind:0,x:480+facing*110,y:363,hp:3,maxHp:3,
     face:-facing,attackT:0,attackType:0,hitT:0,cd:2,walking:false}];
   game.effects=[];
   const desired=G.turretAngle(turret,{x:game.zombies[0].x,y:game.zombies[0].y-11});
   assert.ok(Math.abs(desired)<.4);
   // start aligned, avoiding a false mismatch from the 3.8rad/s turn speed.
   turret.angle=desired;
   game.tick(1/60);
   const shot=game.effects.find(f=>f.kind===13);
   assert.ok(shot,`missing ${facing<0?'left':'right'} shot`);
   const barrel=G.turretMuzzle(turret);
   closeEnough(shot.x,barrel.x,.01);closeEnough(shot.y,barrel.y,.01);
   assert.ok(Math.hypot(shot.x-turret.x,shot.y-turret.y)>35,'bullet cannot originate inside turret body');
   assert.ok((shot.x-turret.x)*facing>30,'projectile originates in turret forward hemisphere');
 }
});
test('effect ages use full epoch millis rather than truncated uint32 clock; old effects excluded',t=>{
 const {game}=room(t);
 game.zombies=[];game.effects=[];
 const now=Date.now();
 game.fx(13,{x:515,y:359},{x:600,y:340},.17);
 game.effects[0].born=now-115;
 const payload=encode(game,now>>>0);
 // header + one 30-byte survivor + five intervening list counters = effect count at byte 67
 const effectCountOffset=31+1+30+5;
 assert.equal(payload[effectCountOffset],1);
 const ageOffset=effectCountOffset+1+14;
 assert.ok(payload.readUInt16LE(ageOffset)>=90,'effect age should retain 115ms server history');
 game.effects[0].born=now-1000;
 const newPayload=encode(game,now>>>0);
 assert.equal(newPayload[effectCountOffset],0,'expired effects must not be replayed');
});
test('boss telegraph is transmitted before authoritative melee damage',t=>{
 const {game,player}=room(t);
 player.x=480;player.y=370;player.hp=100;
 game.zombies=[{id:77,kind:4,x:520,y:370,hp:100,maxHp:100,face:-1,attackT:0,hitT:0,cd:0,attackType:0,walking:false}];
 game.tickN=-1;game.tick(1/60);
 const z=game.zombies[0];assert.ok(z.attacking);assert.ok(z.attackT>.80);
 assert.equal(player.hp,100,'boss cannot deal instant damage before slash frame');
 // Telegraphed hit happens after 57% of the 0.82s slash animation.
 for(let i=0;i<34;i++)game.tick(1/60);
 assert.ok(player.hp<100,'boss damages after timed impact');
 assert.ok(z.attackT>0,'attack flags remain visible over multiple network snapshots');
});
test('weapon tracer effect types align with LAN rather than generic projectiles',t=>{
 const {game,player}=room(t);
 player.w1=3;player.slot=1;player.m1=2;player.r1=135;
 game.action(player.id,{type:'fire'});
 assert.ok(game.effects.some(f=>f.kind===13),'Rifle should emit effect 13');
 const shot=game.effects.find(f=>f.kind===13);
 closeEnough(shot.y,player.y+7,.01);
 player.fireCd=0;player.w1=2;player.m1=2;
 game.effects=[];game.action(player.id,{type:'fire'});
 assert.equal(game.effects.filter(f=>f.kind===10).length,5,'shotgun pellets fan across 5 lanes');
});
test('LAN ammo cache leaves incompatible drop; tops magazine after reserve cap',t=>{
 const {game,player}=room(t);
 const ammo={id:44,kind:'ammo',weapon:3,x:player.x,y:player.y};
 assert.equal(game.collect(player,ammo),false,'wrong weapon does not consume ammo');
 player.w1=3;player.m1=12;player.r1=225;
 assert.equal(game.collect(player,ammo),true);
 assert.equal(player.r1,225);
 assert.ok(player.m1>12,'spare ammo with full reserve feeds magazine');
});
test('reserved weapon replacement can only be claimed by nearby owner, cancel releases crate',t=>{
 const {game,player}=room(t);
 player.w1=1;player.w2=2;
 const d={id:91,kind:'weapon',weapon:3,x:player.x,y:player.y};
 game.drops.push(d);
 assert.equal(game.collect(player,d),false);
 assert.equal(d.reservedBy,player.id);
 player.x+=200;
 game.action(player.id,{type:'replace',slot:1});
 assert.equal(player.w1,1,'remote replacement denied');
 assert.equal(d.reservedBy,undefined);
 player.x=d.x;player.replacePending=false;
 assert.equal(game.collect(player,d),false);
 game.action(player.id,{type:'cancel_replace'});
 assert.equal(d.reservedBy,undefined);
 assert.equal(player.replacePending,false);
 assert.equal(player.ignoreDrop,d.id);
});
test('supply drop landing broadcasts its dust cue, prevents >2 concurrent drops',t=>{
 const {game,events}=room(t);
 game.drops=[];assert.equal(game.spawnDrop(),true);assert.equal(game.spawnDrop(),true);
 assert.equal(game.spawnDrop(),false);
 const d=game.drops[0];d.fall=0.05;game.tick(.1);
 assert.equal(d.landed,true);
 assert.ok(game.effects.some(f=>f.kind===8),'landing dust effect matches LAN');
 assert.ok(events.some(x=>x.type==='sfx'&&x.clip==='airdrop'));
});
