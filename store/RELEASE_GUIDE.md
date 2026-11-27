# Panduan Rilis ke Play Store

1. **Backend dulu**: pasang `backend_patch/` (lihat README-nya) dan set env `CONTACT_EMAIL`. Cek `https://<domain>/privacy`, `/terms`, `/hapus-akun` terbuka.
2. **Build AAB**: ikuti `README_BUILD.md` (keystore → GitHub Secrets → Actions). Setiap run CI memakai `--build-number=<nomor run>` sehingga versionCode otomatis naik.
3. **Play Console → Buat app**: nama Auzify, bahasa utama Indonesia, App/Gratis. Isi: Kebijakan Privasi (URL `/privacy`), Akses app (akun demo, lihat `REVIEWER_NOTES.md`), Iklan: Tidak, Rating konten (`CONTENT_RATING.md`), Data safety (`DATA_SAFETY.md`), Audiens target: 13+/dewasa, **Hapus akun**: URL `/hapus-akun`, Kategori + listing (`STORE_LISTING.md`).
4. **Play App Signing**: aktifkan saat upload pertama (kunci upload = keystore kamu).
5. **Internal testing**: upload `app-release.aab`, tambahkan emailmu, pasang lewat tautan opt-in. Uji login, putar, background, notifikasi, unduh, chat, room, hapus akun.
6. **assetlinks**: Play Console → Integritas app → salin **SHA-256 sertifikat penandatanganan app** → set di server `ANDROID_SHA256_CERTS=AA:BB:...` (boleh beberapa, pisah koma; tambahkan juga SHA-256 keystore upload bila menguji APK sideload) → restart server → buka `https://<domain>/.well-known/assetlinks.json` untuk memastikan.
7. **Closed testing**: akun developer pribadi baru umumnya wajib closed test dengan sejumlah penguji (terakhir yang saya tahu 12 orang) minimal 14 hari berturut-turut sebelum bisa mengajukan produksi. **Cek syarat terkini di Play Console**; angka ini belum diverifikasi ulang.
8. **Produksi**: ajukan akses produksi setelah syarat terpenuhi, lalu kirim untuk ditinjau.
9. **targetSdk**: app memakai 36. Periksa persyaratan target API terbaru di Play Console saat rilis (belum diverifikasi ulang di sesi ini).
