'use strict';
const {encode, decodeInput} = require('./codec');
const clamp = (x,a,b) => Math.max(a,Math.min(b,Number.isFinite(x)?x:a));
const dist = (a,b) => Math.hypot(a.x-b.x,a.y-b.y);
const roll = (a,b) => Math.random()*(b-a)+a;
const laneY = y => clamp(y, 540*0.52 + 22, 540*0.865 - 40);
const weapons = [
  {d:1,r:560,l:25,c:0.28,m:-1,refill:0},
  {d:1,r:450,l:25,c:.11,m:30,refill:1.15},
  {d:1.15,r:245,l:10,c:.72,m:6,refill:1.45},
  {d:1.55,r:535,l:22,c:.135,m:45,refill:1.55},
  {d:7,r:760,l:13,c:.9,m:5,refill:1.85},
  {d:8,r:520,l:28,c:1,m:1,refill:1.75}
];
class GameRoom {
  constructor(code, log = console) {
    this.code=code;this.log=log;this.players=new Map();this.clients=new Map();this.owner=0;
    this.started=false;this.gameOver=false;this.timedOut=false;this.wave=1;this.worldTime=0;
    this.waveLeft=90;this.total=25;this.spawned=0;this.kills=0;this.spawnTimer=.9;this.breakTimer=0;
    this.zombies=[];this.walls=[];this.turrets=[];this.drops=[];this.grenades=[];this.effects=[];
    this.snapSeq=0;this.nextEntity=1;this.nextEffect=1;this.dropTimer=10;this.tickN=0;
    this.lastActive=Date.now();this.lastEmpty=0;this.nextPlayer=2;
    this.timer=null;this.previous=process.hrtime.bigint();this.acc=0;
  }
  add(peer, owner=false) {
    if(this.players.size>=4 || (this.started && !this.gameOver))return null;
    const id=this.nextPlayer++;
    const p={id,x:480+roll(-55,55),y:laneY(378+roll(-18,18)),hp:100,face:1,walking:false,
      med:2,gren:3,wall:2,turret:0,slot:0,w1:-1,m1:0,r1:0,w2:-1,m2:0,r2:0,
      reload:0,reloadSlot:0,replacePending:false,pendingWeapon:0,pendingDrop:0,shootT:0,hurtT:0,
      fireCd:0,healCd:0,grenCd:0,wallCd:0,turretCd:0,ack:0,inputCredit:.22,lastInput:Date.now(),ignoreDrop:0};
    this.players.set(id,p);this.clients.set(id,peer);
    if(owner) this.owner=id;
    this.lastEmpty=0;this.lastActive=Date.now();
    if(!this.timer)this.startLoop();return p;
  }
  remove(id) {
    this.players.delete(id);this.clients.delete(id);this.lastActive=Date.now();
    if(this.owner===id){this.owner=this.players.keys().next().value||0;
      if(this.owner) this.clients.get(this.owner)?.json({type:'owner',owner:true});}
    if(this.players.size===0)this.lastEmpty=Date.now();
    this.broadcastState();
  }
  broadcastState(){for(const [id,sock] of this.clients)sock.json({type:'members',count:this.players.size,owner:id===this.owner,started:this.started});this.snapshot();}
  startLoop(){this.previous=process.hrtime.bigint();this.timer=setInterval(()=>{
    const current=process.hrtime.bigint();const elapsed=Math.min(.12,Number(current-this.previous)/1e9);
    this.previous=current;this.acc+=elapsed;let steps=0;
    while(this.acc >= 1/60 && steps++<5){this.tick(1/60);this.acc-=1/60;}
    if(steps>=5)this.acc=0;
  },16);this.timer.unref?.();}
  close(){if(this.timer)clearInterval(this.timer);this.timer=null;
    for(const sock of this.clients.values())sock.close(1001);this.clients.clear();this.players.clear();}
  handleBinary(id,bytes){const p=this.players.get(id);if(!p)return;
    const cmds=decodeInput(bytes);if(!cmds)return;
    const now=Date.now();const elapsed=clamp((now-p.lastInput)/1000,0,.3);
    p.lastInput=now;p.inputCredit=clamp(p.inputCredit+elapsed*1.03,0,.3);
    for(const c of cmds){
      if(c.seq<=p.ack || c.seq-p.ack>300 || c.dt<=0 || c.dt>.101)continue;
      if(c.dt>p.inputCredit+0.0001)break;
      p.inputCredit-=c.dt;
      const vx=clamp(c.qx/127,-1,1),vy=clamp(c.qy/127,-1,1);
      const mag=Math.max(1,Math.hypot(vx,vy));
      if(p.hp>0 && !this.gameOver && this.started && !p.replacePending){
        p.x=clamp(p.x+vx/mag*150*c.dt,30,930);
        p.y=laneY(p.y+vy/mag*150*c.dt);
        if(Math.abs(vx)>.14)p.face=vx<0?-1:1;
        p.walking=Math.hypot(vx,vy)>.12;
      }else p.walking=false;
      p.ack=c.seq;
    }
  }
  action(id,message){const p=this.players.get(id);if(!p || typeof message!=='object' || !message)return;
    const type=message.type;
    if(type==='start' && id===this.owner && !this.started){this.started=true;this.gameOver=false;
      for(const sock of this.clients.values())sock.json({type:'started'});this.broadcastState();return;}
    if(type==='restart' && id===this.owner && this.gameOver){this.reset();return;}
    if(!this.started||this.gameOver||p.hp<=0)return;
    if(type==='fire')return this.fire(p);
    if(type==='heal'){
      if(p.med>0&&p.hp<100&&p.healCd<=0){p.med--;p.hp=Math.min(100,p.hp+45);p.healCd=.7;this.fx(5,p,p,.35,id);}return;
    }
    if(type==='grenade'){
      if(p.gren<=0||p.grenCd>0)return;
      const x=clamp(Number(message.x),0,1)*960,y=laneY(clamp(Number(message.y),0,1)*540);
      if(Math.hypot(x-p.x,y-p.y)>250)return;
      p.gren--;p.grenCd=.5;this.grenades.push({id:this.nextEntity++,sx:p.x,sy:p.y,tx:x,ty:y,elapsed:0,travel:.46,height:72,fuse:1.02});return;
    }
    if(type==='wall'){
      if(p.wall<=0||p.wallCd>0||this.walls.length>=8)return;
      const x=clamp(Number(message.x),0,1)*960,y=laneY(clamp(Number(message.y),0,1)*540);
      if(Math.hypot(x-p.x,y-p.y)>150 || this.walls.some(w=>Math.abs(w.x-x)<62&&Math.abs(w.y-y)<60))return;
      p.wall--;p.wallCd=.6;this.walls.push({id:this.nextEntity++,x,y,hp:125,maxHp:125});this.fx(7,{x,y},{x,y},.3,id);return;
    }
    if(type==='turret'){
      if(p.turret<=0||p.turretCd>0||this.turrets.length>=4)return;
      const x=clamp(Number(message.x),0,1)*960,y=laneY(clamp(Number(message.y),0,1)*540);
      if(Math.hypot(x-p.x,y-p.y)>150 || this.turrets.some(t=>Math.hypot(t.x-x,t.y-y)<75))return;
      p.turret--;p.turretCd=.6;this.turrets.push({id:this.nextEntity++,x,y,hp:80,face:Number(message.face)<0?-1:1,angle:0,cd:0});return;
    }
    if(type==='weapon'){
      const slot=Number(message.slot);if(slot===0||slot===1||slot===2){p.slot=slot;p.reload=0;}return;
    }
    if(type==='replace'){
      const slot=Number(message.slot);if(!p.replacePending||![1,2].includes(slot))return;
      const wid=p.pendingWeapon;const drop=this.drops.find(d=>d.id===p.pendingDrop);
      if(!drop || wid<1 || wid>5){p.replacePending=false;return;}
      const w=weapons[wid];p[`w${slot}`]=wid;p[`m${slot}`]=w.m;
      p[`r${slot}`]=Math.min(255,w.m*3);p.slot=slot;
      p.replacePending=false;this.drops=this.drops.filter(d=>d!==drop);return;
    }
    if(type==='cancel_replace'){p.replacePending=false;p.ignoreDrop=p.pendingDrop;p.pendingDrop=0;return;}
  }
  activeWeapon(p){return p.slot===0?0:(p[`w${p.slot}`]>0?p[`w${p.slot}`]:0);}
  fire(p){const weapon=this.activeWeapon(p),w=weapons[weapon];if(p.fireCd>0||p.reload>0||p.replacePending)return;
    if(weapon>0){if(p[`m${p.slot}`]<=0){if(p[`r${p.slot}`]>0)p.reload=w.refill;else p.slot=0;return;}
      p[`m${p.slot}`]--;}
    p.fireCd=w.c;p.shootT=.2;
    const muzzle={x:p.x+p.face*17,y:p.y-16};const targets=this.zombies.filter(z=>(z.x-p.x)*p.face>=0&&Math.abs(z.y-p.y)<w.l+8&&Math.abs(z.x-p.x)<=w.r);
    targets.sort((a,b)=>Math.abs(a.x-p.x)-Math.abs(b.x-p.x));
    const target=targets[0];const end=target?{x:target.x,y:target.y-10}:{x:clamp(p.x+p.face*w.r,0,960),y:p.y-12};
    this.fx(w.effect||1,muzzle,end,.18,p.id);
    if(target)this.hitZombie(target,w.d, p.id);
    if(weapon===2){for(const z of targets.slice(1,3))this.hitZombie(z,.75,p.id);}
    if(weapon===5&&target){for(const z of [...this.zombies])if(dist(z,target)<86)this.hitZombie(z,w.d*.75,p.id);this.fx(6,end,end,1.65,p.id);}
    if(weapon>0&&p[`m${p.slot}`]===0 && p[`r${p.slot}`]>0)p.reload=w.refill;
  }
  hitZombie(z,dmg,src=0){if(!this.zombies.includes(z))return;z.hp-=dmg;z.hitT=.15;this.fx(2,z,z,.17,src);
    if(z.hp<=0){this.zombies.splice(this.zombies.indexOf(z),1);this.kills=Math.min(this.total,this.kills+1);this.fx(4,z,z,.3,src);}}
  fx(kind,a,b,life=.18,src=0){const now=Date.now();this.effects.push({id:this.nextEffect++ & 65535,kind,x:a.x,y:a.y,x2:b.x,y2:b.y,ttl:life,life,src,born:now});
    if(this.effects.length>64)this.effects.splice(0,this.effects.length-64);}
  spawn(){let kind=0;let r=Math.random();if(this.wave%10===0 && this.spawned===0)kind=4;
    else if(this.wave>=2&&r<.10)kind=2;else if(r<.31)kind=3;else if(r<.57)kind=1;
    const hp=kind===4?100+Math.floor((this.wave-1)/10)*35:[3,4,7,3.5][kind];
    const left=Math.random()<.5;this.zombies.push({id:this.nextEntity++,kind,x:left?34:926,y:laneY(roll(305,410)),hp,maxHp:hp,
      face:left?1:-1,walking:false,attacking:false,attackT:0,attackType:0,hitT:0,cd:roll(.15,.5)});this.spawned++;}
  spawnDrop(){if(this.drops.length>=4)return;
    const kinds=['grenade','grenade','wall','medkit','weapon','ammo','turret'];const kind=kinds[Math.floor(Math.random()*kinds.length)];
    const x=roll(58,900),y=laneY(roll(325,400));this.drops.push({id:this.nextEntity++,kind,qty:kind==='grenade'?2:1,weapon:Math.ceil(roll(0,5)),
      x,y:540*.52-18,startY:540*.52-18,landY:y,elapsed:0,fall:2.6,despawn:28,landed:false});}
  collect(p,d){switch(d.kind){case 'grenade':p.gren=Math.min(5,p.gren+d.qty);break;
    case 'medkit':p.med=Math.min(9,p.med+1);break;
    case 'wall':p.wall=Math.min(8,p.wall+d.qty);break;
    case 'turret':p.turret=Math.min(4,p.turret+1);break;
    case 'ammo':{for(const sl of [1,2])if(p[`w${sl}`]===d.weapon)p[`r${sl}`]=Math.min(255,p[`r${sl}`]+30);break;}
    case 'weapon':{let slot=p.w1<1?1:p.w2<1?2:0;if(!slot){p.replacePending=true;p.pendingWeapon=d.weapon;p.pendingDrop=d.id;return false;}
      p[`w${slot}`]=d.weapon;p[`m${slot}`]=weapons[d.weapon].m;p[`r${slot}`]=Math.min(255,weapons[d.weapon].m*3);p.slot=slot;break;}}
    this.fx(8,d,d,.3,p.id);return true;}
  tick(dt){this.tickN++;
    for(const p of this.players.values()){
      for(const key of ['shootT','hurtT','fireCd','healCd','grenCd','wallCd','turretCd'])p[key]=Math.max(0,p[key]-dt);
      if(p.reload>0){p.reload=Math.max(0,p.reload-dt);if(p.reload===0&&p.slot>0){const w=weapons[p[`w${p.slot}`]];
        if(w){const amount=Math.min(w.m-p[`m${p.slot}`],p[`r${p.slot}`]);p[`m${p.slot}`]+=amount;p[`r${p.slot}`]-=amount;}}
      }
      if(Date.now()-p.lastInput>350)p.walking=false;
    }
    if(this.started&&!this.gameOver){this.worldTime+=dt;
      if(this.breakTimer>0){this.breakTimer=Math.max(0,this.breakTimer-dt);
        if(this.breakTimer===0){this.wave++;this.total=25+(this.wave-1)*5;this.spawned=0;this.kills=0;
          this.waveLeft=Math.max(48,90-2*(this.wave-1));this.spawnTimer=.9;this.timedOut=false;}}
      else{this.waveLeft=Math.max(0,this.waveLeft-dt);if(this.waveLeft===0)this.timedOut=true;
        this.spawnTimer-=dt;if(this.spawnTimer<=0&&this.spawned<this.total&&this.zombies.length<Math.min(14,6+this.wave)){
          this.spawn();this.spawnTimer=Math.max(.28,.8-Math.min(14,this.wave)*.025);}}
      for(const z of [...this.zombies]){
        z.attackT=Math.max(0,z.attackT-dt);z.hitT=Math.max(0,z.hitT-dt);z.cd=Math.max(0,z.cd-dt);
        let target=null,best=Infinity,wallTarget=false;
        for(const p of this.players.values())if(p.hp>0&&dist(p,z)<best){best=dist(p,z);target=p;}
        for(const w of this.walls)if(dist(w,z)<Math.min(100,best)){best=dist(w,z);target=w;wallTarget=true;}
        for(const t of this.turrets)if(dist(t,z)<Math.min(100,best)){best=dist(t,z);target=t;wallTarget=true;}
        if(!target){z.walking=false;continue;}
        z.face=target.x>=z.x?1:-1;z.attacking=false;
        const reach=z.kind===4?76:45;
        if(best>reach){const sp=z.kind===3?47:z.kind===4?25:z.kind===2?21:28;
          const ratio=Math.min(1,sp*dt/Math.max(best,.01));z.x+= (target.x-z.x)*ratio;z.y=laneY(z.y+(target.y-z.y)*ratio);z.walking=true;
        }else{z.walking=false;if(z.cd<=0){z.attacking=true;z.attackT=.35;z.cd=z.kind===4?1.2:.9;
          target.hp=Math.max(0,target.hp-(z.kind===4?18:7));if(!wallTarget)target.hurtT=.2;
          if(wallTarget){if(target.hp<=0){this.walls=this.walls.filter(w=>w!==target);this.turrets=this.turrets.filter(t=>t!==target);}}
          this.fx(3,z,target,.2);}}
      }
      for(const t of this.turrets){t.cd=Math.max(0,t.cd-dt);if(t.cd>0)continue;
        const targets=this.zombies.filter(z=>dist(z,t)<270&&(z.x-t.x)*t.face>=-5).sort((a,b)=>dist(a,t)-dist(b,t));
        if(targets.length){const z=targets[0];t.angle=clamp(Math.atan2(z.y-t.y,Math.abs(z.x-t.x)),-Math.PI/2,Math.PI/2);
          this.fx(13,t,z,.18);this.hitZombie(z,1.2);t.cd=.19;}}
      for(const g of [...this.grenades]){g.elapsed+=dt;g.fuse-=dt;
        if(g.fuse<=0){this.grenades.splice(this.grenades.indexOf(g),1);const blast={x:g.tx,y:g.ty};this.fx(6,blast,blast,1.65);
          for(const z of [...this.zombies])if(dist(z,blast)<112)this.hitZombie(z,5);}}
      this.dropTimer-=dt;if(this.dropTimer<=0){this.spawnDrop();this.dropTimer=roll(24,34);}
      for(const p of this.players.values())if(p.ignoreDrop){const ignored=this.drops.find(d=>d.id===p.ignoreDrop);if(!ignored||dist(p,ignored)>62)p.ignoreDrop=0;}
      for(const d of [...this.drops]){d.elapsed+=dt;d.y=d.startY+(d.landY-d.startY)*Math.min(1,d.elapsed/d.fall);
        if(d.elapsed>=d.fall)d.landed=true;
        if(!d.landed)continue;
        d.despawn-=dt;if(d.despawn<=0){this.drops.splice(this.drops.indexOf(d),1);continue;}
        for(const p of this.players.values())if(p.hp>0&&!p.replacePending&&dist(p,d)<42&&p.ignoreDrop!==d.id){
          if(this.collect(p,d))this.drops.splice(this.drops.indexOf(d),1);break;}}
      if(this.spawned>=this.total && this.zombies.length===0 && this.breakTimer<=0)this.breakTimer=8;
      if(this.players.size>0&&[...this.players.values()].every(p=>p.hp<=0)){this.gameOver=true;for(const sock of this.clients.values())sock.json({type:'game_over'});}
    }
    if(this.tickN%2===0)this.snapshot();
    const cutoff=Date.now()-260;this.effects=this.effects.filter(f=>f.born>cutoff);
  }
  snapshot(){if(this.clients.size===0)return;const payload=encode(this,Date.now()>>>0);
    for(const peer of this.clients.values())if(peer.alive && peer.socket.writableLength<32768)peer.binary(payload);
  }
  reset(){this.started=true;this.gameOver=false;this.timedOut=false;this.wave=1;this.worldTime=0;
    this.waveLeft=90;this.total=25;this.spawned=0;this.kills=0;this.spawnTimer=.9;this.breakTimer=0;
    this.zombies=[];this.walls=[];this.turrets=[];this.drops=[];this.grenades=[];this.dropTimer=10;
    for(const p of this.players.values()){p.hp=100;p.med=2;p.gren=3;p.wall=2;p.turret=0;p.w1=-1;p.w2=-1;
      p.slot=0;p.ignoreDrop=0;p.m1=0;p.m2=0;p.r1=0;p.r2=0;p.reload=0;p.replacePending=false;p.x=480+roll(-50,50);p.y=laneY(378);p.ack=0;}
    for(const sock of this.clients.values())sock.json({type:'started'});this.broadcastState();
  }
}
module.exports={GameRoom};
