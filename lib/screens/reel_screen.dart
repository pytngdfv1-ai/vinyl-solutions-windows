import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../platform/haptic.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio/player_service.dart';
import '../models/vinyl.dart';
import '../theme.dart';

/// Reproductor de cinta abierta (carrete): reproduce cualquier álbum o suelto.
class ReelScreen extends StatefulWidget {
  const ReelScreen({super.key, required this.vinyl});
  final Vinyl vinyl;

  @override
  State<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends State<ReelScreen> with SingleTickerProviderStateMixin {
  final _ps = PlayerService.instance;
  late final Ticker _tick;
  Duration _last = Duration.zero;
  double _angle = 0;
  double _speed = 0;
  double _vu = 0;
  final _t = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tick = createTicker(_onTick)..start();
    _load();
  }

  Future<void> _load() async {
    try {
      await _ps.start(widget.vinyl);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo reproducir')));
      }
    }
  }

  void _onTick(Duration d) {
    final dt = (d - _last).inMicroseconds / 1e6;
    _last = d;
    final playing = _ps.player.playing && _ps.nowPlaying.value?.id == widget.vinyl.id;
    _speed += ((playing ? 1.0 : 0.0) - _speed) * math.min(1.0, dt * 2.5);
    _angle += _speed * dt * 3.2;
    final s = d.inMilliseconds / 1000.0;
    final target = playing ? 0.5 + 0.25 * math.sin(s * 7.3) * math.sin(s * 2.1) + 0.15 * math.sin(s * 13.0) : 0.0;
    _vu += (target - _vu) * math.min(1.0, dt * 9);
    _t.value++;
  }

  @override
  void dispose() {
    _tick.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vinyl;
    return Scaffold(
      appBar: AppBar(title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.98,
            child: ValueListenableBuilder<int>(
              valueListenable: _t,
              builder: (_, __, ___) {
                final dur = _ps.player.duration?.inMilliseconds ?? 0;
                final pos = _ps.player.position.inMilliseconds;
                final prog = dur > 0 ? (pos / dur).clamp(0.0, 1.0).toDouble() : 0.0;
                return CustomPaint(painter: _ReelPainter(_angle, _vu, prog, pos ~/ 1000));
              },
            ),
          ),
          StreamBuilder<bool>(
            stream: _ps.player.playingStream,
            builder: (_, snap) {
              final playing = snap.data ?? false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {
                      Haptic.selectionClick();
                      _ps.goTrack((_ps.player.currentIndex ?? 0) - 1);
                    },
                  ),
                  IconButton.filled(
                    iconSize: 40,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      Haptic.mediumImpact();
                      playing ? _ps.player.pause() : _ps.player.play();
                    },
                  ),
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      Haptic.selectionClick();
                      _ps.goTrack((_ps.player.currentIndex ?? 0) + 1);
                    },
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: StreamBuilder<int?>(
              stream: _ps.player.currentIndexStream,
              builder: (_, snap) {
                final cur = snap.data ?? 0;
                return ListView.builder(
                  itemCount: v.tracks.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    leading: Text('${i + 1}', style: TextStyle(color: i == cur ? AppColors.gold : Colors.white54)),
                    title: Text(v.tracks[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: i == cur ? AppColors.gold : null)),
                    onTap: () => _ps.goTrack(i),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelPainter extends CustomPainter {
  _ReelPainter(this.angle, this.vu, this.progress, this.seconds);
  final double angle;
  final double vu;
  final double progress;
  final int seconds;

  static const _gold = Color(0xFFE8C14A);

  void _text(Canvas c, String t, Offset o, double size, Color col, {bool bold = false, TextAlign al = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: col, fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = al == TextAlign.center ? -tp.width / 2 : 0.0;
    tp.paint(c, o + Offset(dx, -tp.height / 2));
  }

  void _knob(Canvas c, Offset o, double r) {
    final rect = Rect.fromCircle(center: o, radius: r);
    c.drawCircle(o.translate(1, 2), r, Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    c.drawCircle(o, r, Paint()..shader = const SweepGradient(colors: [Color(0xFFE6E7EC), Color(0xFF6E7079), Color(0xFFD2D4DA), Color(0xFF5B5D66), Color(0xFFE6E7EC)]).createShader(rect));
    for (var i = 0; i < 28; i++) {
      final a = i * 2 * math.pi / 28;
      c.drawLine(o + Offset(math.cos(a), math.sin(a)) * (r * .86), o + Offset(math.cos(a), math.sin(a)) * r, Paint()..strokeWidth = .7..color = Colors.black54);
    }
    c.drawCircle(o, r * .68, Paint()..shader = const RadialGradient(center: Alignment(-.4, -.5), colors: [Color(0xFF9A9CA6), Color(0xFF3A3C44)]).createShader(rect));
    c.drawLine(o, o + Offset(math.cos(-math.pi * .7), math.sin(-math.pi * .7)) * (r * .62), Paint()..strokeWidth = 1.6..strokeCap = StrokeCap.round..color = Colors.white);
  }

  /// Vúmetro con escala en dB, marcas, zona roja, "VU" y aguja.
  void _vuMeter(Canvas c, Rect r, double level, String ch) {
    final face = RRect.fromRectAndRadius(r, const Radius.circular(5));
    c.drawRRect(face.inflate(2), Paint()..color = const Color(0xFF08080A));
    c.drawRRect(face, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE2A8), Color(0xFFF2B65C), Color(0xFFE09A3E)]).createShader(r));
    c.save();
    c.clipRRect(face);
    final pivot = Offset(r.center.dx, r.bottom + r.height * .28);
    final rad = r.height * 1.02;
    const a0 = -math.pi * .83;
    const a1 = -math.pi * .17;
    double ang(double f) => a0 + (a1 - a0) * f;
    // zona roja (de 0 a +3 dB)
    final red = Rect.fromCircle(center: pivot, radius: rad);
    c.drawArc(red, ang(.7), ang(1) - ang(.7), false, Paint()..style = PaintingStyle.stroke..strokeWidth = r.height * .05..color = const Color(0xFFC62828));
    c.drawArc(red, ang(0), ang(.7) - ang(0), false, Paint()..style = PaintingStyle.stroke..strokeWidth = r.height * .02..color = Colors.black87);
    // marcas y números
    const marks = [(-20.0, 0.0), (-10.0, .22), (-7.0, .36), (-5.0, .48), (-3.0, .6), (0.0, .76), (3.0, 1.0)];
    for (final m in marks) {
      final a = ang(m.$2);
      final dir = Offset(math.cos(a), math.sin(a));
      c.drawLine(pivot + dir * (rad - r.height * .06), pivot + dir * (rad + r.height * .04), Paint()..strokeWidth = 1.2..color = m.$1 > 0 || m.$1 == 0 ? const Color(0xFF8A1A10) : Colors.black87);
      final lab = m.$1 > 0 ? '+${m.$1.round()}' : '${m.$1.round()}';
      _text(c, lab, pivot + dir * (rad - r.height * .2), r.height * .13, m.$1 >= 0 ? const Color(0xFF8A1A10) : Colors.black87, bold: true);
    }
    for (var i = 0; i <= 20; i++) {
      final a = ang(i / 20);
      final dir = Offset(math.cos(a), math.sin(a));
      c.drawLine(pivot + dir * (rad - r.height * .03), pivot + dir * (rad + r.height * .01), Paint()..strokeWidth = .6..color = Colors.black54);
    }
    _text(c, 'VU', Offset(r.center.dx, r.bottom - r.height * .3), r.height * .2, Colors.black87, bold: true);
    _text(c, ch, Offset(r.left + r.width * .12, r.top + r.height * .14), r.height * .11, Colors.black54, bold: true);
    _text(c, 'dB', Offset(r.right - r.width * .12, r.top + r.height * .14), r.height * .11, Colors.black54, bold: true);
    // aguja con sombra
    final a = ang(level.clamp(0.0, 1.0));
    final tip = pivot + Offset(math.cos(a), math.sin(a)) * (rad - r.height * .08);
    c.drawLine(pivot.translate(1.5, 1.5), tip.translate(1.5, 1.5), Paint()..strokeWidth = 1.6..color = Colors.black26);
    c.drawLine(pivot, tip, Paint()..strokeWidth = 1.3..strokeCap = StrokeCap.round..color = const Color(0xFF1A1A1A));
    c.restore();
    // cristal
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 2, r.top + 2, r.width - 4, r.height * .42), const Radius.circular(4)),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)]).createShader(r),
    );
    c.drawRRect(face, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.black);
    c.drawCircle(pivot.translate(0, -r.height * .28), 0, Paint());
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    // cuerpo con textura metálica
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * .04, h * .46, w * .92, h * .52), const Radius.circular(16));
    c.drawRRect(body.shift(const Offset(0, 4)), Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    c.drawRRect(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A3A42), Color(0xFF1C1C21), Color(0xFF101013)]).createShader(body.outerRect));
    c.drawRRect(body.deflate(1), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white24);
    for (final p in [Offset(w * .08, h * .5), Offset(w * .92, h * .5), Offset(w * .08, h * .94), Offset(w * .92, h * .94)]) {
      c.drawCircle(p, 3, Paint()..color = const Color(0xFF8E9099));
      c.drawLine(p.translate(-2, 0), p.translate(2, 0), Paint()..strokeWidth = .8..color = Colors.black87);
    }
    _text(c, 'STEREO  TAPE  DECK', Offset(w * .5, h * .495), 9, Colors.white54, bold: true);

    final reelR = w * .21;
    final centers = [Offset(w * .28, h * .26), Offset(w * .72, h * .26)];
    // recorrido de la cinta: rodillos y cabezal
    final guideL = Offset(w * .34, h * .585);
    final guideR = Offset(w * .66, h * .585);
    final tape = Paint()..color = const Color(0xFF5B3F28)..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    c.drawLine(Offset(centers[0].dx + reelR * .55, centers[0].dy + reelR * .85), guideL, tape);
    c.drawLine(guideL, guideR, tape);
    c.drawLine(guideR, Offset(centers[1].dx - reelR * .55, centers[1].dy + reelR * .85), tape);
    // cabezales
    for (final x in [.42, .5, .58]) {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * x, h * .565), width: w * .06, height: h * .028), const Radius.circular(2));
      c.drawRRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB7B9C2), Color(0xFF4A4C54)]).createShader(r.outerRect));
    }
    for (final g in [guideL, guideR]) {
      c.drawCircle(g, 6, Paint()..shader = const RadialGradient(center: Alignment(-.4, -.5), colors: [Color(0xFFE3E4EA), Color(0xFF55575F)]).createShader(Rect.fromCircle(center: g, radius: 6)));
      c.drawCircle(g, 1.8, Paint()..color = Colors.black87);
    }
    for (var k = 0; k < 2; k++) {
      final o = centers[k];
      final pack = reelR * (k == 0 ? 0.92 - 0.45 * progress : 0.47 + 0.45 * progress);
      c.drawCircle(o.translate(3, 4), reelR, Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      final rect = Rect.fromCircle(center: o, radius: reelR);
      c.drawCircle(o, reelR, Paint()..shader = const SweepGradient(colors: [Color(0xFFE8E9EE), Color(0xFF8C8E98), Color(0xFFD9DBE1), Color(0xFF7C7E88), Color(0xFFE8E9EE)]).createShader(rect));
      c.drawCircle(o, reelR * .97, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white60);
      // cinta enrollada con vetas
      c.drawCircle(o, pack, Paint()..shader = const RadialGradient(colors: [Color(0xFF3B2A1C), Color(0xFF5A402B)]).createShader(Rect.fromCircle(center: o, radius: pack)));
      for (var i = 1; i < 6; i++) {
        c.drawCircle(o, pack * (.35 + i * .11), Paint()..style = PaintingStyle.stroke..strokeWidth = .5..color = Colors.black26);
      }
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(angle);
      for (var i = 0; i < 3; i++) {
        c.rotate(2 * math.pi / 3);
        final lim = (pack / reelR).clamp(0.55, 1.0);
        final p = Path()
          ..moveTo(-reelR * .12, -reelR * .3)
          ..lineTo(-reelR * .3, -reelR * .92 * lim)
          ..lineTo(reelR * .3, -reelR * .92 * lim)
          ..lineTo(reelR * .12, -reelR * .3)
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFF17181C));
        c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = .8..color = Colors.white24);
      }
      c.restore();
      c.drawCircle(o, reelR * .24, Paint()..shader = const RadialGradient(center: Alignment(-.4, -.5), colors: [Color(0xFF5A5C66), Color(0xFF22232A)]).createShader(Rect.fromCircle(center: o, radius: reelR * .24)));
      c.drawCircle(o, reelR * .07, Paint()..color = const Color(0xFFE6E7EC));
    }

    // vúmetros con escala
    _vuMeter(c, Rect.fromLTWH(w * .08, h * .64, w * .3, h * .24), vu, 'L');
    _vuMeter(c, Rect.fromLTWH(w * .42, h * .64, w * .3, h * .24), vu * .93, 'R');

    // contador de cinta
    final cnt = Rect.fromLTWH(w * .76, h * .64, w * .17, h * .075);
    c.drawRRect(RRect.fromRectAndRadius(cnt, const Radius.circular(3)), Paint()..color = const Color(0xFF0B0B0D));
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    _text(c, '$mm:$ss', cnt.center, h * .05, const Color(0xFFFF5A3C), bold: true);
    _text(c, 'COUNTER', Offset(cnt.center.dx, cnt.top - 6), 7, Colors.white54, bold: true);
    // perillas y luces
    _knob(c, Offset(w * .82, h * .8), w * .045);
    _knob(c, Offset(w * .91, h * .8), w * .035);
    _text(c, 'LEVEL', Offset(w * .82, h * .87), 7, Colors.white54, bold: true);
    _text(c, 'TONE', Offset(w * .91, h * .87), 7, Colors.white54, bold: true);
    c.drawCircle(Offset(w * .08, h * .93), 3, Paint()..color = vu > .05 ? const Color(0xFF42C26B) : const Color(0xFF1F3A28));
    _text(c, 'PLAY', Offset(w * .155, h * .93), 7, Colors.white54, bold: true);
    c.drawCircle(Offset(w * .24, h * .93), 3, Paint()..color = const Color(0xFF5A1A16));
    _text(c, 'REC', Offset(w * .29, h * .93), 7, Colors.white54, bold: true);
    _text(c, '7½ ips', Offset(w * .5, h * .93), 8, _gold, bold: true);
  }

  @override
  bool shouldRepaint(covariant _ReelPainter old) => true;
}
