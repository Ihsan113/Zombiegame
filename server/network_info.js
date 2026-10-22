"use strict";
// Access URLs are informational only. A public-looking IP does not guarantee reachability.
const os = require('node:os');
const net = require('node:net');

function isPrivateOrSpecialIpv4(ip) {
  if (net.isIP(ip) !== 4) return true;
  const [a,b] = ip.split('.').map(Number);
  return a === 0 || a === 10 || a === 127 || a >= 224 ||
    (a === 100 && b >= 64 && b <= 127) ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && (b === 168 || (b === 0 && Number(ip.split('.')[2]) === 0))) ||
    (a === 198 && (b === 18 || b === 19)) ||
    (a === 198 && b === 51 && Number(ip.split('.')[2]) === 100) ||
    (a === 203 && b === 0 && Number(ip.split('.')[2]) === 113); // documentation ranges
}
function hostUrl(host, port) {
  if (net.isIP(host) === 6) return `http://[${host}]:${port}`;
  if (net.isIP(host) === 4 || (/^[a-z0-9.-]+$/i.test(host) && host !== '.' && !host.includes('..')))
    return `http://${host}:${port}`;
  return null;
}
function declaredPublicUrl(env, port) {
  if (env.PUBLIC_URL) {
    try {
      const url = new URL(env.PUBLIC_URL);
      if ((url.protocol === 'http:' || url.protocol === 'https:') && url.hostname &&
          !url.username && !url.password && (url.pathname === '/' || !url.pathname) &&
          !url.search && !url.hash) return {url:url.origin,source:'PUBLIC_URL'};
    } catch { /* invalid optional environment variable */ }
  }
  const host=(env.PUBLIC_HOST || env.SERVER_IP || '').trim();
  const portValue=Number(env.PUBLIC_PORT || env.SERVER_PORT || port);
  if (host && host !== '0.0.0.0' && host !== '::' &&
      Number.isInteger(portValue) && portValue >= 1 && portValue <= 65535) {
    const url=hostUrl(host, portValue);
    if (url) return {url,source:env.PUBLIC_HOST?'PUBLIC_HOST':'SERVER_IP'};
  }
  return null;
}
function collectAddresses(interfaces) {
  const result=[];
  const seen=new Set();
  for (const [name,addresses] of Object.entries(interfaces || {})) {
    for (const addr of addresses || []) {
      if ((addr.family !== 'IPv4' && addr.family !== 4) || addr.internal ||
          net.isIP(addr.address) !== 4 || addr.address.startsWith('169.254.')) continue;
      if (seen.has(addr.address)) continue;
      seen.add(addr.address);
      result.push({name,address:addr.address,public:!isPrivateOrSpecialIpv4(addr.address)});
    }
  }
  const score=(name)=>/^(wlan|wifi|ap|swlan)/i.test(name)?0:/^(eth|enp|ens)/i.test(name)?1:/^(rmnet|ccmni|pdp)/i.test(name)?2:/^(tun|tailscale)/i.test(name)?3:4;
  return result.sort((a,b)=>score(a.name)-score(b.name)||a.name.localeCompare(b.name));
}
function getAccessInfo({port,bind='0.0.0.0',env=process.env,interfaces=os.networkInterfaces()}={}) {
  const local=`http://127.0.0.1:${port}`;
  const addresses=collectAddresses(interfaces);
  const networkVisible=bind !== '127.0.0.1' && bind !== '::1' && bind !== 'localhost';
  const lan=networkVisible?addresses.filter(x=>!x.public).slice(0,5).map(x=>({interface:x.name,url:hostUrl(x.address,port)})):[];
  const allocated=declaredPublicUrl(env,port);
  const detected=networkVisible?addresses.find(x=>x.public):undefined;
  const publicUrl=allocated || (detected?{url:hostUrl(detected.address,port),source:`interface ${detected.name}`} : null);
  return {local,lan,publicUrl,bind,port};
}
function formatStartupUrls(info) {
  const lines=[
    '',
    '==========================================================',
    ' PIXEL ZOMBIE ONLINE | NODE.JS + WEBSOCKET (TCP)',
    '==========================================================',
    ` Port API + WebSocket : ${info.port}`,
    ` Alamat di HP ini     : ${info.local}`,
  ];
  if(info.lan.length) {
    for(const item of info.lan)lines.push(` IP lokal [${item.interface}] : ${item.url}`);
  } else lines.push(' IP jaringan lokal    : tidak terdeteksi / hanya localhost');
  if (info.publicUrl)lines.push(` URL publik/hosting   : ${info.publicUrl.url} [${info.publicUrl.source}]`);
  else lines.push(' URL publik/hosting   : tidak diketahui (atur PUBLIC_URL atau PUBLIC_HOST)');
  lines.push(` Cek API di HP ini    : ${info.local}/health`,
    ' Masukkan URL DASAR ke game (TANPA /health atau /ws).',
    ' Catatan: IP lokal/container tidak otomatis bisa diakses dari internet.',
    ' URL publik juga perlu port hosting/firewall yang benar.',
    '==========================================================');
  return lines.join('\n');
}

// A server behind Pterodactyl, a proxy, or carrier-grade NAT may have a different
// outward-facing address from its inbound allocation. This lookup is DIAGNOSTIC.
// It never configures the listening socket or declares the port reachable.
async function detectPublicIpv4({fetchImpl=globalThis.fetch,timeoutMs=3500}={}) {
  const endpoints=[
    {url:'https://api.ipify.org?format=json',label:'ipify',json:true},
    {url:'https://ipv4.icanhazip.com',label:'icanhazip',json:false},
  ];
  if (typeof fetchImpl !== 'function') return null;
  for (const endpoint of endpoints) {
    try {
      const response=await fetchImpl(endpoint.url,{
        signal:AbortSignal.timeout(timeoutMs),
        headers:{'Accept':endpoint.json?'application/json':'text/plain'},
      });
      if (!response.ok) continue;
      const candidate=endpoint.json?(await response.json())?.ip:await response.text();
      const ip=typeof candidate==='string'?candidate.trim():'';
      // Do not trust the remote service blindly or print unsafe values into logs.
      if (net.isIP(ip)===4 && !isPrivateOrSpecialIpv4(ip))
        return {ip,source:endpoint.label};
    } catch {/* unavailable provider; try the next provider */}
  }
  return null;
}
function formatDetectedPublicIp(result, {port, publicUrl=null}={}) {
  if (!result) return [
    ' IP publik keluar       : tidak berhasil dideteksi (DNS/jaringan/layanan lookup)',
    ' Gunakan alamat alokasi Pterodactyl atau atur PUBLIC_URL di .env.',
  ].join('\n');
  const lines=[` IP publik keluar       : ${result.ip} (via ${result.source})`];
  if (!publicUrl) {
    lines.push(` Perkiraan URL publik   : http://${result.ip}:${port} [BELUM TERVERIFIKASI]`);
    lines.push(' IP keluar bisa berbeda dari IP koneksi masuk; CGNAT atau firewall dapat memblokir akses.');
  } else {
    lines.push(` URL game pilihan      : ${publicUrl.url} [${publicUrl.source}]`);
    try {
      const configured=new URL(publicUrl.url);
      if (net.isIP(configured.hostname)===4 && configured.hostname!==result.ip)
        lines.push(' INFO: IP keluar berbeda dari alamat server; gunakan URL yang dialokasikan hosting.');
    } catch {/* URL is validated elsewhere */}
  }
  return lines.join('\n');
}

module.exports={isPrivateOrSpecialIpv4,declaredPublicUrl,collectAddresses,getAccessInfo,formatStartupUrls,detectPublicIpv4,formatDetectedPublicIp};
