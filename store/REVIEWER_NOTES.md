# Catatan untuk Reviewer Play Console

**Akun demo** (BUAT DULU di server, jangan pakai akun pribadi):
- Username: `reviewer_auzify` (isi sesuai yang kamu buat)
- Password: `<isi>`

**Cara menguji:** Beranda → ketuk lagu untuk memutar; ketuk ikon lirik di pemutar penuh. Chat & Room butuh login (akun demo di atas). Hapus akun: Profil → Hapus akun (atau `https://<domain>/hapus-akun`).
**Moderasi UGC:** di Chat, tahan pesan orang lain → Laporkan / Blokir. Di Room, ketuk anggota → Laporkan / Blokir. Aturan: `https://<domain>/terms`.
**Layanan latar belakang:** pemutaran musik memakai foreground service tipe mediaPlayback dengan notifikasi media.
**Server:** pastikan backend aktif selama peninjauan; app tidak berfungsi tanpa server.
**Sumber konten:** app memutar audio yang diambil server dari layanan pihak ketiga atas permintaan pengguna. Jawab pertanyaan reviewer tentang sumber konten dengan jujur (lihat RISIKO_KEPATUHAN di CHECKLIST.md).
