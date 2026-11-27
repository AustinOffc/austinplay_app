import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Indeks tab aktif di shell (0 Beranda, 1 Cari, 2 Koleksi, 3 Room, 4 Chat, 5 Profil).
/// Chat & daftar Room hanya "hidup" saat tab-nya terlihat.
final tabIndexProvider = StateProvider<int>((ref) => 0);

/// Kode room dari tautan undangan (?together=KODE) yang menunggu diproses layar Room.
final pendingJoinProvider = StateProvider<String?>((ref) => null);

/// Tautan yang dibuka saat app masih memuat (splash); diproses setelah splash selesai.
/// Sengaja bukan provider: ditulis dari dalam redirect router yang bisa jalan saat build.
class DeepLinks {
  static String? pending;
}
