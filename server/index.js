'use strict';
/** Pixel Zombie Online: single TCP port, Node.js-only authoritative rooms. */
const http=require('node:http');
const {randomBytes,createHash}=require('node:crypto');
const {upgrade}=require('./websocket');
const {GameRoom}=require('./game');
const CODE_CHARS='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const codeOk=x=>typeof x==='string'&&/^[A-HJ-NP-Z2-9]{6}$/.test(x);
const hash=x=>createHash('sha256').update(x).digest('hex');
const token=()=>randomBytes(32).toString('hex');
const now=()=>Date.now();
function createApp(config={}){
  const log=config.log??console;
  const maxRooms=config.maxRooms??Number(process.env.MAX_ROOMS||12);
  const reservationsMs=config.reservationsMs??45000;
  const idleMs=config.idleMs??120000;
  if(!Number.isInteger(maxRooms)||maxRooms<1||maxRooms>200)throw Error('Invalid MAX_ROOMS');
  const rooms=new Map(), limits=new Map(), unauth=new Set();
  function available(room){
    for(const [key,t] of room.tickets)if(t.state==='reserved'&&t.expiry<now())room.tickets.delete(key);
    return [...room.tickets.values()].filter(t=>t.state==='active'||t.expiry>=now()).length;
  }
  function invitation(room,owner){const t=token();room.tickets.set(hash(t),{state:'reserved',owner,expiry:now()+reservationsMs,id:0});return t;}
  function roomCode(){for(let n=0;n<100;n++){const bytes=randomBytes(6);const code=[...bytes].map(x=>CODE_CHARS[x%CODE_CHARS.length]).join('');
    if(!rooms.has(code))return code;}throw Error('Too many rooms');}
  function closeRoom(room,reason){if(rooms.get(room.code)!==room)return;rooms.delete(room.code);room.game.close();log.info?.(`Room ${room.code} closed: ${reason}`);}
  function send(res,status,obj){const body=JSON.stringify(obj);res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Content-Length':Buffer.byteLength(body),'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(body);}
  async function read(req){let len=0,blocks=[];for await(const b of req){len+=b.length;if(len>4096)throw Object.assign(Error('Request too large'),{status:413});blocks.push(b);}
    try{return JSON.parse(Buffer.concat(blocks).toString('utf8')||'{}');}catch{throw Object.assign(Error('Invalid JSON'),{status:400});}}
  function limit(req){const ip=req.socket.remoteAddress||'unknown';const val=limits.get(ip);
    if(!val||now()-val.since>60000){limits.set(ip,{since:now(),count:1});return false;}return ++val.count>180;}
  const handler=async(req,res)=>{try{
    if(limit(req))return send(res,429,{error:'Rate limited'});
    if(req.url==='/health'&&req.method==='GET')return send(res,200,{ok:true,mode:'node-websocket',rooms:rooms.size,players:[...rooms.values()].reduce((a,r)=>a+r.game.players.size,0),transport:'websocket',tick_hz:60,snapshot_hz:30});
    if(req.method!=='POST'||!['/api/rooms/create','/api/rooms/join','/api/rooms/connect'].includes(req.url))return send(res,404,{error:'Unknown endpoint'});
    if(!req.headers['content-type']?.startsWith('application/json'))return send(res,415,{error:'Use application/json'});
    const body=await read(req);
    if(req.url==='/api/rooms/create'){
      if(rooms.size>=maxRooms)return send(res,503,{error:'Server room capacity reached'});
      const code=roomCode(),room={code,tickets:new Map(),game:new GameRoom(code,log),created:now()};rooms.set(code,room);
      return send(res,201,{code,ticket:invitation(room,true),owner:true,ready:true,transport:'websocket'});
    }
    const code=String(body.code||'').trim().toUpperCase();if(!codeOk(code))return send(res,400,{error:'Invalid 6-character room code'});
    const room=rooms.get(code);if(!room)return send(res,404,{error:'Room not found'});
    if(req.url==='/api/rooms/join'){
      if(room.game.started)return send(res,409,{error:'Match already started'});
      if(available(room)>=4)return send(res,409,{error:'Room full (4/4)'});
      return send(res,200,{code,ticket:invitation(room,false),owner:false,ready:true,transport:'websocket'});
    }
    const ticket=typeof body.ticket==='string'?body.ticket:'';
    const t=ticket.length===64?room.tickets.get(hash(ticket)):undefined;
    if(!t||t.expiry<now()&&t.state==='reserved')return send(res,403,{error:'Room ticket expired'});
    return send(res,200,{code,ready:true,transport:'websocket',path:'/ws',started:room.game.started});
  }catch(err){log.error?.(err.message);return send(res,err.status||500,{error:err.status?err.message:'Server error'});}};
  const server=http.createServer(handler);
  server.on('upgrade',(req,socket,head)=>{
    if(limit(req)){socket.destroy();return;}
    upgrade(req,socket,head,peer=>{
      unauth.add(peer);let room=null,id=0,authed=false;
      const timeout=setTimeout(()=>{if(!authed)peer.close(1008);},10000);timeout.unref?.();
      peer.on('close',()=>{clearTimeout(timeout);unauth.delete(peer);
        if(room&&id){room.game.remove(id);for(const [h,t] of room.tickets)if(t.state==='active'&&t.id===id)room.tickets.delete(h);}});
      let messageCount=0, messageWindow=now();
      peer.on('message',(buf,binary)=>{
        if(now()-messageWindow>1000){messageWindow=now();messageCount=0;}
        if(++messageCount>180)return peer.close(1008);
        if(!authed){if(binary||buf.length>512)return peer.close(1008);
          let msg;try{msg=JSON.parse(buf.toString('utf8'));}catch{return peer.close(1008);}
          if(msg.type!=='auth'||!codeOk(msg.code)||typeof msg.ticket!=='string'||msg.ticket.length!==64)return peer.close(1008);
          room=rooms.get(msg.code);const t=room?.tickets.get(hash(msg.ticket));
          if(!room||!t||t.state!=='reserved'||t.expiry<now()||room.game.players.size>=4||room.game.started)return peer.close(1008);
          const player=room.game.add(peer,t.owner);
          if(!player)return peer.close(1008);
          t.state='active';t.id=player.id;id=player.id;authed=true;unauth.delete(peer);clearTimeout(timeout);
          peer.json({type:'welcome',id,owner:id===room.game.owner,code:room.code});
          room.game.broadcastState();return;
        }
        if(binary){room.game.handleBinary(id,buf);return;}
        if(buf.length>1024)return peer.close(1009);
        try{const msg=JSON.parse(buf.toString('utf8'));
          if(msg?.type==='ping'){peer.json({type:'pong',seq:msg.seq});return;}
          if(msg&&typeof msg.type==='string')room.game.action(id,msg);
        }catch{/* ignore bad client messages */}
      });
    });
  });
  const housekeeping=setInterval(()=>{
    for(const room of [...rooms.values()]){
      const used=available(room);if(room.game.players.size===0&&used===0&&now()-room.created>idleMs)closeRoom(room,'idle');
      if(room.game.players.size===0&&room.game.lastEmpty&&now()-room.game.lastEmpty>idleMs)closeRoom(room,'empty');
      if(!room.game.owner&&room.game.players.size>0&&!([...room.tickets.values()].some(t=>t.owner&&t.state==='reserved'&&t.expiry>now()))){
        room.game.owner=room.game.players.keys().next().value;room.game.broadcastState();
      }
    }
    for(const [ip,val] of limits)if(now()-val.since>120000)limits.delete(ip);
  },5000);housekeeping.unref();
  return {server,rooms,close:()=>{clearInterval(housekeeping);for(const p of [...unauth])p.close(1001);
    for(const room of [...rooms.values()])closeRoom(room,'shutdown');return new Promise(resolve=>server.close(resolve));}};
}
if(require.main===module){const app=createApp();const port=Number(process.env.API_PORT||8080),bind=process.env.API_BIND||'0.0.0.0';
  app.server.listen(port,bind,()=>console.log(`Pixel Zombie Online Node.js HTTP + WebSocket listening at ${bind}:${port} (TCP only)`));
  const stop=()=>app.close().then(()=>process.exit(0));process.on('SIGINT',stop);process.on('SIGTERM',stop);}
module.exports={createApp};
