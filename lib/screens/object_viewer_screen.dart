import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/objects3d.dart';
import '../models/vinyl.dart';
import '../widgets/mini3d.dart';

/// Visor 3D: arrastra para girar el objeto (al soltar queda de frente o de espalda),
/// "Dar vuelta" lo gira 180° y "Sacar" saca el disco de la funda o el cassette de la caja.
class ObjectViewerScreen extends StatefulWidget {
  const ObjectViewerScreen({super.key, required this.vinyl});
  final Vinyl vinyl;

  @override
  State<ObjectViewerScreen> createState() => _ObjectViewerScreenState();
}

class _ObjectViewerScreenState extends State<ObjectViewerScreen> with TickerProviderStateMixin {
  late final AnimationController _snap = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
    ..addListener(_onSnap);
  late final AnimationController _out = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  double _yaw = 0, _pitch = .18;
  double _y0 = 0, _y1 = 0, _p0 = 0;
  bool _pulled = false;
  double _zoom = 1, _z0 = 1;
  Offset _pan = Offset.zero;
  bool _rotated = false;

  ui.Image? _front, _back, _label, _discFace;
  bool _ready = false;

  Vinyl get v => widget.vinyl;
  bool get _tape => v.isTape;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _front = await Objects3D.loadImage(v.coverUrl);
      _back = await Objects3D.backImage(v, tape: _tape);
      _label = await Objects3D.labelImage(v, tape: _tape);
      if (!_tape) _discFace = await _makeDiscFace(_label);
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  Future<ui.Image> _makeDiscFace(ui.Image? label) async {
    const s = 512.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const o = Offset(s / 2, s / 2);
    c.drawCircle(o, s / 2, Paint()..color = const Color(0xFF0C0C0F));
    for (var r = .46; r < .98; r += .035) {
      c.drawCircle(o, s / 2 * r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0x16FFFFFF));
    }
    c.drawCircle(
      o,
      s / 2,
      Paint()
        ..shader = const SweepGradient(
          colors: [Color(0x00FFFFFF), Color(0x26FFFFFF), Color(0x00FFFFFF), Color(0x26FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromCircle(center: o, radius: s / 2)),
    );
    if (label != null) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: s * .2)));
      c.drawImageRect(label, Rect.fromLTWH(0, 0, label.width.toDouble(), label.height.toDouble()), Rect.fromCircle(center: o, radius: s * .2),
          Paint()..filterQuality = FilterQuality.medium);
      c.restore();
    }
    c.drawCircle(o, s * .012, Paint()..color = const Color(0xFF050506));
    return rec.endRecording().toImage(s.round(), s.round());
  }

  @override
  void dispose() {
    _snap.dispose();
    _out.dispose();
    super.dispose();
  }

  void _onSnap() {
    final t = Curves.easeOutCubic.transform(_snap.value);
    setState(() {
      _yaw = _y0 + (_y1 - _y0) * t;
      _pitch = _p0 + (.18 - _p0) * t;
    });
  }

  void _goTo(double yaw) {
    _y0 = _yaw;
    _y1 = yaw;
    _p0 = _pitch;
    _snap.forward(from: 0);
  }

  void _flipHalf() => _goTo((_yaw / math.pi).round() * math.pi + math.pi);

  void _pull() {
    _pulled = !_pulled;
    _pulled ? _out.forward() : _out.reverse();
    setState(() {});
  }

  List<Face3> _scene(double o) {
    if (_tape) {
      const cw = 1.25, ch = 1.95, cd = .16;
      final ty = (-0.1 - 1.45 * o);
      return [
        if (o > 0.001)
          ...box3(V3(0, ty, 0), 1.05, .62, .1, front: _label, side: const Color(0xFF16161A), frontColor: const Color(0xFFEDE6D2), backColor: const Color(0xFF16161A)),
        ...box3(V3(0, 0, 0), cw, ch, cd,
            front: _front,
            frontUv: _front == null ? null : coverUv(_front!, cw / ch),
            back: _back,
            side: const Color(0xFF202026),
            frontColor: const Color(0xFF26262C),
            backColor: const Color(0xFF26262C)),
      ];
    }
    const sw = 1.75, sd = .07;
    return [
      if (o > 0.001) ...disc3(V3(1.5 * o, 0, 0), .83, .03, _discFace),
      ...box3(V3(0, 0, 0), sw, sw, sd, front: _front, frontUv: _front == null ? null : coverUv(_front!, 1), back: _back, side: const Color(0xFF202026)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title;
    final o = Curves.easeInOut.transform(_out.value);
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator())
                : AnimatedBuilder(
                    animation: _out,
                    builder: (_, __) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (_) {
                        _snap.stop();
                        _z0 = _zoom;
                        _rotated = false;
                      },
                      onScaleUpdate: (d) => setState(() {
                        if (d.pointerCount >= 2) {
                          _zoom = (_z0 * d.scale).clamp(.8, 4.0);
                          _pan += d.focalPointDelta;
                        } else if (_zoom <= 1.05) {
                          _rotated = true;
                          _yaw += d.focalPointDelta.dx * .012;
                          _pitch = (_pitch + d.focalPointDelta.dy * .008).clamp(-.5, .6);
                        } else {
                          _pan += d.focalPointDelta;
                        }
                      }),
                      onScaleEnd: (_) {
                        if (_zoom < 1) {
                          _zoom = 1;
                          _pan = Offset.zero;
                        }
                        if (_rotated) _goTo((_yaw / math.pi).round() * math.pi);
                      },
                      onDoubleTap: () => setState(() {
                        _zoom = _zoom > 1.2 ? 1 : 2;
                        _pan = Offset.zero;
                      }),
                      onTap: _flipHalf,
                      child: SizedBox.expand(
                        child: CustomPaint(
                          painter: Scene3DPainter(
                            _scene(o),
                            _yaw,
                            _pitch,
                            scale: (_tape ? .3 : .27) * _zoom,
                            pan: _pan,
                            shift: _tape ? Offset(0, .7 * o) : Offset(-.75 * o, 0),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(onPressed: _flipHalf, icon: const Icon(Icons.flip), label: const Text('Dar vuelta')),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _pull,
                    icon: Icon(_tape ? Icons.album_outlined : Icons.album),
                    label: Text(_pulled ? 'Guardar' : (_tape ? 'Sacar cassette' : 'Sacar disco')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
