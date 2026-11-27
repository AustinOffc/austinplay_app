# Jawaban Formulir Data Safety (draf — periksa ulang sebelum kirim)

Dasar: perilaku backend v3.9.3 + patch Tahap 5. Kamu yang bertanggung jawab atas kebenaran jawaban akhir.

**Apakah app mengumpulkan/membagikan data pengguna?** Ya (dikumpulkan). Tidak ada iklan, tidak ada SDK analitik/iklan.
**Data dienkripsi saat transit?** Ya (HTTPS). **Pengguna bisa meminta penghapusan?** Ya — di dalam app (Profil → Hapus akun) dan web `https://<domain>/hapus-akun`.

| Kategori Play | Data | Dikumpulkan | Dibagikan | Wajib/Opsional | Tujuan |
|---|---|---|---|---|---|
| Info pribadi → ID pengguna | username (+ hash password) | Ya | Tidak | Wajib bila membuat akun | Fungsi app, manajemen akun |
| Foto & video → Foto | foto profil | Ya | Tidak (tampil ke pengguna lain di app) | Opsional | Fungsi app |
| Pesan → Pesan lain dalam app | pesan Chat Global | Ya | Tidak | Opsional | Fungsi app |
| Aktivitas app → Interaksi dalam app | riwayat putar, suka, playlist, daftar unduhan | Ya | Tidak | Opsional (butuh akun) | Fungsi app, personalisasi |
| Aktivitas app → Histori penelusuran | kata kunci pencarian | Lihat catatan 1 | Lihat catatan 1 | Wajib untuk mencari | Fungsi app |
| Konten pengguna lain | isi laporan moderasi | Ya | Tidak | Opsional | Keamanan |

Catatan 1: kata kunci/judul diteruskan server ke layanan pihak ketiga (sumber lagu/lirik) untuk memenuhi permintaan. Ini bisa dianggap "dibagikan" — pilihan aman: centang **dibagikan** untuk Histori penelusuran dengan tujuan "Fungsi app".
Catatan 2: alamat IP dipakai sementara untuk anti-spam; penyedia jaringan (Cloudflare) bisa mencatatnya. Bila ragu, deklarasikan "Info lokasi → perkiraan lokasi/ID perangkat" sesuai panduan Play atau konsultasikan.
Catatan 3: tidak ada data keuangan, kontak, kesehatan, lokasi presisi, atau mikrofon/kamera. Izin foto hanya lewat pemilih galeri sistem.

**Praktik keamanan:** enkripsi saat transit = Ya; mekanisme hapus data = Ya (URL: `https://<domain>/hapus-akun`); Familiy Policy: tidak ditujukan untuk anak.
