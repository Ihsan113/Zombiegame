'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {once}=require('node:events');
const {createApp}=require('../index');
const {decodeInput,encode}=require('../codec');
const {GameRoom}=require('../game');
async function fixture(t, options={}){
 const app=createApp({maxRooms:options.maxRooms||3,reservationsMs:options.reservationsMs||45000,log:{info(){},error(){}}});
 app.server.listen(0,'127.0.0.1');await once(app.server,'listening');
 const root=`http://127.0.0.1:${app.server.address().port}`;
 t.after(async()=>{await app.close();});
 const req=async(route,body)=>{const res=await fetch(root+route,{method:body===undefined?'GET':'POST',headers:body===undefined?{}:{'content-type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});return {status:res.status,data:await res.json()};};
 return {app,root,req};
}
async function auth(root,code,ticket){
 const ws=new WebSocket(root.replace('http://','ws://')+'/ws');ws.binaryType='arraybuffer';
 await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
 const welcome=new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(Error('WS welcome timeout')),3000);
  function on(e){if(typeof e.data==='string'){const v=JSON.parse(e.data);if(v.type==='welcome'){clearTimeout(timeout);ws.removeEventListener('message',on);resolve(v);}}}
  ws.addEventListener('message',on);});
 ws.send(JSON.stringify({type:'auth',code,ticket}));return {ws,welcome:await welcome};
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
test('health, HTTP room API, single-port WebSocket authentication, ticket replay refused',async t=>{
 const {root,req}=await fixture(t);
 assert.equal((await req('/health')).data.mode,'node-websocket');
 const made=await req('/api/rooms/create',{});assert.equal(made.status,201);assert.match(made.data.code,/^[A-HJ-NP-Z2-9]{6}$/);
 assert.equal(made.data.transport,'websocket');
 assert.equal((await req('/api/rooms/connect',{code:made.data.code,ticket:made.data.ticket})).data.path,'/ws');
 const {ws,welcome}=await auth(root,made.data.code,made.data.ticket);assert.equal(welcome.owner,true);assert.ok(welcome.id>=2);
 t.after(()=>ws.close());
 const repeat=new WebSocket(root.replace('http://','ws://')+'/ws');
 await new Promise((r,j)=>{repeat.addEventListener('open',r,{once:true});repeat.addEventListener('error',j,{once:true});});
 const badClose=new Promise(resolve=>repeat.addEventListener('close',resolve,{once:true}));
 repeat.send(JSON.stringify({type:'auth',code:made.data.code,ticket:made.data.ticket}));
 const closed=await badClose;assert.equal(closed.code,1008);
 assert.equal((await req('/internal/validate',{})).status,404);
});
test('four players join, owner starts, authoritative simulation sends binary snapshots',async t=>{
 const {root,req,app}=await fixture(t);
 const made=(await req('/api/rooms/create',{})).data;
 const players=[await auth(root,made.code,made.ticket)];
 for(let i=0;i<3;i++){const invite=await req('/api/rooms/join',{code:made.code});assert.equal(invite.status,200);
  players.push(await auth(root,made.code,invite.data.ticket));}
 t.after(()=>players.forEach(p=>p.ws.close()));
 assert.equal((await req('/api/rooms/join',{code:made.code})).status,409);
 const game=app.rooms.get(made.code).game;
 assert.equal(game.players.size,4);
 players[1].ws.send(JSON.stringify({type:'start'}));await sleep(40);assert.equal(game.started,false);
 players[0].ws.send(JSON.stringify({type:'start'}));await sleep(80);assert.equal(game.started,true);
 assert.equal((await req('/api/rooms/join',{code:made.code})).status,409);
 const buffer=encode(game,Date.now()>>>0);
 assert.equal(buffer[0],0xb7);assert.ok(buffer.length<=1180);
 assert.equal(buffer.readUInt8(31),4); // player count at offset 31
 assert.ok(game.worldTime>0);
 const player=game.players.get(players[0].welcome.id);const x0=player.x;
 const cmd=Buffer.alloc(9);cmd[0]=1;cmd.writeUInt32LE(1,1);cmd.writeInt8(127,5);cmd.writeInt8(0,6);cmd.writeUInt16LE(300,7);
 players[0].ws.send(cmd);await sleep(50);
 assert.ok(player.x>x0 && player.x-x0<5,'input clamped to 150px/s and 30ms');
 players[0].ws.send(JSON.stringify({type:'fire'}));await sleep(50);
 assert.ok(game.effects.length>0,'server simulates shooting effects');
});
test('input codec rejects malformed commands, expired ticket, and snapshots fit client layout',async t=>{
 const {root,req,app}=await fixture(t,{reservationsMs:30});
 assert.equal(decodeInput(Buffer.from([2,0])),null);
 assert.equal(decodeInput(Buffer.alloc(194)),null);
 const made=(await req('/api/rooms/create',{})).data;await sleep(50);
 assert.equal((await req('/api/rooms/connect',{code:made.code,ticket:made.ticket})).status,403);
 const room=app.rooms.get(made.code).game;
 for(let i=0;i<40;i++)room.zombies.push({id:i+1,kind:i%4,x:300+i*3,y:370,hp:3,maxHp:3,face:1,walking:false,attackT:0,hitT:0});
 assert.ok(encode(room,Date.now()>>>0).length<=1180);
});
test('room sessions are isolated and owner transfers after disconnect',async t=>{
 const {root,req,app}=await fixture(t);
 const a=(await req('/api/rooms/create',{})).data;
 const b=(await req('/api/rooms/create',{})).data;
 const owner=await auth(root,a.code,a.ticket);
 const guestTicket=(await req('/api/rooms/join',{code:a.code})).data;
 const guest=await auth(root,a.code,guestTicket.ticket);
 const other=await auth(root,b.code,b.ticket);
 t.after(()=>[owner,guest,other].forEach(x=>x.ws.close()));
 owner.ws.send(JSON.stringify({type:'start'}));
 await sleep(35);
 assert.equal(app.rooms.get(a.code).game.started,true);
 assert.equal(app.rooms.get(b.code).game.started,false);
 owner.ws.close();
 await sleep(35);
 assert.equal(app.rooms.get(a.code).game.owner,guest.welcome.id);
 guest.ws.send(JSON.stringify({type:'restart'}));
 assert.equal(app.rooms.get(b.code).game.players.size,1);
});
test('expired or incorrect websocket ticket cannot authenticate',async t=>{
 const {root,req}=await fixture(t);
 const room=(await req('/api/rooms/create',{})).data;
 const ws=new WebSocket(root.replace('http://','ws://')+'/ws');
 await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
 const done=new Promise(resolve=>ws.addEventListener('close',resolve,{once:true}));
 ws.send(JSON.stringify({type:'auth',code:room.code,ticket:'0'.repeat(64)}));
 assert.equal((await done).code,1008);
});
