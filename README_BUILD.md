# Auzify Flutter — Panduan Build dari HP

Status: **Tahap 5 (rilis: hapus akun, moderasi UGC, dokumen store, patch backend)**. Lihat `CHECKLIST.md` untuk fitur yang sudah/belum ada.

## 1. Taruh di GitHub
1. Buat repo privat baru di GitHub (app GitHub / browser HP).
2. Upload seluruh isi folder ini (termasuk `.github/workflows/build.yml`).

## 2. Isi Base URL backend
Repo → **Settings → Secrets and variables → Actions → tab Variables → New repository variable**
- Name: `API_BASE`  Value: `https://domain-auzify-kamu` (tanpa `/` di akhir, wajib HTTPS)

## 3. Font (opsional tapi disarankan)
Unduh Plus Jakarta Sans (Medium, SemiBold, Bold, ExtraBold `.ttf`), taruh di `assets/fonts/`,
lalu hapus tanda `#` pada blok `fonts:` di `pubspec.yaml`. Tanpa ini app memakai font bawaan Android.

## 4. Build APK debug (tes cepat)
Tab **Actions → Build Auzify → Run workflow**. Setelah hijau, unduh artifact **auzify-debug-apk** dan pasang di HP.

## 5. Keystore untuk Play Store (sekali saja)
Di HP, pakai **Termux**:
```
pkg install openjdk-17
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload-keystore.jks > keystore.b64
```
**Simpan `upload-keystore.jks` + passwordnya di tempat aman (cadangkan!).** Kehilangan keystore = repot ganti kunci.
Lalu di **Settings → Secrets and variables → Actions → Secrets** buat:
`KEYSTORE_BASE64` (isi `keystore.b64`), `KEYSTORE_PASSWORD`, `KEY_ALIAS` (`upload`), `KEY_PASSWORD`.
Jalankan workflow lagi → artifact **auzify-release-aab** muncul (itu file untuk Play Console).

## 6. Upload ke Play Console
Buat app → Internal testing → upload `.aab` → aktifkan Play App Signing. Akun developer pribadi baru
biasanya wajib closed test dengan sejumlah penguji ≥ 14 hari sebelum produksi (cek syarat terbaru di Play Console).

## Catatan versi (terkunci)
Flutter 3.35.7 · Java 17 · AGP 8.9.1 · Gradle 8.12 · Kotlin 2.1.0 · compileSdk/targetSdk 36 · minSdk 24.
Google Play mewajibkan targetSdk 36 untuk app baru sejak 31 Agu 2026. Versi app: `1.0.0+1`
(angka sebelum `+` = versionName, setelah `+` = versionCode yang harus naik tiap upload).

## Tahap 5: yang baru
- **Patch backend** wajib dipasang sebelum rilis (hapus akun, lapor/blokir, halaman /privacy /terms /hapus-akun, assetlinks): lihat `backend_patch/README.md`.
- **Dokumen Play Store**: folder `store/` (mulai dari `RELEASE_GUIDE.md`).
- **Ikon & splash native** sudah ada di `android/app/src/main/res` (tanpa paket tambahan).
- **versionCode** AAB release otomatis = nomor run GitHub Actions (`--build-number`). Naikkan `version:` di `pubspec.yaml` (mis. `1.0.1+1`) untuk versionName baru; ubah juga `AppConfig.appVersion`.
- Artifact baru `auzify-r8-mapping` (mapping R8) — simpan untuk membaca crash.
- Ganti `applicationId` hanya SEKARANG (sebelum rilis): `android/app/build.gradle.kts`, `MainActivity.kt` (package + folder), `AndroidManifest.xml` (channel id di `main.dart`), `assetlinks`.

## Tahap 6: fitur pemutar
Antrean, timer tidur, equalizer, SponsorBlock (lihat `CHECKLIST.md`). Tidak butuh patch backend baru (memakai `/api/sponsorblock` yang sudah ada). Paket baru: tidak ada.

## Tahap 7: Beranda
Chart, Radio, Top Hits (lihat `CHECKLIST.md`). Tidak ada perubahan backend dan tidak ada paket baru.

## Tahap 8: lirik
Tombol Aa (sorot per kata, geser waktu, romanisasi, bagikan gambar). Tidak ada perubahan backend dan tidak ada paket baru.

## Tahap 9: sisa fitur
Ganti cover playlist, Simpan album/playlist sebagai playlist baru, cache lirik offline, jeda/lanjut unduhan (lihat `CHECKLIST.md`). Tidak ada perubahan backend dan tidak ada paket baru. Tes baru: `test/lyrics_cache_test.dart`.
