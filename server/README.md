# Node.js-only Pixel Zombie Online room + WebSocket server

No Godot binary, no UDP, no extra npm packages. Requires Node.js 22+.

```bash
cd server
npm test
API_BIND=0.0.0.0 API_PORT=2186 MAX_ROOMS=4 node index.js
```

Test `curl http://127.0.0.1:2186/health`. Expect `{ "ok": true, "mode": "node-websocket", ... }`.

API: POST `/api/rooms/create` (`{}`) -> `code` + single-use `ticket`; POST `/api/rooms/join` (`{"code":"ABC234"}`) -> ticket; POST `/api/rooms/connect` (`{"code":"...","ticket":"..."}`) -> `transport:websocket`, `path:/ws`.

The client connects to `ws://<same-host>:<same-port>/ws` (or `wss://` for HTTPS), sends `{"type":"auth","code":"...","ticket":"..."}`. Server returns `welcome`, `members`, then sends compact 30Hz binary state. Movement is a binary packet containing 1-byte count followed by repeated 8-byte little-endian sequenced commands. Actions are JSON text. Node simulates authoritative movement, combat, zombies, waves, pickups, and buildables at 60 fixed ticks/s.

Each active room has its own `GameRoom` instance in one Node.js process. Defaults: 12 rooms maximum, four players per room, 45-second ticket reservation, 2-minute empty-room cleanup. Tuning: `MAX_ROOMS`, `API_PORT`, `API_BIND`, `GAME_IDLE_MS` (idle override to add if needed). Only TCP port `API_PORT` is required.

Set external firewall to allow TCP 2186 (or chosen port). `API_BIND=0.0.0.0` exposes the service to the network; use TLS/wss, firewall and authentication precautions on public servers. No UDP port, port-forwarding per-room, or GODOT_BIN is needed. Note 60Hz and 30Hz are update targets, not guaranteed latencies. Explicitly untested: real Android APK export and multi-device wide-area performance.


## URL otomatis di terminal (v0.6.1)

Saat startup, terminal menampilkan URL untuk HP itu sendiri (`127.0.0.1`), IP Wi-Fi/LAN yang terdeteksi, dan URL publik/hosting **jika memang diketahui**. Alamat `0.0.0.0` hanya bind address, bukan alamat untuk APK.

**Termux, APK di HP yang sama:** `http://127.0.0.1:2186`. **HP kedua di Wi-Fi yang sama:** gunakan URL `IP lokal` yang tercetak. Pada jaringan seluler / CGNAT, IP publik yang tampak belum tentu bisa menerima koneksi masuk; butuh hosting publik atau tunnel HTTP/WebSocket.

**Pterodactyl:** server membaca `SERVER_PORT` otomatis. Jika panel juga menyediakan `SERVER_IP`, konsol menampilkan URL gabungannya. Bila panel tidak memberinya, set variabel lingkungan opsional `PUBLIC_URL=http://IP-ALOKASI:PORT` atau `PUBLIC_HOST=IP-ALOKASI` (misalnya dengan Startup Variables yang dapat diedit), atau lihat alamat pada tab **Network** di panel. `PUBLIC_URL` juga bisa menggunakan HTTPS bila proxy benar-benar mendukung WebSocket/WSS. Jangan menganggap IP jaringan Docker (`172.x`) sebagai IP publik.

Saat membuka halaman utama `http://IP:PORT/`, backend sekarang mengembalikan `server_url` berdasarkan alamat yang dipakai browser; URL itulah yang bisa disalin ke game. Tes kesehatan di `/health`.

## Konfigurasi dengan `.env` (backend v0.6.2)

Tidak perlu mengubah `index.js` untuk memilih port. File **`.env` sudah ada** di samping `index.js` dan dibaca otomatis, termasuk bila server dimulai dari direktori lain atau memakai Pterodactyl `ts-node --esm`.

```dotenv
API_PORT=2186
API_BIND=0.0.0.0
MAX_ROOMS=12
# PUBLIC_URL=http://IP_HOSTING:PORT
```

- Untuk **Termux**: edit `API_PORT` (misalnya `API_PORT=3000`), simpan `.env`, lalu **restart** `node index.js`. Di APK masukkan `http://127.0.0.1:3000` bila APK dan Termux berada di HP yang sama.
- Untuk **Pterodactyl**: port yang diberikan panel melalui `SERVER_PORT` **selalu menang** atas `API_PORT` dalam `.env`. Jangan memilih port lain kecuali port tersebut sudah menjadi alokasi TCP panel. Ubah `PUBLIC_URL` hanya untuk menampilkan alamat publik di console; itu bukan pengganti pengaturan Network/port.
- Prioritas port: `SERVER_PORT` → `API_PORT` → `PORT`. **Tidak ada port default di `index.js`**; bila semuanya tidak ada, server berhenti dengan pesan untuk mengatur `API_PORT`. Paket ZIP ini sudah membawa `.env` yang berisi contoh port 2186.
- Variabel lingkungan yang diatur oleh panel atau shell **tidak ditimpa** oleh `.env`. `API_BIND`, `MAX_ROOMS`, `PUBLIC_URL`, `PUBLIC_HOST`, dan `PUBLIC_PORT` juga dapat diatur di `.env`.
- File `.env` bisa memuat konfigurasi khusus server; jangan publikasikan ke Git. Proyek utama mengabaikan `server/.env`, tetapi paket ZIP server memang menyertakan contoh `.env` siap edit.
- **Saat upgrade:** backup `.env` milikmu sebelum mengekstrak ZIP dengan opsi overwrite, karena paket baru menyertakan `.env` template. Gunakan `.env.example` sebagai acuan.

Cek: buka `http://HOST:PORT/health` atau `/`. Satu port TCP menangani API HTTP dan WebSocket sekaligus.


## Menampilkan IP publik keluar otomatis (v0.6.3)

Pada setiap startup, server tetap mendengarkan pada port alokasi `SERVER_PORT` dari
Pterodactyl atau `API_PORT` dari `.env`. Tanpa memblokir koneksi pemain, server
meminta **IP publik keluar** ke `https://api.ipify.org?format=json` dengan batas
waktu 3,5 detik. Jika tidak tersedia, server mencoba `ipv4.icanhazip.com`.
Nilai `PUBLIC_IP_LOOKUP=1` mengaktifkan deteksi; `0` menonaktifkannya. Tidak
perlu API key atau paket npm tambahan. Hasilnya tampil di Console.

**Penting:** IP publik yang dikembalikan situs lookup adalah alamat untuk
trafik **keluar**, BUKAN bukti port `2186` atau port lain terbuka untuk pemain.
Pada Pterodactyl, gunakan alamat dari panel (atau `PUBLIC_URL` di `.env`) bila
berbeda. Pada Termux/data seluler, CGNAT dapat menghalangi akses dari luar
meskipun IP publik terdeteksi. Jika ditemukan, server menampilkan contoh URL
`http://IP:PORT` dengan label **BELUM TERVERIFIKASI**, bukan klaim dapat
diakses. Tes akses `/health` dari HP lain/jaringan lain untuk memverifikasi.

Contoh output:

```text
Port API + WebSocket : 2186
URL publik/hosting   : tidak diketahui (atur PUBLIC_URL atau PUBLIC_HOST)
Mendeteksi IP publik keluar melalui api.ipify.org ...
IP publik keluar       : 198.20.30.40 (via ipify)
Perkiraan URL publik   : http://198.20.30.40:2186 [BELUM TERVERIFIKASI]
```

Angka pada contoh di atas bukan alamat server sungguhan.

## v0.6.4 — Gameplay/visual parity with stable LAN

Upload **all files**, including the new required `geometry.js`; preserve your custom `.env` when upgrading. Node authoritative server now mirrors LAN grenade arc/range, barricade/turret placement constraints, turret barrel geometry and aiming, gun FX, boss telegraphs, ammo caches and airdrop dust/audio. Mobile Godot client v0.6.4 is required for matching turret flash and de-duplicated weapon effects. Run `npm test` (including `test/gameplay_parity.test.js`) after upload. Upgrading only the backend is not sufficient for all visual improvements.
