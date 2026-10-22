# Pixel Zombie Online v0.6.4 — Perbaikan gameplay online

Basis: `PixelZombieOnline_v0.6.1_Server_v0.6.3_PublicIP_Auto.zip`; acuan mekanik: `PixelZombieLAN.zip` (mode LAN/offline stabil).

## Perubahan utama

1. Peluru turret kini berasal dari moncong PNG yang berputar, termasuk AIM LEFT dan AIM RIGHT. Efek flash mengikuti event tembakan server, bukan titik badan turret. HP, damage, jarak dan jeda tembak sama dengan acuan LAN.
2. Granat mengikuti jarak preview 62,4–288 px dan durasi terbang/ledak ala LAN. Sebelumnya aksi jarak 250–288 px ditolak server, membuat tombol terasa tidak bekerja.
3. Penempatan tembok/turret memvalidasi jarak minimal/maksimal, celah antarstruktur dan wajah turret seperti LAN; error tampil pada HUD.
4. Tembakan sidearm/SMG/shotgun/rifle/sniper/rocket memakai jenis visual yang sesuai, dengan satu prediksi lokal dan keputusan damage server.
5. Serangan zombie/boss tidak lagi berkedip hanya satu frame; boss memberi waktu wind-up sebelum kerusakan.
6. Airdrop mendarat dengan efek debu dan audio, cache amunisi tidak hilang tanpa gun yang cocok, pilihan ganti senjata dikunci untuk pemain yang mengambilnya.
7. Umur efek di snapshot diperbaiki agar sesuai dengan timeline server dan tidak direplay terus menerus.

## Instalasi

**Hosting:** backup `.env` → Stop → ekstrak ZIP server backend baru ke root (`/home/container/`) dan overwrite JS lama → pastikan file baru `geometry.js` ada → Start → tes `http://IP:PORT/health`. Port tetap berasal dari `.env` atau `SERVER_PORT` Pterodactyl.

**Android:** build APK dari ZIP game lengkap v0.6.4; APK versi sebelumnya tidak mencakup perbaikan visual client. Input URL HTTP/HTTPS yang sama (tanpa `/health` atau `/ws`).

**Uji perangkat:** 2–4 pemain, turun/naik ping, turret kedua arah, granat minimum/maksimum, tembok bertumpuk, pengambilan amunisi dan senjata dari drop, gelombang boss, restart. Mode LAN/solo tetap tersedia.

## Status validasi

Backend: `npm test` mencakup tes HTTP/WebSocket dan regresi gameplay. Pemeriksaan aset dan konfigurasi CI berbasis Python lulus. Belum menjalankan Godot 4.7.2 di lingkungan ini atau menguji dua APK Android pada internet yang berbeda; animasi dan latensi nyata tidak bisa dijamin sampai pengujian perangkat selesai.
