# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# Tahap 2 (audio): jangan sampai ter-strip
-keep class com.ryanheise.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
# Tahap 5: pustaka pendukung (flutter_secure_storage/tink, Play Core) — cegah R8 gagal karena kelas opsional
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.android.play.core.**
-keep class com.google.crypto.tink.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
