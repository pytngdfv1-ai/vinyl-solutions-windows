import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../data/equalizer.dart';
import '../data/koofr_settings.dart';
import '../models/vinyl.dart';
import 'koofr_proxy.dart';

/// Reproductor único. La música sigue sonando aunque se cierre la pantalla
/// del disco (para buscar otro en la biblioteca).
class PlayerService {
  PlayerService._() {
    player.currentIndexStream.listen(_onIndex);
    // Recuerda la duración de cada tema (a veces no se vuelve a informar al cambiar de tema).
    player.durationStream.listen((d) {
      if (d != null && d > Duration.zero) _durations[player.currentIndex ?? 0] = d;
    });
    player.processingStateStream.listen((st) {
      if (st == ProcessingState.completed) _onCompleted();
    });
  }
  static final PlayerService instance = PlayerService._();

  final AudioPlayer player = AudioPlayer();

  /// Disco cargado en el reproductor (null = nada).
  final ValueNotifier<Vinyl?> nowPlaying = ValueNotifier<Vinyl?>(null);

  final Map<int, Duration> _durations = {};

  /// Avance (0..1) del tema actual; si no se conoce la duración, se estima para que el brazo avance.
  double progressAt(Duration pos) {
    var dur = player.duration;
    if (dur == null || dur <= Duration.zero) dur = _durations[player.currentIndex ?? 0];
    final cur = pos.inMilliseconds;
    if (dur == null || dur <= Duration.zero) {
      return (cur / (5 * 60 * 1000)).clamp(0.0, 0.95).toDouble();
    }
    return (cur / dur.inMilliseconds).clamp(0.0, 1.0).toDouble();
  }

  String? _loadedId;
  int _lastIndex = 0;
  bool _changing = false;
  bool _loading = false;

  /// Playlist: los temas se encadenan sin la animación de pausa del brazo.
  bool chain = false;

  /// Se llama antes de cargar un disco (p. ej. para cerrar una sesión de DJ en vivo).
  static Future<void> Function()? beforeStart;

  /// Carga el disco y empieza a sonar. Si ya está cargado, no hace nada.
  Future<void> start(Vinyl v, {int index = 0, bool chain = false}) async {
    if (_loadedId == v.id || _loading) return;
    await beforeStart?.call();
    _loading = true;
    try {
      // La nube a veces falla un instante ("Source error"): se reintenta hasta 3 veces;
      // la última, directo con las credenciales (sin el caché local).
      Object? last;
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          if (!v.trackUrls.first.startsWith('file:')) await _preflight(v.trackUrls.first);
          // Windows: intento 0 y 2 con las credenciales como cabeceras HTTP directas;
          // el intento 1 pasa por un servidor local (127.0.0.1) que añade las credenciales.
          final children = <AudioSource>[];
          for (final url in v.trackUrls) {
            if (url.startsWith('file:')) {
              children.add(AudioSource.uri(Uri.parse(url)));
            } else if (attempt == 1) {
              children.add(AudioSource.uri(await KoofrProxy.instance.wrap(url)));
            } else {
              children.add(AudioSource.uri(Uri.parse(url), headers: KoofrSettings.headersFor(url)));
            }
          }
          final source = ConcatenatingAudioSource(children: children);
          this.chain = chain;
          _changing = false;
          _lastIndex = index;
          await player.setAudioSource(source, initialIndex: index);
          _durations.clear();
          _loadedId = v.id;
          nowPlaying.value = v;
          unawaited(Eq.apply());
          unawaited(player.play());
          return;
        } catch (e) {
          last = e;
          await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
        }
      }
      throw last ?? Exception('No se pudo cargar');
    } finally {
      _loading = false;
    }
  }

  /// Comprueba que Koofr responde antes de reproducir (mensaje claro si falla).
  Future<void> _preflight(String url) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers.addAll({...(KoofrSettings.headersFor(url) ?? const {}), 'Range': 'bytes=0-1'});
      final res = await client.send(req).timeout(const Duration(seconds: 20));
      await res.stream.listen((_) {}).cancel();
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw Exception('Koofr respondió ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Cambio manual: el brazo vuelve al reposo, cambia el tema y baja de nuevo.
  Future<void> goTrack(int i) async {
    final v = nowPlaying.value;
    if (v == null || _changing || i < 0 || i >= v.trackUrls.length) return;
    if (chain) {
      _lastIndex = i;
      await player.seek(Duration.zero, index: i);
      unawaited(player.play());
      return;
    }
    _changing = true;
    await player.pause(); // el brazo se levanta
    await Future.delayed(const Duration(milliseconds: 900));
    _lastIndex = i;
    await player.seek(Duration.zero, index: i);
    await Future.delayed(const Duration(milliseconds: 300));
    _changing = false;
    unawaited(player.play()); // el brazo baja al borde exterior
  }

  /// El reproductor pasó solo al siguiente tema: repite la animación.
  void _onIndex(int? i) {
    if (i == null) return;
    final prev = _lastIndex;
    _lastIndex = i;
    if (_loadedId == null || prev == i || _changing || chain) return;
    _autoAdvance();
  }

  Future<void> _autoAdvance() async {
    _changing = true;
    await player.pause();
    await Future.delayed(const Duration(milliseconds: 900));
    await player.seek(Duration.zero);
    await Future.delayed(const Duration(milliseconds: 300));
    _changing = false;
    unawaited(player.play());
  }

  /// Terminó el último tema: el brazo vuelve al reposo.
  Future<void> _onCompleted() async {
    if (_changing || _loadedId == null) return;
    _changing = true;
    await player.pause();
    _lastIndex = 0;
    await player.seek(Duration.zero, index: 0);
    _changing = false;
  }

  Future<void> stop() async {
    _loadedId = null;
    _changing = false;
    nowPlaying.value = null;
    await player.stop();
  }

  /// Detiene la música si el disco indicado es el que suena.
  Future<void> stopIf(String id) async {
    if (nowPlaying.value?.id == id) await stop();
  }
}
