# Pixel Zombie Online v0.6.0 — Pterodactyl Node.js Setup

Paket ini sudah menyertakan perbaikan `index.js` untuk egg Pterodactyl yang menggunakan `ts-node --esm` karena pengecekan `*.js` pada Startup Command bawaan tidak tepat.

## Pemasangan lewat Files

1. Hentikan server dahulu.
2. Di `/home/container`, unggah isi ZIP **backend server** langsung ke folder utama (bukan menyimpan ZIP sebagai file tunggal, dan bukan menaruh semua file di dalam subfolder).
3. Untuk pembaruan dari versi sebelumnya, timpa (overwrite) `index.js`. File `codec.js`, `geometry.js`, `game.js`, `websocket.js`, `config.js`, `network_info.js`, dan `package.json` juga harus tersedia. `geometry.js` baru wajib disertakan pada versi v0.6.4.
4. Tab Startup: biarkan `MAIN_FILE` bernilai `index.js`. Tidak perlu mengubah Startup Command yang dikunci admin.
5. Klik Start. Cek Console, lalu akses `http://IP_HOSTING:PORT/health`. Sesuaikan `IP_HOSTING:PORT` dengan alokasi dari panel.

Server akan mendengarkan pada `API_PORT` jika disetel; jika tidak, memakai `SERVER_PORT` yang biasanya diberikan Pterodactyl; jika tidak ada keduanya, memakai port default 2186. `API_BIND` default `0.0.0.0`.

Jika konsol tetap *Offline*, kirim output konsol lengkap setelah Start. Perbaikan ini sudah diuji dengan Node.js 22 dan `ts-node --esm`, tetapi panel hosting bisa memiliki aturan proses atau firewall tambahan.

### Tes

```sh
node --test
```

Game APK v0.6.0 tetap harus dibuild dari proyek Godot, dan performa permainan jarak jauh perlu diuji dengan perangkat nyata.


## Menampilkan IP pada Console (v0.6.1)

Saat Start, cari blok `PIXEL ZOMBIE ONLINE | NODE.JS + WEBSOCKET`. Di situ tercetak port, `URL HP ini`, IP lokal, dan `URL publik/hosting` jika diketahui. Panel Pterodactyl belum tentu mengirim `SERVER_IP`; jika baris URL publik belum diketahui, lihat tab **Network / Allocation**, lalu atur `PUBLIC_URL` lewat variabel yang tersedia (atau gunakan alamat panel tersebut secara manual). Tidak perlu membuka port UDP.

**Contoh:** bila alokasi milikmu `202.155.143.139:2186`, alamat untuk game adalah `http://202.155.143.139:2186`, tanpa `/health`. Contoh ini bukan IP otomatis semua hosting. Halaman utama `/` sekarang menampilkan JSON dengan `server_url` sesuai alamat yang kamu buka.

## Update v0.6.2: file `.env`

File `.env` sudah tersedia di folder utama backend (`/home/container/.env`), satu folder dengan `index.js`. Edit lewat **Files → .env** bila file tersembunyi ditampilkan; isinya antara lain `API_PORT=2186`, `API_BIND=0.0.0.0`, dan `MAX_ROOMS=12`.

**Penting untuk panel:** kebanyakan egg Pterodactyl menetapkan `SERVER_PORT` berdasarkan alokasi Network. Server **mengutamakan `SERVER_PORT`**, jadi mengganti `API_PORT` di `.env` tidak memindahkan port alokasi panel. Bila ingin port lain, minta alokasi port baru pada hosting. `PUBLIC_URL` dapat diatur untuk menampilkan URL yang bisa disalin pemain, tetapi tidak membuka akses publik secara otomatis.

Untuk pengguna **Termux/nonpanel**, cukup ubah `API_PORT` pada `.env`, simpan, lalu restart server. Tidak perlu mengedit kode. Bila sebelumnya sudah memiliki `.env` pribadi, backup sebelum menimpa saat update ZIP.


### Public IP otomatis (v0.6.3)
Console menampilkan IP **egress** melalui ipify jika akses HTTPS keluar tersedia.
IP itu bisa berbeda dari `SERVER_IP` (port NAT/shared hosting). Untuk input
game, prioritaskan alamat alokasi di panel atau nilai `PUBLIC_URL`.
Set `PUBLIC_IP_LOOKUP=0` di `.env` jika hosting melarang lookup.

## Update game parity v0.6.4

Perbaikan turret/granat/barricade/senjata berada di `game.js`, file baru `geometry.js`, dan `codec.js`. **Upload semua file server dari ZIP terbaru**, bukan `index.js` saja. File `.env` dari hosting yang sudah berfungsi sebaiknya dicadangkan sebelum overwrite. Klien Android juga harus dibuild dari proyek v0.6.4 untuk efek muzzle flash dan feedback online terbaru. Jalankan `npm test` setelah upload.
