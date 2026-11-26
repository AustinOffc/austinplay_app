# Auzify Flutter — Panduan Build dari HP

Status: **Tahap 1 (fondasi)**. Lihat `CHECKLIST.md` untuk fitur yang sudah/belum ada.

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
