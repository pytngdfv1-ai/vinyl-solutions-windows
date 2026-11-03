import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ui_settings.dart';

/// Luz del brillo del vinilo y del plástico. En Windows no hay acelerómetro:
/// la luz sigue la posición del ratón sobre la ventana.
class Tilt {
  Tilt._();
  static final Tilt instance = Tilt._();

  /// x, y en -1..1 (suavizados).
  final ValueNotifier<Offset> value = ValueNotifier<Offset>(Offset.zero);
  int _lastMs = 0;

  VoidCallback acquire() => () {};

  /// Llamado con la posición del ratón y el tamaño de la ventana.
  void pointer(Offset pos, Size size) {
    if (!UiSettings.fx || size.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 33) return;
    _lastMs = now;
    final x = ((pos.dx / size.width) * 2 - 1).clamp(-1.0, 1.0).toDouble();
    final y = ((pos.dy / size.height) * 2 - 1).clamp(-1.0, 1.0).toDouble();
    final o = value.value;
    value.value = Offset(o.dx + (x - o.dx) * 0.25, o.dy + (y - o.dy) * 0.25);
  }
}

/// Carga única del shader de brillo (null si el dispositivo no lo soporta: se usa el degradado).
class SheenShader {
  static ui.FragmentProgram? program;
  static bool _tried = false;

  static Future<void> load() async {
    if (_tried) return;
    _tried = true;
    try {
      program = await ui.FragmentProgram.fromAsset('shaders/vinyl_sheen.frag');
    } catch (_) {
      program = null;
    }
  }
}
