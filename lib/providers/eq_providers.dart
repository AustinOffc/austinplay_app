import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'library_providers.dart';
import 'music_providers.dart';

class EqBand {
  const EqBand(this.centerHz, this.gain);
  final double centerHz;
  final double gain;
}

class EqState {
  const EqState({
    this.ready = false,
    this.enabled = false,
    this.minDb = -10,
    this.maxDb = 10,
    this.bands = const [],
  });

  /// false = parameter equalizer belum tersedia (belum ada lagu yang dimuat / perangkat tidak mendukung).
  final bool ready;
  final bool enabled;
  final double minDb;
  final double maxDb;
  final List<EqBand> bands;
}

/// Preset berbentuk kurva relatif (−1..1 dari rentang dB), diinterpolasi ke jumlah band perangkat.
const Map<String, List<double>> eqPresets = {
  'Flat': [0, 0, 0, 0, 0],
  'Bass': [0.8, 0.5, 0, -0.1, 0],
  'Vokal': [-0.3, 0, 0.5, 0.4, -0.1],
  'Treble': [0, -0.1, 0, 0.5, 0.8],
};

/// Equalizer Android (just_audio AndroidEqualizer). Disimpan lokal di 'auz_eq' (tidak disinkronkan).
class EqController extends Notifier<EqState> {
  AndroidEqualizer get _eq => ref.read(audioHandlerProvider).equalizer;
  bool _loaded = false;

  @override
  EqState build() {
    unawaited(_load());
    return const EqState();
  }

  Map<String, dynamic> _saved() {
    final raw = ref.read(localStoreProvider).get('auz_eq');
    if (raw == null || raw.isEmpty) return {};
    try {
      final v = jsonDecode(raw);
      return v is Map ? Map<String, dynamic>.from(v) : {};
    } catch (_) {
      return {};
    }
  }

  /// Menunggu parameter tersedia (setelah pemutar pertama memuat audio), lalu menerapkan pengaturan tersimpan.
  Future<void> _load() async {
    if (_loaded) return;
    try {
      final p = await _eq.parameters;
      if (_loaded) return;
      _loaded = true;
      final saved = _saved();
      final on = saved['on'] == true;
      final g = saved['g'];
      if (g is List && g.length == p.bands.length) {
        for (var i = 0; i < p.bands.length; i++) {
          final v = g[i];
          if (v is num) await p.bands[i].setGain(v.toDouble().clamp(p.minDecibels, p.maxDecibels).toDouble());
        }
      }
      await _eq.setEnabled(on);
      _publish(p, on);
    } catch (_) {
      // perangkat tanpa equalizer: biarkan ready=false
    }
  }

  void _publish(AndroidEqualizerParameters p, bool on) {
    state = EqState(
      ready: true,
      enabled: on,
      minDb: p.minDecibels,
      maxDb: p.maxDecibels,
      bands: [for (final b in p.bands) EqBand(b.centerFrequency, b.gain)],
    );
  }

  Future<void> _save(AndroidEqualizerParameters p, bool on) async {
    await ref.read(localStoreProvider).put(
          'auz_eq',
          jsonEncode({'on': on, 'g': [for (final b in p.bands) double.parse(b.gain.toStringAsFixed(2))]}),
        );
  }

  Future<void> setEnabled(bool on) async {
    final p = await _eq.parameters;
    await _eq.setEnabled(on);
    _publish(p, on);
    await _save(p, on);
  }

  Future<void> setGain(int band, double db) async {
    final p = await _eq.parameters;
    if (band < 0 || band >= p.bands.length) return;
    await p.bands[band].setGain(db.clamp(p.minDecibels, p.maxDecibels).toDouble());
    _publish(p, state.enabled);
    await _save(p, state.enabled);
  }

  Future<void> applyPreset(String name) async {
    final shape = eqPresets[name];
    if (shape == null) return;
    final p = await _eq.parameters;
    final n = p.bands.length;
    final top = p.maxDecibels * 0.7;
    for (var i = 0; i < n; i++) {
      final pos = n == 1 ? 0.0 : i * (shape.length - 1) / (n - 1);
      final lo = pos.floor();
      final hi = pos.ceil();
      final f = shape[lo] + (shape[hi] - shape[lo]) * (pos - lo);
      final db = (f * (f >= 0 ? top : -p.minDecibels * 0.7)).clamp(p.minDecibels, p.maxDecibels).toDouble();
      await p.bands[i].setGain(db);
    }
    final on = name != 'Flat' ? true : state.enabled;
    await _eq.setEnabled(on);
    _publish(p, on);
    await _save(p, on);
  }
}

final eqProvider = NotifierProvider<EqController, EqState>(EqController.new);
