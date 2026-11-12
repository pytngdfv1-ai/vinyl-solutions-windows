import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import '../data/equalizer.dart';

/// Envuelve la plataforma de audio para avisar al ecualizador de cada reproductor creado.
class _HookedPlatform extends JustAudioPlatform {
  _HookedPlatform(this._inner);

  final JustAudioPlatform _inner;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final p = await _inner.init(request);
    Eq.attach(p);
    return p;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) =>
      _inner.disposePlayer(request);

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) =>
      _inner.disposeAllPlayers(request);
}

/// Llamar justo después de `JustAudioMediaKit.ensureInitialized`.
void installAudioHook() {
  JustAudioPlatform.instance = _HookedPlatform(JustAudioPlatform.instance);
}
