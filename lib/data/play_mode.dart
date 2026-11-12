enum PlayMode { disc, cassette, reel }

/// Reproductor en el que se está navegando: cambia cómo se ve y suena cada elemento.
/// null = según lo que sea cada elemento (disco, cassette o tema suelto).
class ViewMode {
  static PlayMode? current;

  /// Elemento que suena y el reproductor en el que se empezó a reproducir.
  static String? playingId;
  static PlayMode? playingMode;

  static bool tapeOf(String id, bool cassette, bool single) {
    final m = current ?? (id == playingId ? playingMode : null);
    return switch (m) {
      PlayMode.disc => false,
      PlayMode.cassette => true,
      _ => cassette || single,
    };
  }
}
