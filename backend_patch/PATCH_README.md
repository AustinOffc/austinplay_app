# PATCH_README — backend_patch: perubahan kecil & aditif untuk Auzify v3.9.3

Semua perubahan **tidak mengubah kontrak endpoint yang ada** dan klien web tetap jalan.

## File
| File | Status | Isi |
|---|---|---|
| `src/routes/account.routes.js` | BARU | `DELETE /api/auth/account` (butuh password) → hapus user + `ap_user_data` + pesan chat (CASCADE) |
| `src/routes/moderation.routes.js` | BARU | `POST /api/chat/report`, `POST /api/report-user`, `GET/POST /api/block`, `DELETE /api/block/:userId`, `GET /api/chat/reports` (admin). Tabel `ap_reports`, `ap_blocks` dibuat otomatis. Laporan dibuang otomatis setelah 90 hari |
| `src/routes/app.routes.js` | BARU | `/privacy`, `/terms`, `/hapus-akun`, `/.well-known/assetlinks.json`, `GET /api/app/config` |
| `src/legal/*.html` | BARU | Halaman Kebijakan Privasi, Syarat & Aturan Komunitas (ID+EN), Hapus Akun |
| `src/server.js` | UBAH (3 baris) | memasang router di atas — lihat `server.js.diff` |
| `src/routes/together.routes.js` | UBAH (1 baris) | tambah `uid` pada anggota room (untuk lapor/blokir) — lihat `together.routes.js.diff` |

## Pasang
1. Salin isi folder `src/` ke `src/` server (timpa `server.js` dan `together.routes.js` — atau terapkan `.diff`; kalau file server kamu sudah berubah sejak v3.9.3, terapkan diff manual).
2. Env (Pterodactyl → Startup/Variables):
   - `CONTACT_EMAIL` — email kontak yang tampil di halaman legal (**wajib diisi**, default `kontak@example.com`).
   - `ANDROID_SHA256_CERTS` — SHA-256 sertifikat penandatanganan app (pisah koma), untuk App Links.
   - Opsional: `APP_MIN_VERSION`, `APP_LATEST_VERSION`, `APP_NOTICE`, `ANDROID_PACKAGE`.
3. Restart server. Tidak perlu migrasi manual.

## Uji cepat
- `GET /privacy`, `/terms`, `/hapus-akun` → halaman tampil.
- `GET /.well-known/assetlinks.json` → JSON.
- Login dari app → Profil → "Hapus akun" dengan akun uji.
- Chat: tahan pesan orang lain → Laporkan / Blokir; `GET /api/chat/reports` (akun di `CHAT_ADMINS`).

## Catatan
- Kode ini **belum dijalankan terhadap PostgreSQL nyata** (hanya `node --check`). Uji di staging dulu.
- Room & koneksi SSE tetap di memori satu instance (tidak berubah).
- Pesan pengguna yang diblokir disaring di klien (server tetap mengirim semuanya).
