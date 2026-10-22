"use strict";
const test=require('node:test');
const assert=require('node:assert/strict');
const {detectPublicIpv4,formatDetectedPublicIp}=require('../network_info');
const good=(ip)=>({ok:true,json:async()=>({ip}),text:async()=>ip});

test('ipify detects an actual globally routable IPv4',async()=>{
 const seen=[];
 const r=await detectPublicIpv4({fetchImpl:async(url,options)=>{
   seen.push(url);assert.ok(options.signal);return good('8.8.8.8');
 }});
 assert.deepEqual(r,{ip:'8.8.8.8',source:'ipify'});
 assert.match(seen[0],/api\.ipify\.org/);
});
test('invalid/private IP from ipify tries fallback safely',async()=>{
 let calls=0;
 const r=await detectPublicIpv4({fetchImpl:async()=>{
  calls++;if(calls===1)return good('10.0.0.1');return good('1.1.1.1');
 }});
 assert.deepEqual(r,{ip:'1.1.1.1',source:'icanhazip'});
 assert.equal(calls,2);
});
test('network lookup failure does not crash and does not advertise bogus URL',async()=>{
 const r=await detectPublicIpv4({fetchImpl:async()=>{throw new Error('no outbound network');}});
 assert.equal(r,null);
 assert.match(formatDetectedPublicIp(null,{port:2186}),/tidak berhasil dideteksi/);
});
test('console flags guessed URL unverified; respects configured URL',()=>{
 assert.match(formatDetectedPublicIp({ip:'8.8.8.8',source:'ipify'},{port:2186}),/BELUM TERVERIFIKASI/);
 const log=formatDetectedPublicIp({ip:'8.8.8.8',source:'ipify'},{port:2186,publicUrl:{url:'http://9.9.9.9:2186',source:'SERVER_IP'}});
 assert.match(log,/URL game pilihan/);
 assert.match(log,/berbeda/);
 assert.doesNotMatch(log,/Perkiraan URL publik/);
});
