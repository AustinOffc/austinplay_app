# Checklist fitur: Web Auzify v3.9.3 vs App Flutter

Legenda: ✅ selesai · ⚠️ sebagian · ❌ belum. **Belum ada satu pun yang dikompilasi/diuji** (tanpa Flutter SDK di lingkungan ini). Status: **Tahap 1–5 selesai + fitur pemutar/Beranda/lirik (Tahap 6–8) + Tahap 9 (cover playlist, simpan album, lirik offline, jeda/lanjut unduhan)**.

| Fitur | Status | Catatan |
|---|---|---|
| Config base URL (`--dart-define=API_BASE`) | ✅ | Tahap 1 |
| Tema Soft Pink Glass (token, latar, GlassCard, tombol, toast) | ⚠️ | Tanpa saturasi blur; font perlu dibundel manual |
| Bottom nav melayang 6 tab + gelembung liquid | ⚠️ | Tap & tekan-lama-geser ada; **rail vertikal ≥1024dp sudah ada** (`GlassRail`, mini player bergeser ke kanan rail); ikon sementara Material (bukan Lucide) |
| Splash | ✅ | Splash Flutter + native splash Android (resource manual, latar #FFE9F1, Android 12+ juga) |
| API client (Bearer, 401, 429, timeout, put/delete) | ✅ | |
| Login / daftar / keluar / keluar semua perangkat | ✅ | + ubah password, foto profil, **hapus akun** (butuh patch backend) |
| Beranda | ⚠️ | + seksi **Terakhir diputar** (dari riwayat). Animasi nama huruf-per-huruf (masuk rise/flip/pop, goyang 1.5px, keluar; hormati reduce-motion) sudah ada. Chart & Radio: lihat baris di bawah |
| Cari | ⚠️ | Saran ketik, filter tipe, riwayat lokal, tempel link YouTube |
| Halaman Artis & Album | ⚠️ | + tombol **Sukai artis**. Tombol **Simpan sebagai playlist** untuk seluruh album/playlist (maks 15 lagu pertama, ada toast bila terpotong) |
| Mesin audio, notifikasi media, antrean, shuffle/repeat, fallback langsung→proxy→refresh, resume posisi | ⚠️ | Putar **file lokal** bila sudah diunduh; auto-next & kecepatan tersambung ke setelan + sync. Prefetch masih hanya menghangatkan server |
| Mini player + pemutar penuh | ⚠️ | + Like, Simpan ke playlist, Unduh/Hapus unduhan, Kecepatan. Belum: antrean, timer tidur, equalizer, SponsorBlock, Aa lirik (per-kata/geser/romanisasi/bagikan) |
| Koleksi: Playlists | ✅ | Buat, ubah nama, hapus, putar/acak, hapus lagu, maks 15 lagu. **Ganti cover** dari galeri (dipangkas persegi 320px, ≤40 KB, disimpan sebagai data URL seperti web) + tombol "Cover otomatis". Cover kustom dari web juga tampil di app (`CoverImage` kini membaca data URL) |
| Koleksi: Artists & Favorit | ✅ | |
| Koleksi: Offline | ⚠️ | Unduh lagu/playlist via `/api/proxy-audio&dl=`, progres, batal, hapus, ukuran total, unduh ulang otomatis di perangkat baru (Wi-Fi) atau manual. **Cache lirik offline** (lirik disimpan saat lagu diunduh, dipakai bila jaringan gagal, dihapus bersama unduhan). **Jeda/lanjut unduhan** (header `Range`, berkas `.part` disimpan; hanya dalam sesi app, setelah app ditutup unduhan mulai dari awal). Hapus (ikon sampah) membatalkan sepenuhnya |
| Mode offline (banner + buka tab Offline otomatis) | ✅ | |
| Sinkron akun (`/api/sync`) | ✅ | Port algoritma `sync.js`: last-write-wins per key, union saat login pertama, riwayat digabung, debounce, tahan offline, poll 60 dtk, sync saat app dilanjutkan. Menunggu uji dua arah dengan web |
| Riwayat & Statistik | ⚠️ | Riwayat ≥ min(30 dtk, 50% durasi), maks 1000, hapus riwayat. Statistik: rentang, ringkasan, artis/lagu teratas, jam ramai, streak. Bagikan statistik sebagai gambar "Wrapped" (kartu pink, top artis/lagu) ✅; belum diuji di perangkat |
| Chat Global | ⚠️ | Real-time SSE + polling `?after=` saat putus, muat pesan lama saat scroll, kirim, hapus (milik sendiri/admin), salin, jumlah online. **Lapor pesan & blokir pengguna** (pesan pengguna terblokir disembunyikan; butuh patch backend) |
| Room (Listen Together) | ⚠️ | Buat Private/Public, gabung kode, daftar room aktif, anggota + foto, host mengirim state (play/pause/seek/lagu + heartbeat 5 dtk), tamu terkunci (juga dari notifikasi) + "Ikut lagi", kick/blokir/jadikan host/pengaturan/akhiri, SSE reconnect. + lapor/blokir anggota. Belum diuji dengan server nyata |
| Profil lengkap | ✅ | Foto profil, ubah password, hapus akun (app + web), daftar diblokir, tautan Privasi/Syarat, tips baterai, channel WhatsApp, bersihkan cache, disclaimer non-afiliasi |
| Deep link & share | ⚠️ | App Links `/play`, `/artist`, `/album`, `/?together=KODE` (cold & warm start); Bagikan lagu/artis/album/room. `assetlinks.json` disediakan patch backend (isi `ANDROID_SHA256_CERTS`) |
| CI GitHub Actions | ✅ | Belum pernah dijalankan |
| Dokumen `store/` | ✅ | Listing ID/EN, Kebijakan Privasi, Syarat & aturan komunitas, Data Safety, Rating konten, catatan reviewer, panduan rilis, template assetlinks |
| `backend_patch/` | ⚠️ | Hapus akun, lapor/blokir, /privacy /terms /hapus-akun, assetlinks, /api/app/config. Hanya `node --check`, belum diuji dengan PostgreSQL |
| Cek versi/pengumuman (`/api/app/config`) | ✅ | Dialog wajib-update / ajakan update / toast pengumuman; diam bila endpoint tidak ada |
| Antrean (lihat/urut/hapus, Putar berikutnya, Tambah ke antrean) | ✅ | Sheet di pemutar penuh + menu lagu. Belum diuji di perangkat |
| Timer tidur (15/30/45/60 mnt, akhir lagu) | ✅ | Volume dipelankan ±2,5 dtk lalu jeda |
| Equalizer | ✅ | `AndroidEqualizer` (just_audio) + preset; tersimpan lokal. Baru aktif setelah lagu pertama dimuat; perilaku di perangkat belum diuji |
| SponsorBlock | ✅ | Saklar + kategori di Profil (lokal, tidak sinkron); lewati otomatis via `/api/sponsorblock` (format nyata server: `{start,end,category}`, bukan `segment:[..]` seperti di prompt) |
| Beranda: Chart (Indonesia/Global/Viral), Radio, Top Hits | ✅ | Hasil `/api/search` (tanpa backend baru), cache lokal 6 jam. Radio: dari artis terbanyak didengar, dari lagu yang diputar, dan menu lagu "Mulai radio". Belum diuji dengan server nyata |
| Tombol Aa di lirik: sorot per kata, geser waktu per lagu, romanisasi, bagikan lirik sebagai gambar | ✅ | Pengaturan lokal (tidak sinkron), sama seperti web. Sorot per kata = taksiran dari durasi baris. Romanisasi memakai `/api/romanize` (backend sudah ada). Gambar dibuat dari widget (`RepaintBoundary`) lalu dibagikan lewat `share_plus`; belum diuji di perangkat |
| Ikon Lucide | ❌ | Masih ikon Material, semua lewat `lib/core/icons.dart`. Sengaja ditunda: versi `lucide_icons_flutter` belum bisa diverifikasi tanpa `flutter pub get`; ganti setelah CI hijau |

## Risiko yang tersisa
- **Tidak ada satu baris pun yang pernah dikompilasi.** Pemeriksaan statis (skrip: semua import ada, paket terdaftar di pubspec, tanpa import tak terpakai, kurung seimbang) bersih, tetapi itu bukan pengganti `flutter analyze`. Jalankan CI dan kirim lognya bila gagal.
- Versi yang dipilih dari ingatan & belum diverifikasi lewat `flutter pub get`: Flutter 3.35.7, AGP 8.9.1, Gradle 8.12, Kotlin 2.1.0, `just_audio 0.10.5`, `audio_service 0.18.18`, `path_provider 2.1.5`, `connectivity_plus 6.1.4`, `image_picker 1.1.2`, `image 4.5.4`, `share_plus 10.1.4`, `url_launcher 6.3.1`, `flutter_cache_manager 3.4.1`.
- `flutter analyze` memperlakukan *warning* sebagai gagal; kesalahan kecil masih mungkin.
- `flutter create .` di CI melengkapi `gradlew` dsb. dan tidak menimpa file yang sudah ada (termasuk resource ikon/splash buatan Tahap 5).
- R8/minify aktif: aturan proguard ditambah untuk tink/secure storage/ExoPlayer, tetapi belum diuji di build release nyata. Bila AAB release crash saat start, coba `isMinifyEnabled = false` dulu untuk diagnosa.
- File unduhan disimpan `.mp3` walau isi bisa m4a/webm (ExoPlayer mengenali dari isi); belum diuji di perangkat.
- Jeda/lanjut unduhan bergantung pada dukungan `Range` di `/api/proxy-audio` (kata prompt: didukung). Bila server membalas 200 (bukan 206), unduhan otomatis mulai dari awal.
- Patch backend belum dijalankan terhadap PostgreSQL; uji di staging.
- App Links baru terverifikasi setelah `assetlinks.json` berisi SHA-256 dari Play App Signing.
- Syarat Play (closed test, targetSdk) bisa berubah — cek di Play Console.

## RISIKO_KEPATUHAN (Google Play) — baca sebelum rilis
Backend mengambil audio dari YouTube lewat yt-dlp + scraper pihak ketiga, dan app menyediakan unduhan/offline. Itu **berisiko tinggi ditolak atau dihapus dari Google Play** (kebijakan hak kekayaan intelektual; ketentuan layanan YouTube melarang mengunduh/memutar di luar pemutar resmi). Materi store sengaja tidak mengklaim hal palsu, tapi tidak bisa menghilangkan risiko ini. Pilihan realistis, keputusan di tanganmu:
1. Distribusi APK di luar Play Store (website/GitHub Releases) — risiko Play hilang, update manual.
2. Ganti sumber dengan konten berlisensi/embed resmi lewat antarmuka `StreamSource` (`lib/services/music_service.dart`) tanpa menyentuh UI/pemutar; fitur unduh mungkin harus dihapus.
3. Tetap ajukan ke Play dengan risiko penolakan/penangguhan akun developer (akun yang ditangguhkan bisa berdampak pada semua app).
Jawab pertanyaan reviewer dengan jujur; jangan menyembunyikan sumber konten.
