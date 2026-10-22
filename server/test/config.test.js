'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');
const net = require('node:net');
const {parseEnv,loadEnvFile,resolveServerConfig} = require('../config');

test('parse comments, quoted values, optional export and empty values',()=>{
 const data=parseEnv('# info\nAPI_PORT = 3210  # comment\nPUBLIC_URL="https://game.example.com:3210"\nexport MAX_ROOMS=4\nEMPTY=\n');
 assert.deepEqual(data,{API_PORT:'3210',PUBLIC_URL:'https://game.example.com:3210',MAX_ROOMS:'4',EMPTY:''});
 assert.throws(()=>parseEnv('broken'),/Invalid .env line 1/);
});
test('environment variables from hosting override .env without executing shell code',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'pixel-env-'));
 try{
  const filename=path.join(dir,'.env');
  fs.writeFileSync(filename,'API_PORT=1234\nSERVER_PORT=9999\nPUBLIC_URL="http://example.com:1234"\n');
  const target={SERVER_PORT:'2186',API_PORT:'7777'};
  const result=loadEnvFile(filename,target);
  assert.equal(result.found,true);
  assert.equal(target.API_PORT,'7777');
  assert.equal(target.SERVER_PORT,'2186');
  assert.equal(target.PUBLIC_URL,'http://example.com:1234');
  assert.deepEqual(resolveServerConfig(target),{port:2186,bind:'0.0.0.0',portSource:'SERVER_PORT'});
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('API_PORT works without panel PORT; port is required and validated',()=>{
 assert.deepEqual(resolveServerConfig({API_PORT:'24001',API_BIND:'127.0.0.1'}),{port:24001,bind:'127.0.0.1',portSource:'API_PORT'});
 assert.equal(resolveServerConfig({PORT:'4567'}).port,4567);
 assert.throws(()=>resolveServerConfig({}),/Server port missing/);
 for(const bad of ['0','65536','not-a-port','2186;rm -rf /'])assert.throws(()=>resolveServerConfig({API_PORT:bad}),/Invalid API_PORT/);
 assert.equal(loadEnvFile('/not-a-real-path/pixel-zombie.env',{}).found,false);
});
async function availablePort(){
 const server=net.createServer();await new Promise((resolve,reject)=>server.once('error',reject).listen(0,'127.0.0.1',resolve));
 const port=server.address().port;await new Promise(resolve=>server.close(resolve));return port;
}
test('node startup reads .env from app directory, even when invoked from another cwd',async t=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'pixel-server-test-'));
 t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));
 const base=path.join(__dirname,'..');
 for(const name of ['index.js','game.js','codec.js','geometry.js','websocket.js','network_info.js','config.js'])
  fs.copyFileSync(path.join(base,name),path.join(dir,name));
 const port=await availablePort();
 fs.writeFileSync(path.join(dir,'.env'),`API_PORT=${port}\nAPI_BIND=127.0.0.1\nMAX_ROOMS=2\n`);
 const env={...process.env};
 for(const k of ['SERVER_PORT','API_PORT','PORT','API_BIND','MAX_ROOMS'])delete env[k];
 const child=spawn(process.execPath,[path.join(dir,'index.js')],{cwd:os.tmpdir(),env,stdio:['ignore','pipe','pipe']});
 let output='';child.stdout.on('data',b=>output+=String(b));child.stderr.on('data',b=>output+=String(b));
 t.after(()=>{if(child.exitCode===null)child.kill('SIGTERM');});
 let ready=false;
 for(let attempt=0;attempt<100;attempt++){
  if(child.exitCode!==null)break;
  await new Promise(resolve=>setTimeout(resolve,30));
  try{const res=await fetch(`http://127.0.0.1:${port}/health`);if(res.ok){const data=await res.json();assert.equal(data.ok,true);ready=true;break;}}catch{}
 }
 assert.equal(ready,true,`Startup failed: ${output}`);
 assert.match(output,/Port source: API_PORT \(\.env loaded/);
 assert.match(output,new RegExp(`:${port}`));
 child.kill('SIGTERM');
});
