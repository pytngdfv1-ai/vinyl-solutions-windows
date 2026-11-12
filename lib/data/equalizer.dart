import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una banda del ecualizador (en Windows las define la app: no hay efectos del sistema).
class EqBand {
  EqBand(this.centerFrequency);

  final double centerFrequency;
  double gain = 0;

  Future<void> setGain(double db) async => gain = db;
}

class EqParams {
  EqParams(this.bands, {this.minDecibels = -12, this.maxDecibels = 12});

  final List<EqBand> bands;
  final double minDecibels;
  final double maxDecibels;
}

/// Ecualizador de 5 bandas (60 Hz, 250 Hz, 1 kHz, 4 kHz, 16 kHz).
/// Windows: se aplica como filtro de audio de mpv (`af`) sobre los reproductores de
/// just_audio_media_kit. Necesita el parche del CI que expone `MediaKitPlayer.player`;
/// sin él [effectActive] queda en falso y solo se guardan los ajustes.
class Eq {
  static bool effectActive = false;

  static final List<dynamic> _targets = [];

  /// Lo llama el hook de la plataforma de audio cada vez que se crea un reproductor.
  static void attach(Object platformPlayer) {
    try {
      final dynamic d = platformPlayer;
      final dynamic native = d.player.platform; // NativePlayer de media_kit
      native.setProperty; // falla (NoSuchMethodError) si no es NativePlayer
      _targets.add(native);
      effectActive = true;
      unawaited(_push());
    } catch (_) {}
  }

  static String _filter() {
    if (!enabled.value) return '';
    final pr = params!;
    final parts = <String>[];
    for (var i = 0; i < pr.bands.length; i++) {
      final g = i < gains.length ? gains[i] : 0.0;
      if (g.abs() < 0.05) continue;
      parts.add('equalizer=f=${pr.bands[i].centerFrequency.round()}:t=o:w=1.5:g=${g.toStringAsFixed(1)}');
    }
    return parts.isEmpty ? '' : 'lavfi=[${parts.join(',')}]';
  }

  static Future<void> _push() async {
    final af = _filter();
    for (final t in List.of(_targets)) {
      try {
        await t.setProperty('af', af);
      } catch (_) {
        _targets.remove(t); // reproductor liberado
      }
    }
  }

  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  /// Ganancias guardadas (dB), una por banda.
  static List<double> gains = [];

  /// Bandas del ecualizador.
  static EqParams? params = EqParams([for (final f in const [60.0, 250.0, 1000.0, 4000.0, 16000.0]) EqBand(f)]);

  static const presets = <String, List<double>>{
    'Plano': [0, 0, 0, 0, 0],
    'Graves': [.8, .5, 0, 0, 0],
    'Agudos': [0, 0, 0, .5, .8],
    'Rock': [.6, .3, -.3, .3, .6],
    'Pop': [-.2, .3, .6, .3, -.2],
    'Vocal': [-.4, 0, .6, .5, -.1],
    'Clásica': [.4, .2, -.2, .2, .5],
    'Loudness': [.8, .2, -.1, .2, .8],
  };

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled.value = p.getBool('eq_on') ?? false;
      gains = (p.getString('eq_gains') ?? '')
          .split(',')
          .map((e) => double.tryParse(e))
          .whereType<double>()
          .toList();
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('eq_on', enabled.value);
      await p.setString('eq_gains', gains.join(','));
    } catch (_) {}
  }

  /// Carga los ajustes guardados en las bandas.
  static Future<bool> apply() async {
    final pr = params!;
    for (var i = 0; i < pr.bands.length; i++) {
      final g = i < gains.length ? gains[i] : 0.0;
      await pr.bands[i].setGain(g.clamp(pr.minDecibels, pr.maxDecibels).toDouble());
    }
    await _push();
    return true;
  }

  static Future<void> setEnabled(bool v) async {
    enabled.value = v;
    await _push();
    await _save();
  }

  static Future<void> setGain(int i, double db) async {
    final pr = params;
    if (pr == null || i >= pr.bands.length) return;
    while (gains.length < pr.bands.length) {
      gains.add(0);
    }
    gains[i] = db;
    await pr.bands[i].setGain(db);
    await _push();
  }

  static Future<void> commit() => _save();

  /// Un preset (5 valores de -1 a 1) se reparte entre las bandas que tenga el dispositivo.
  static Future<void> preset(String name) async {
    final pr = params;
    final f = presets[name];
    if (pr == null || f == null) return;
    final n = pr.bands.length;
    for (var i = 0; i < n; i++) {
      final k = n == 1 ? 0 : (i * (f.length - 1) / (n - 1)).round();
      await setGain(i, (f[k] * pr.maxDecibels).clamp(pr.minDecibels, pr.maxDecibels).toDouble());
    }
    await _save();
  }
}
