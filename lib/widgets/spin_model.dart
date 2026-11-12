import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../platform/haptic.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Objeto 3D "girable": una secuencia de [frames] imágenes de una vuelta completa.
/// Al deslizar el dedo sobre él gira en su eje, con la fuerza del impulso y fricción.
class SpinModel extends StatefulWidget {
  const SpinModel({super.key, required this.folder, this.frames = 36, this.enabled = true});

  /// Carpeta en assets/models3d/.
  final String folder;
  final int frames;

  /// Solo gira con el dedo si está activo (la tarjeta del frente).
  final bool enabled;

  static const initialFrame = 3;

  @override
  State<SpinModel> createState() => _SpinModelState();
}

class _SpinModelState extends State<SpinModel> with SingleTickerProviderStateMixin {
  late final Ticker _tick;
  double _pos = SpinModel.initialFrame.toDouble(); // en cuadros
  FrictionSimulation? _fling;
  Duration _t0 = Duration.zero;
  int _lastTick = -1;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _tick = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      // Deja listos los primeros cuadros para que el giro no parpadee.
      for (var i = 0; i < widget.frames; i += 3) {
        precacheImage(AssetImage(_path(i)), context);
      }
    }
  }

  String _path(int i) => 'assets/models3d/${widget.folder}/${i.toString().padLeft(2, '0')}.webp';

  void _onTick(Duration d) {
    final f = _fling;
    if (f == null) return;
    final t = (d - _t0).inMicroseconds / 1e6;
    if (f.isDone(t)) {
      _tick.stop();
      _fling = null;
      return;
    }
    _set(f.x(t));
  }

  void _set(double v) {
    final n = widget.frames;
    final p = ((v % n) + n) % n;
    final idx = p.floor();
    if (idx != _lastTick && idx % 4 == 0) Haptic.selectionClick();
    _lastTick = idx;
    setState(() => _pos = p);
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      _path(_pos.floor() % widget.frames),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
    if (!widget.enabled) return img;
    return LayoutBuilder(
      builder: (context, cons) {
        // Arrastrar todo el ancho del icono = una vuelta y media.
        final perPx = widget.frames * 1.5 / math.max(120.0, cons.maxWidth);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _tick.stop();
            _fling = null;
          },
          onHorizontalDragUpdate: (d) => _set(_pos - d.delta.dx * perPx),
          onHorizontalDragEnd: (d) {
            final v = -(d.primaryVelocity ?? 0) * perPx; // cuadros por segundo
            if (v.abs() < 8) return;
            _fling = FrictionSimulation(0.12, _pos, v.clamp(-widget.frames * 4.0, widget.frames * 4.0).toDouble());
            _t0 = Duration.zero;
            _tick
              ..stop()
              ..start();
          },
          child: img,
        );
      },
    );
  }
}
