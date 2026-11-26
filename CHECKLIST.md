# Checklist fitur: Web Auzify v3.9.3 vs App Flutter

Legenda: ✅ selesai · ⚠️ sebagian · ❌ belum. **Belum ada satu pun yang dikompilasi/diuji** (tanpa Flutter SDK di lingkungan ini).

| Fitur | Status | Catatan |
|---|---|---|
| Config base URL (`--dart-define=API_BASE`) | ✅ | Tahap 1 |
| Tema Soft Pink Glass (token, latar, GlassCard, tombol, toast) | ⚠️ | Tanpa saturasi blur; font perlu dibundel manual |
| Bottom nav melayang 6 tab + gelembung liquid | ⚠️ | Tap & tekan-lama-geser ada; rail ≥1024dp belum; ikon sementara Material (bukan Lucide) |
| Splash | ⚠️ | Splash Flutter ada; native splash Android belum |
| API client (Bearer, 401, 429, timeout) | ✅ | |
| Login / daftar / keluar / keluar semua perangkat | ⚠️ | Ubah password: service siap, UI belum; foto profil belum |
| Beranda, Cari, Artis, Album | ❌ | Tahap 2 |
| Mesin audio, mini/full player, lirik, prefetch | ❌ | Tahap 2 |
| Koleksi, like, playlist, sync, riwayat, statistik, offline | ❌ | Tahap 3 |
| Room, Chat Global (SSE), Profil lengkap, deep link, share | ❌ | Tahap 4 |
| CI GitHub Actions | ✅ | Belum pernah dijalankan |
| Dokumen `store/`, `backend_patch/` | ❌ | Tahap 5 |

## Risiko yang tersisa
- Versi Flutter 3.35.7 / AGP 8.9.1 / Gradle 8.12 / Kotlin 2.1.0 dipilih dari ingatan, **belum diverifikasi** dengan build nyata.
- `flutter create .` di CI diandalkan untuk melengkapi `gradlew`, ikon, dan style bawaan.
- Risiko kebijakan Play (sumber audio dari YouTube) — dibahas di laporan akhir.
