'use strict';
/** Local .env support with no npm dependencies; never executes config as shell code. */
const fs = require('node:fs');
const path = require('node:path');

function parseEnv(source) {
  const values = {};
  const lines = source.replace(/^\uFEFF/, '').split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line || line.startsWith('#')) continue;
    const match = /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
    if (!match) throw new Error(`Invalid .env line ${i + 1} (expected KEY=value)`);
    let value = match[2].trim();
    if (value.startsWith('"') || value.startsWith("'")) {
      const quote = value[0];
      const end = value.indexOf(quote, 1);
      if (end < 0 || (value.slice(end + 1).trim() && !value.slice(end + 1).trim().startsWith('#')))
        throw new Error(`Invalid quoted .env value on line ${i + 1}`);
      value = value.slice(1, end);
      if (quote === '"') value = value.replace(/\\n/g, '\n').replace(/\\r/g, '\r');
    } else {
      value = value.replace(/\s+#.*$/, '').trim();
    }
    values[match[1]] = value;
  }
  return values;
}

function loadEnvFile(filename = path.join(__dirname, '.env'), target = process.env) {
  let source;
  try { source = fs.readFileSync(filename, 'utf8'); }
  catch (error) {
    if (error.code === 'ENOENT') return {found:false,loaded:[],skipped:[]};
    throw error;
  }
  const vars = parseEnv(source);
  const loaded = [], skipped = [];
  for (const [key,value] of Object.entries(vars)) {
    // Pterodactyl / other environment variables always override .env.
    if (Object.prototype.hasOwnProperty.call(target, key)) skipped.push(key);
    else { target[key] = value; loaded.push(key); }
  }
  return {found:true,loaded,skipped};
}

function resolveServerConfig(env = process.env) {
  // The hosting panel controls its allocated port, even if .env specifies API_PORT.
  const portSource = ['SERVER_PORT','API_PORT','PORT'].find(key => String(env[key] ?? '').trim());
  if (!portSource) throw new Error('Server port missing: set API_PORT in .env or SERVER_PORT in the hosting panel');
  const raw = String(env[portSource]).trim();
  const port = /^\d{1,5}$/.test(raw) ? Number(raw) : NaN;
  if (!Number.isInteger(port) || port < 1 || port > 65535)
    throw new Error(`Invalid ${portSource} (use a TCP port between 1 and 65535)`);
  const bind = String(env.API_BIND || '0.0.0.0').trim();
  if (!bind || /\s/.test(bind)) throw new Error('Invalid API_BIND');
  return {port, bind, portSource};
}

module.exports = {parseEnv,loadEnvFile,resolveServerConfig};
