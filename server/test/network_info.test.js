"use strict";
const test=require('node:test');
const assert=require('node:assert/strict');
const {getAccessInfo,formatStartupUrls,declaredPublicUrl,collectAddresses}=require('../network_info');
const sample={lo:[{address:'127.0.0.1',family:'IPv4',internal:true}],wlan0:[{address:'192.168.1.17',family:'IPv4',internal:false}],eth0:[{address:'172.18.0.2',family:'IPv4',internal:false}]};

test('Termux displays localhost and phone LAN IP without claiming a public IP',()=>{
 const info=getAccessInfo({port:2186,interfaces:sample,env:{}});
 assert.equal(info.local,'http://127.0.0.1:2186');
 assert.equal(info.publicUrl,null);
 assert.match(formatStartupUrls(info),/http:\/\/192\.168\.1\.17:2186/);
 assert.match(formatStartupUrls(info),/atur PUBLIC_URL/);
 assert.doesNotMatch(formatStartupUrls(info),/http:\/\/0\.0\.0\.0/);
});
test('Pterodactyl allocation SERVER_IP and SERVER_PORT generate a copyable URL',()=>{
 const info=getAccessInfo({port:2186,interfaces:sample,env:{SERVER_IP:'202.155.143.139',SERVER_PORT:'2186'}});
 assert.equal(info.publicUrl.url,'http://202.155.143.139:2186');
 assert.match(formatStartupUrls(info),/URL publik\/hosting/);
});
test('PUBLIC_URL supports https proxy and overrides server IP; invalid URL is ignored',()=>{
 const info=getAccessInfo({port:2186,interfaces:{},env:{PUBLIC_URL:'https://game.example.org/',SERVER_IP:'192.168.1.1'}});
 assert.equal(info.publicUrl.url,'https://game.example.org');
 const invalid=declaredPublicUrl({PUBLIC_URL:'https://game.example.org/secret',SERVER_IP:'0.0.0.0'},2186);
 assert.equal(invalid,null);
});
test('localhost bind does not advertise LAN; no duplicate IP addresses',()=>{
 const info=getAccessInfo({port:2186,bind:'127.0.0.1',env:{},interfaces:sample});
 assert.equal(info.lan.length,0);
 assert.deepEqual(collectAddresses({wlan0:[sample.wlan0[0],sample.wlan0[0]]}).map(x=>x.address),['192.168.1.17']);
});
