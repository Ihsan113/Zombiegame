'use strict';
const {encode, decodeInput} = require('./codec');
const G = require('./geometry');
const clamp = (x,a,b) => Math.max(a,Math.min(b,Number.isFinite(x)?x:a));
const dist = (a,b) => Math.hypot(a.x-b.x,a.y-b.y);
const roll = (a,b) => Math.random()*(b-a)+a;
const laneY = G.laneY;
const weapons = [
  {d:1,r:560,l:25,c:0.28,m:-1,refill:0,effect:1,reserve:0,pack:0},
  {d:1,r:450,l:25,c:.11,m:30,refill:1.15,effect:14,reserve:180,pack:45},
  {d:1.15,r:245,l:10,c:.72,m:6,refill:1.45,effect:10,reserve:36,pack:12},
  {d:1.55,r:535,l:22,c:.135,m:45,refill:1.55,effect:13,reserve:225,pack:60},
  {d:7,r:760,l:13,c:.9,m:5,refill:1.85,effect:11,reserve:30,pack:5},
  {d:8,r:520,l:28,c:1,m:1,refill:1.75,effect:12,reserve:12,pack:2}
];
class GameRoom {
  constructor(code, log = console) {
    this.code=code;this.log=log;this.players=new Map();this.clients=new Map();this.owner=0;
    this.started=false;this.gameOver=false;this.timedOut=false;this.wave=1;this.worldTime=0;
    this.waveLeft=90;this.total=25;this.spawned=0;this.kills=0;this.spawnTimer=.9;this.breakTimer=0;
    this.zombies=[];this.walls=[];this.turrets=[];this.drops=[];this.grenades=[];this.projectiles=[];this.effects=[];
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
    for(const drop of this.drops)if(drop.reservedBy===id)delete drop.reservedBy;
    if(this.owner===id){this.owner=this.players.keys().next().value||0;
      if(this.owner) this.clients.get(this.owner)?.json({type:'owner',owner:true});}
    if(this.players.size===0)this.lastEmpty=Date.now();
    this.broadcastState();
  }
  feedback(id,message){this.clients.get(id)?.json({type:'action_feedback',message});}
  sfx(clip,exceptId=0){for(const [id,peer] of this.clients)if(peer.alive&&id!==exceptId)peer.json({type:'sfx',clip});}
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
      if(p.med>0&&p.hp<100&&p.healCd<=0){p.med--;p.hp=Math.min(100,p.hp+35);p.healCd=.5;this.sfx('heal');}return;
    }
    if(type==='grenade'){
      if(p.gren<=0||p.grenCd>0){if(p.gren<=0)this.feedback(id,'NO GRENADES — collect a supply drop');return;}
      if(!Number.isFinite(message.x)||!Number.isFinite(message.y))return;
      // Stable LAN clamps to the permitted 62.4–288px range; it does NOT
      // reject the last 38px of a valid Android hold/drag throw.
      const throwInfo=G.aimGrenade(p,message.x,message.y);
      p.gren--;p.grenCd=.32;
      this.grenades.push({id:this.nextEntity++,sx:throwInfo.start.x,sy:throwInfo.start.y,
        tx:throwInfo.target.x,ty:throwInfo.target.y,elapsed:0,travel:throwInfo.travel,
        height:throwInfo.height,fuse:throwInfo.travel+.42});
      this.sfx('grenade_throw');return;
    }
    if(type==='wall'){
      if(p.wall<=0||p.wallCd>0||this.walls.length>=8){
        if(p.wall<=0)this.feedback(id,'NO WALL KITS — collect a supply drop');return;}
      if(!Number.isFinite(message.x)||!Number.isFinite(message.y))return;
      const pos=G.fromRatio(message.x,message.y,44);
      if(!G.canPlaceWall(p,pos,this.walls)){this.feedback(id,'INVALID WALL SPOT — move preview 82–139px away');return;}
      p.wall--;p.wallCd=.42;this.walls.push({id:this.nextEntity++,x:pos.x,y:pos.y,hp:125,maxHp:125});
      this.fx(7,pos,pos,.3,id);this.sfx('wall_build');return;
    }
    if(type==='turret'){
      if(p.turret<=0||p.turretCd>0||this.turrets.length>=4){
        if(p.turret<=0)this.feedback(id,'NO TURRET KIT — find an airdrop');return;}
      if(!Number.isFinite(message.x)||!Number.isFinite(message.y))return;
      const pos=G.fromRatio(message.x,message.y,35);
      if(!G.canPlaceTurret(p,pos,this.turrets,this.walls)){this.feedback(id,'INVALID TURRET SPOT — adjust preview and retry');return;}
      p.turret--;p.turretCd=.52;
      const t={id:this.nextEntity++%65535||1,x:pos.x,y:pos.y,hp:180,maxHp:180,
        face:Number(message.face)<0?-1:1,angle:0,cd:.25,flash:0};
      this.turrets.push(t);this.sfx('wall_build');return;
    }
    if(type==='weapon'){
      const slot=Number(message.slot);if(slot===0||slot===1||slot===2){p.slot=slot;p.reload=0;p.reloadSlot=0;}return;
    }
    if(type==='replace'){
      const slot=Number(message.slot);if(!p.replacePending||![1,2].includes(slot))return;
      const wid=p.pendingWeapon;const drop=this.drops.find(d=>d.id===p.pendingDrop);
      if(!drop || drop.reservedBy!==id || wid<1 || wid>5 || dist(p,drop)>96){p.replacePending=false;if(drop&&drop.reservedBy===id)delete drop.reservedBy;return;}
      const w=weapons[wid];p[`w${slot}`]=wid;p[`m${slot}`]=w.m;
      p[`r${slot}`]=[0,90,18,135,10,3][wid];p.slot=slot;
      p.replacePending=false;this.drops=this.drops.filter(d=>d!==drop);return;
    }
    if(type==='cancel_replace'){
      const drop=this.drops.find(d=>d.id===p.pendingDrop);if(drop&&drop.reservedBy===id)delete drop.reservedBy;
      p.replacePending=false;p.ignoreDrop=p.pendingDrop;p.pendingDrop=0;p.pendingWeapon=0;return;}
  }
  activeWeapon(p){return p.slot===0?0:(p[`w${p.slot}`]>0?p[`w${p.slot}`]:0);}
  fire(p){
    const weapon=this.activeWeapon(p),w=weapons[weapon];
    if(p.fireCd>0||p.reload>0||p.replacePending)return;
    if(weapon>0){
      if(p[`m${p.slot}`]<=0){if(p[`r${p.slot}`]>0){p.reload=w.refill;p.reloadSlot=p.slot;}else p.slot=0;return;}
      p[`m${p.slot}`]--;
    }
    p.fireCd=w.c;p.shootT=weapon===0?.19:.14;
    const face=p.face<0?-1:1;
    const muzzle={x:p.x+face*24,y:p.y+7};
    const range=Math.min(w.r,960*.9);
    const targets=this.zombies.filter(z=>(z.x-p.x)*face>16 && (z.x-p.x)*face<=range && Math.abs(z.y-p.y)<=w.l);
    targets.sort((a,b)=>Math.abs(a.x-p.x)-Math.abs(b.x-p.x));
    this.fx(0,muzzle,muzzle,weapon===4?.22:.13,p.id);
    this.sfx('shot',p.id); // Shooter already predicts local gun sound; avoid duplicate audio.
    if(weapon===2){
      const pelletHits=new Map();
      for(const spread of [-13,-6.5,0,6.5,13]){
        const hit=this.zombies.filter(z=>{const proj=(z.x-p.x)*face;
          return proj>16&&proj<=range&&Math.abs(z.y-p.y-spread)<=w.l*.75;})
          .sort((a,b)=>Math.abs(a.x-p.x)-Math.abs(b.x-p.x))[0];
        const len=hit?Math.abs(hit.x-p.x):range;
        this.fx(10,{x:muzzle.x,y:muzzle.y+spread*.35},{x:p.x+face*len,y:p.y-5+spread},.14,p.id);
        if(hit)pelletHits.set(hit,(pelletHits.get(hit)||0)+1);
      }
      for(const [z,hits] of pelletHits)this.hitZombie(z,w.d*hits,p.id);
    }else{
      const target=targets[0];
      const endpoint={x:target?target.x:p.x+face*range,y:p.y+7};
      if(weapon===5){
        const travel=clamp(Math.abs(endpoint.x-p.x)/920,.16,.44);
        this.fx(12,muzzle,endpoint,travel,p.id);
        this.projectiles.push({target:{x:target?target.x:endpoint.x,y:target?target.y:endpoint.y},delay:travel,damage:w.d,radius:86,owner:p.id});
      }else{
        this.fx(w.effect,muzzle,endpoint,weapon===1?.12:weapon===4?.22:.16,p.id);
        if(target){this.fx(3,target,endpoint,.26,p.id);this.hitZombie(target,w.d,p.id);}
      }
    }
    if(weapon>0 && p[`m${p.slot}`]<=0){
      if(p[`r${p.slot}`]>0){p.reload=w.refill;p.reloadSlot=p.slot;}else p.slot=0;
    }
  }
  hitZombie(z,dmg,src=0){if(!this.zombies.includes(z))return;z.hp-=dmg;z.hitT=.15;this.fx(2,z,z,.20,src);
    if(z.hp<=0){this.zombies.splice(this.zombies.indexOf(z),1);this.kills=Math.min(this.total,this.kills+1);this.fx(4,z,z,.32,src);this.sfx('death');}}
  fx(kind,a,b,life=.18,src=0){const now=Date.now();this.effects.push({id:this.nextEffect++ & 65535,kind,x:a.x,y:a.y,x2:b.x,y2:b.y,ttl:life,life,src,born:now});
    if(this.effects.length>64)this.effects.splice(0,this.effects.length-64);}
  spawn(){let kind=0;let r=Math.random();if(this.wave%10===0 && this.spawned===0)kind=4;
    else if(this.wave>=2&&r<.10)kind=2;else if(r<.31)kind=3;else if(r<.57)kind=1;
    const hp=kind===4?100+Math.floor((this.wave-1)/10)*35:[3,4,7,3.5][kind];
    const left=Math.random()<.5;this.zombies.push({id:this.nextEntity++,kind,x:left?34:926,y:laneY(roll(305,410)),hp,maxHp:hp,
      face:left?1:-1,walking:false,attacking:false,attackT:0,attackType:0,hitT:0,cd:roll(.15,.5)});this.spawned++;}
  spawnDrop(){if(this.drops.length>=2)return false;
    const kinds=['grenade','grenade','wall','medkit','weapon','ammo','turret'];const kind=kinds[Math.floor(Math.random()*kinds.length)];
    const x=roll(58,900),y=laneY(roll(325,400));this.drops.push({id:this.nextEntity++,kind,qty:kind==='grenade'?2:1,weapon:Math.ceil(roll(0,5)),
      x,y:540*.52-18,startY:540*.52-18,landY:y,elapsed:0,fall:2.6,despawn:28,landed:false});this.sfx('airdrop_incoming');return true;}
  collect(p,d){switch(d.kind){case 'grenade':p.gren=Math.min(5,p.gren+d.qty);break;
    case 'medkit':p.med=Math.min(5,p.med+1);break;
    case 'wall':p.wall=Math.min(5,p.wall+d.qty);break;
    case 'turret':if(p.turret<2)p.turret++;else p.wall=Math.min(5,p.wall+1);break;
    case 'ammo':{
      const slot=[1,2].find(sl=>p[`w${sl}`]===d.weapon);
      if(!slot)return false;
      const profile=weapons[d.weapon];if(!profile)return false;
      const room=Math.max(0,profile.reserve-p[`r${slot}`]);
      const reserveGain=Math.min(profile.pack,room);
      const magGain=Math.min(profile.pack-reserveGain,Math.max(0,profile.m-p[`m${slot}`]));
      if(reserveGain+magGain<=0)return false;
      p[`r${slot}`]+=reserveGain;p[`m${slot}`]+=magGain;p.slot=slot;
      break;
    }
        case 'weapon':{let slot=p.w1<1?1:p.w2<1?2:0;if(!slot){if(d.reservedBy&&d.reservedBy!==p.id)return false;
        d.reservedBy=p.id;p.replacePending=true;p.pendingWeapon=d.weapon;p.pendingDrop=d.id;return false;}
      p[`w${slot}`]=d.weapon;p[`m${slot}`]=weapons[d.weapon].m;p[`r${slot}`]=[0,90,18,135,10,3][d.weapon];p.slot=slot;break;}}
    this.fx(8,d,d,.3,p.id);this.sfx('pickup');return true;}
  tick(dt){this.tickN++;
    for(const p of this.players.values()){
      for(const key of ['shootT','hurtT','fireCd','healCd','grenCd','wallCd','turretCd'])p[key]=Math.max(0,p[key]-dt);
      if(p.reload>0){p.reload=Math.max(0,p.reload-dt);if(p.reload===0&&p.reloadSlot>0){const slot=p.reloadSlot,w=weapons[p[`w${slot}`]];
        if(w){const amount=Math.min(w.m-p[`m${slot}`],p[`r${slot}`]);p[`m${slot}`]+=amount;p[`r${slot}`]-=amount;}p.reloadSlot=0;}
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
        z.face=target.x>=z.x?1:-1;z.attacking=z.attackT>0;
        const reach=z.kind===4?76:45;
        // Boss visuals must run through their LAN telegraph frames. Applying the
        // hit instantly while the client renders a .82–1.10 s windup looks broken.
        if(z.kind===4 && z.attackT>0){
          z.walking=false;z.attacking=true;
          const durations=[.82,1.10,.88],impact=[.57,.68,.60];
          const progress=1-z.attackT/durations[z.attackType||0];
          if(z.attackType===2 && progress<impact[2] && !wallTarget){
            const gap=G.distance(z,target),step=Math.max(0,Math.min(165*dt,gap-34));
            if(gap>.01){z.x+=step*(target.x-z.x)/gap;z.y=laneY(z.y+step*(target.y-z.y)/gap);}
          }
          if(!z.attackHitApplied && progress>=impact[z.attackType||0]){
            z.attackHitApplied=true;
            const impactAt={x:z.x,y:z.y};
            if(z.attackType===1){
              this.fx(9,{x:z.x,y:z.y+28},{x:z.x,y:z.y+28},.62);
              for(const person of this.players.values())if(person.hp>0 && G.distance(person,impactAt)<=104){
                person.hp=Math.max(0,person.hp-24);person.hurtT=.42;this.fx(2,person,person,.24);}
              if(wallTarget && G.distance(target,z)<104)target.hp=Math.max(0,target.hp-38);
            }else{
              const range=z.attackType===2?62:76;
              if(G.distance(target,z)<=range){
                target.hp=Math.max(0,target.hp-(wallTarget?27:(z.attackType===2?22:18)));
                if(!wallTarget)target.hurtT=.38;
                this.fx(5,z,target,.22);
              }
            }
            this.sfx('boss_attack');
            if(wallTarget&&target.hp<=0){this.walls=this.walls.filter(w=>w!==target);this.turrets=this.turrets.filter(t=>t!==target);this.sfx('wall_break');}
          }
          continue;
        }
        if(best>reach){
          const sp=z.kind===3?35:z.kind===4?15:z.kind===2?19:28;
          const ratio=Math.min(1,sp*dt/Math.max(best,.01));
          z.x+=(target.x-z.x)*ratio;z.y=laneY(z.y+(target.y-z.y)*ratio);z.walking=true;
        }else{
          z.walking=false;
          if(z.cd<=0){
            z.attacking=true;
            if(z.kind===4){
              z.attackType=this.tickN%3;
              z.attackT=[.82,1.10,.88][z.attackType];
              z.cd=[1.34,1.72,1.48][z.attackType];
              z.attackHitApplied=false;this.sfx('boss_roar');
            }else{
              z.attackType=0;z.attackT=.36;z.cd=z.kind===2?.92:z.kind===3?.56:.74;
              target.hp=Math.max(0,target.hp-(z.kind===2?14:z.kind===3?6:8));
              if(!wallTarget)target.hurtT=.20;
              this.fx(5,{x:z.x+z.face*14,y:z.y-3},target,.22);this.sfx('attack');
              if(wallTarget&&target.hp<=0){
                this.walls=this.walls.filter(w=>w!==target);this.turrets=this.turrets.filter(t=>t!==target);this.sfx('wall_break');
              }
            }
          }
        }
      }
      // Mirror LAN turret hemisphere selection, smooth angular tracking and
      // the exact barrel muzzle used by the head PNG in game.gd.
      for(const t of this.turrets){
        t.cd=Math.max(0,t.cd-dt);t.flash=Math.max(0,t.flash-dt);
        const target=this.zombies.filter(z=>G.distance(z,t)<270&&(z.x-t.x)*t.face>=-.5)
          .sort((a,b)=>G.distance(a,t)-G.distance(b,t))[0];
        const desired=target?G.turretAngle(t,{x:target.x,y:target.y-11}):Math.sin(this.worldTime*.63+t.id)*.06;
        t.angle=G.clamp(t.angle+G.clamp(desired-t.angle,-3.8*dt,3.8*dt),-Math.PI/2,Math.PI/2);
        if(target && Math.abs(desired-t.angle)<.22 && t.cd<=0){
          const muzzle=G.turretMuzzle(t),aim={x:target.x,y:target.y-11};
          this.fx(13,muzzle,aim,.17,0);
          this.hitZombie(target,1.35);t.cd=.20;t.flash=.075;this.sfx('turret_fire');
        }
      }
      for(const rocket of [...this.projectiles]){
        rocket.delay-=dt;
        if(rocket.delay>0)continue;
        this.projectiles.splice(this.projectiles.indexOf(rocket),1);
        this.fx(6,rocket.target,rocket.target,1.1);this.sfx('explosion');
        for(const z of [...this.zombies])if(G.distance(z,rocket.target)<rocket.radius){
          const falloff=Math.max(.55,1-.35*G.distance(z,rocket.target)/rocket.radius);
          this.hitZombie(z,rocket.damage*falloff,rocket.owner);
        }
      }
      for(const g of [...this.grenades]){g.elapsed+=dt;g.fuse-=dt;
        if(g.fuse<=0){this.grenades.splice(this.grenades.indexOf(g),1);const blast={x:g.tx,y:g.ty};this.fx(6,blast,blast,1.65);this.sfx('explosion');
          for(const z of [...this.zombies])if(dist(z,blast)<112)this.hitZombie(z,5);}}
      this.dropTimer-=dt;if(this.dropTimer<=0){const spawned=this.spawnDrop();this.dropTimer=spawned?roll(24,34):4;}
      for(const p of this.players.values())if(p.ignoreDrop){const ignored=this.drops.find(d=>d.id===p.ignoreDrop);if(!ignored||dist(p,ignored)>62)p.ignoreDrop=0;}
      for(const d of [...this.drops]){d.elapsed+=dt;d.y=d.startY+(d.landY-d.startY)*Math.min(1,d.elapsed/d.fall);
        if(d.elapsed>=d.fall&&!d.landed){d.landed=true;this.fx(8,{x:d.x,y:d.landY+35},{x:d.x,y:d.landY+35},2.0);this.sfx('airdrop');}
        if(!d.landed)continue;
        if(!d.reservedBy)d.despawn-=dt;if(d.despawn<=0&&!d.reservedBy){
          this.fx(8,{x:d.x,y:d.landY+35},{x:d.x,y:d.landY+35},1.15);
          this.drops.splice(this.drops.indexOf(d),1);continue;}
        for(const p of this.players.values())if(p.hp>0&&!p.replacePending&&dist(p,d)<42&&p.ignoreDrop!==d.id&&(!d.reservedBy||d.reservedBy===p.id)){
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
    this.zombies=[];this.walls=[];this.turrets=[];this.drops=[];this.grenades=[];this.projectiles=[];this.effects=[];this.dropTimer=10;
    for(const p of this.players.values()){p.hp=100;p.med=2;p.gren=3;p.wall=2;p.turret=0;p.w1=-1;p.w2=-1;
      p.slot=0;p.reloadSlot=0;p.ignoreDrop=0;p.m1=0;p.m2=0;p.r1=0;p.r2=0;p.reload=0;p.replacePending=false;p.x=480+roll(-50,50);p.y=laneY(378);p.ack=0;}
    for(const sock of this.clients.values())sock.json({type:'started'});this.broadcastState();
  }
}
module.exports={GameRoom};
