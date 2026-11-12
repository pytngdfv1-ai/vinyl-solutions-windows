import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'spin_model.dart';

enum MenuIconKind { turntable, deck, dj, reel, equalizer, gear, covers, search }

/// Icono 3D del carrusel principal: objeto dibujado con volumen, luz y sombra, sin recuadro.
class MenuIconCard extends StatelessWidget {
  const MenuIconCard({super.key, required this.kind, required this.label, this.sub, this.model, this.front = false});

  final MenuIconKind kind;
  final String label;
  final String? sub;

  /// Carpeta de assets/models3d/ con el objeto 3D girable (si no hay, se usa el dibujo).
  final String? model;
  final bool front;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: model != null
              ? SpinModel(folder: model!, enabled: front)
              : CustomPaint(painter: _IconPainter(kind), size: Size.infinite),
        ),
        const SizedBox(height: 6),
        Text(label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      ],
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.kind);
  final MenuIconKind kind;

  static const _gold = Color(0xFFE8C14A);
  static const _steel = Color(0xFFB9BCC6);

  @override
  void paint(Canvas c, Size s) {
    final side = math.min(s.width, s.height);
    c.translate((s.width - side) / 2, (s.height - side) / 2);
    c.scale(side / 100);
    // Suelo: halo suave detrás del objeto.
    c.drawCircle(
      const Offset(50, 54),
      46,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)])
            .createShader(Rect.fromCircle(center: const Offset(50, 54), radius: 46)),
    );
    switch (kind) {
      case MenuIconKind.turntable:
        _turntable(c);
      case MenuIconKind.deck:
        _deck(c);
      case MenuIconKind.dj:
        _dj(c);
      case MenuIconKind.reel:
        _reel(c);
      case MenuIconKind.equalizer:
        _eq(c);
      case MenuIconKind.gear:
        _gear(c);
      case MenuIconKind.covers:
        _covers(c);
      case MenuIconKind.search:
        _search(c);
    }
  }

  // ───────── utilidades de volumen ─────────
  Color _l(Color a, double t) => Color.lerp(a, Colors.white, t)!;
  Color _d(Color a, double t) => Color.lerp(a, Colors.black, t)!;

  void _ground(Canvas c, double cx, double cy, double rx, double ry) {
    c.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      Paint()..color = const Color(0xB0000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  /// Caja vista desde arriba y un poco de frente: cara superior + frente con grosor.
  void _box(Canvas c, Rect top, double depth, Color base, {double rad = 5, bool grain = false}) {
    final front = RRect.fromLTRBR(top.left, top.top + rad, top.right, top.bottom + depth, Radius.circular(rad));
    c.drawRRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_d(base, .25), _d(base, .62)],
        ).createShader(front.outerRect),
    );
    final face = RRect.fromRectAndRadius(top, Radius.circular(rad));
    c.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_l(base, .30), base, _d(base, .30)],
          stops: const [0, .45, 1],
        ).createShader(top),
    );
    if (grain) {
      c.save();
      c.clipRRect(face);
      for (var i = 0; i < 26; i++) {
        final y = top.top + (i + .5) * top.height / 26;
        final w = math.sin(i * 12.9898) * 43758.5453;
        final f = w - w.floorToDouble();
        c.drawPath(
          Path()
            ..moveTo(top.left, y)
            ..cubicTo(top.left + top.width * .3, y + f * 2.5 - 1.2, top.left + top.width * .65, y - f * 2.5 + 1.2, top.right, y + f - .5),
          Paint()..style = PaintingStyle.stroke..strokeWidth = .35 + f * .5..color = Colors.black.withOpacity(.10 + f * .16),
        );
      }
      c.restore();
    }
    // sombra interior inferior y brillo de borde superior
    c.drawRRect(face.deflate(.5), Paint()..style = PaintingStyle.stroke..strokeWidth = .9..color = _l(base, .55).withOpacity(.7));
    c.drawLine(Offset(top.left + rad, top.top + .8), Offset(top.right - rad, top.top + .8), Paint()..strokeWidth = .7..color = Colors.white54);
    c.drawLine(Offset(top.left + rad, top.bottom + .4), Offset(top.right - rad, top.bottom + .4), Paint()..strokeWidth = .8..color = Colors.black54);
  }

  void _screw(Canvas c, Offset o, [double r = 1.3]) {
    c.drawCircle(o, r, Paint()..color = const Color(0xFF8E9099));
    c.drawLine(o.translate(-r * .7, 0), o.translate(r * .7, 0), Paint()..strokeWidth = .5..color = Colors.black87);
  }

  /// Plato / elipse con grosor.
  void _puck(Canvas c, Offset o, double rx, double ry, double depth, Color base) {
    final side = Path()
      ..addOval(Rect.fromCenter(center: o.translate(0, depth), width: rx * 2, height: ry * 2))
      ..addRect(Rect.fromLTRB(o.dx - rx, o.dy, o.dx + rx, o.dy + depth));
    c.drawPath(side, Paint()..color = _d(base, .55));
    c.drawOval(
      Rect.fromCenter(center: o, width: rx * 2, height: ry * 2),
      Paint()
        ..shader = RadialGradient(center: const Alignment(-.35, -.45), radius: 1.05, colors: [_l(base, .35), base, _d(base, .45)])
            .createShader(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2)),
    );
  }

  void _ball(Canvas c, Offset o, double r, Color base) {
    c.drawCircle(o.translate(r * .15, r * .35), r, Paint()..color = Colors.black45..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    final rect = Rect.fromCircle(center: o, radius: r);
    c.drawCircle(o, r, Paint()..shader = RadialGradient(center: const Alignment(-.4, -.5), radius: 1.0, colors: [_l(base, .75), base, _d(base, .65)], stops: const [0, .5, 1]).createShader(rect));
    c.drawCircle(o.translate(-r * .35, -r * .4), r * .22, Paint()..color = Colors.white.withOpacity(.55));
  }

  /// Perilla metálica moleteada con indicador.
  void _knob(Canvas c, Offset o, double r, {double ang = -2.2}) {
    final rect = Rect.fromCircle(center: o, radius: r);
    c.drawCircle(o.translate(.6, 1.4), r, Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4));
    c.drawCircle(o, r, Paint()..shader = const SweepGradient(colors: [Color(0xFFEDEEF2), Color(0xFF6D6F78), Color(0xFFD5D7DD), Color(0xFF585A63), Color(0xFFEDEEF2)]).createShader(rect));
    final n = (r * 4).round().clamp(12, 26);
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      c.drawLine(o + Offset(math.cos(a), math.sin(a)) * (r * .8), o + Offset(math.cos(a), math.sin(a)) * r, Paint()..strokeWidth = .35..color = Colors.black54);
    }
    c.drawCircle(o, r * .62, Paint()..shader = const RadialGradient(center: Alignment(-.4, -.5), colors: [Color(0xFFA7A9B3), Color(0xFF3A3C45)]).createShader(rect));
    c.drawLine(o, o + Offset(math.cos(ang), math.sin(ang)) * (r * .58), Paint()..strokeWidth = r * .2..strokeCap = StrokeCap.round..color = Colors.white);
  }

  void _gloss(Canvas c, Rect r, {double rad = 5}) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 1.5, r.top + 1.5, r.width - 3, r.height * .38), Radius.circular(rad)),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)]).createShader(r),
    );
  }

  void _grooves(Canvas c, Offset o, double rx, double ry, List<double> fr) {
    for (final f in fr) {
      c.drawOval(Rect.fromCenter(center: o, width: rx * 2 * f, height: ry * 2 * f), Paint()..style = PaintingStyle.stroke..strokeWidth = .45..color = const Color(0x2EFFFFFF));
    }
    // brillo cónico del vinilo
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2)));
    c.drawOval(
      Rect.fromCenter(center: o, width: rx * 2, height: ry * 2),
      Paint()..shader = const SweepGradient(colors: [Color(0x00FFFFFF), Color(0x38FFFFFF), Color(0x00FFFFFF), Color(0x38FFFFFF), Color(0x00FFFFFF)]).createShader(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2)),
    );
    c.restore();
  }

  // ───────── iconos ─────────
  void _quad(Canvas c, List<Offset> pts, Color base, {double light = 0}) {
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    p.close();
    final r = p.getBounds();
    c.drawPath(p, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_l(base, .22 + light), base, _d(base, .38)]).createShader(r));
    c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = .6..color = Colors.black.withOpacity(.55));
  }

  void _text(Canvas c, String t, Offset o, double size, Color col, {bool italic = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: col, fontSize: size, fontWeight: FontWeight.w700, fontStyle: italic ? FontStyle.italic : FontStyle.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  /// Tocadiscos maleta azul con tapa abierta, panel de madera y fieltro marrón.
  void _turntable(Canvas c) {
    _ground(c, 50, 90, 44, 5);
    const blue = Color(0xFF2F5576);
    // tapa abierta (detrás)
    final lid = RRect.fromRectAndRadius(const Rect.fromLTWH(15, 3, 70, 42), const Radius.circular(8));
    c.drawRRect(lid, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3C6285), Color(0xFF1B3147)]).createShader(lid.outerRect));
    final inner = RRect.fromRectAndRadius(const Rect.fromLTWH(19.5, 7.5, 61, 33), const Radius.circular(5));
    c.drawRRect(inner, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF17283A), Color(0xFF243D55)]).createShader(inner.outerRect));
    _text(c, 'Vintage Collection', const Offset(50, 22), 5.4, const Color(0xFF0F1C29), italic: true);
    _box(c, const Rect.fromLTWH(46, -1, 8, 6), 1.5, const Color(0xFF1A1A1C), rad: 1.5);
    // cuerpo: cara superior azul con panel de madera
    _box(c, const Rect.fromLTWH(6, 40, 88, 34), 13, blue, rad: 7);
    final wood = RRect.fromRectAndRadius(const Rect.fromLTWH(10, 43.5, 80, 27), const Radius.circular(4));
    c.drawRRect(wood, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8B6240), Color(0xFF5E3F26)]).createShader(wood.outerRect));
    c.save();
    c.clipRRect(wood);
    for (var i = 0; i < 24; i++) {
      final y = 43.5 + i * 27 / 24;
      final w = math.sin(i * 7.31) * 4375.5453;
      final f = w - w.floorToDouble();
      c.drawLine(Offset(10, y), Offset(90, y + f * 2 - 1), Paint()..strokeWidth = .3 + f * .4..color = Colors.black.withOpacity(.12 + f * .15));
    }
    c.restore();
    // plato con fieltro marrón
    const o = Offset(37, 58);
    _puck(c, o, 26, 13.6, 2.6, const Color(0xFF1B1B1D));
    _puck(c, o.translate(0, -.8), 24.6, 12.8, 1.6, const Color(0xFF5C3524));
    _grooves(c, o.translate(0, -.8), 24.6, 12.8, [.9, .74, .58]);
    _puck(c, o.translate(0, -2), 9, 4.7, .8, const Color(0xFF151517));
    c.drawOval(Rect.fromCenter(center: o.translate(0, -2.3), width: 18, height: 9.4), Paint()..style = PaintingStyle.stroke..strokeWidth = .4..color = Colors.white24);
    c.drawLine(o.translate(0, -2.5), o.translate(0, -8), Paint()..strokeWidth = 1.2..strokeCap = StrokeCap.round..color = const Color(0xFFD0D2D8));
    // brazo con cápsula blanca
    _puck(c, const Offset(76, 51), 6.5, 3.4, 2.4, const Color(0xFF111113));
    final arm = Paint()..strokeCap = StrokeCap.round..strokeWidth = 2.2..color = const Color(0xFF16161A);
    c.drawLine(const Offset(76, 49), const Offset(70, 53), arm);
    c.drawLine(const Offset(70, 53), const Offset(60, 63), arm);
    c.drawLine(const Offset(60, 63), const Offset(57, 66.5), Paint()..strokeCap = StrokeCap.round..strokeWidth = 3.4..color = const Color(0xFF0E0E10));
    c.drawLine(const Offset(58.5, 65), const Offset(56.3, 67.4), Paint()..strokeCap = StrokeCap.round..strokeWidth = 2..color = Colors.white);
    // perillas
    _knob(c, const Offset(84, 47), 2.3);
    _knob(c, const Offset(84, 53), 2.3);
    _knob(c, const Offset(84, 59), 2.3);
    _text(c, 'muse', const Offset(48, 69), 3, const Color(0xFFE0C58A));
    // frente: parlantes, asa y cierres
    for (final x in [9.0, 76.0]) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, 76, 15, 9.5), const Radius.circular(2.5));
      c.drawRRect(r, Paint()..color = const Color(0xFF16181C));
      for (var i = 0; i < 4; i++) {
        c.drawLine(Offset(x + 1.5, 78 + i * 2.1), Offset(x + 13.5, 78 + i * 2.1), Paint()..strokeWidth = .35..color = Colors.white24);
      }
    }
    for (final x in [28.0, 66.0]) {
      _box(c, Rect.fromLTWH(x, 76, 6, 5), 1, const Color(0xFF1C1C20), rad: 1);
    }
    final handle = RRect.fromRectAndRadius(const Rect.fromLTWH(36, 77, 28, 9), const Radius.circular(4.5));
    c.drawRRect(handle, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4D7396), Color(0xFF244057)]).createShader(handle.outerRect));
    c.drawRRect(handle.deflate(.5), Paint()..style = PaintingStyle.stroke..strokeWidth = .6..color = Colors.white30);
  }

  void _reelHub(Canvas c, Offset o, double r, double rot) {
    _puck(c, o, r, r * .62, 2, const Color(0xFFC9CCD4));
    _puck(c, o, r * .92, r * .56, .2, const Color(0xFFDADCE2));
    for (var i = 0; i < 3; i++) {
      final a = rot + i * 2 * math.pi / 3;
      final p = Path();
      for (final k in [-.3, -.2, .2, .3]) {
        final rr = (k.abs() > .25) ? r * .3 : r * .85;
        p.lineTo(o.dx + math.cos(a + k) * rr, o.dy + math.sin(a + k) * rr * .62);
      }
      p.close();
      c.drawPath(p, Paint()..color = const Color(0xFF202226));
    }
    _puck(c, o, r * .28, r * .17, .8, const Color(0xFF3A3C42));
  }

  /// Walkman gris oscuro con ventana transparente, teclas y tecla naranja.
  void _deck(Canvas c) {
    _ground(c, 52, 90, 36, 5);
    const g = Color(0xFF414844);
    // lateral derecho y cara superior
    _quad(c, const [Offset(72, 28), Offset(87, 20), Offset(87, 78), Offset(72, 88)], _d(g, .28));
    _quad(c, const [Offset(14, 28), Offset(29, 20), Offset(87, 20), Offset(72, 28)], _l(g, .05), light: .1);
    // cara frontal
    final front = RRect.fromRectAndRadius(const Rect.fromLTWH(14, 28, 58, 60), const Radius.circular(4));
    c.drawRRect(front, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5A625D), g, Color(0xFF2A302D)]).createShader(front.outerRect));
    c.drawRRect(front.deflate(.5), Paint()..style = PaintingStyle.stroke..strokeWidth = .7..color = Colors.white30);
    // teclas superiores
    for (var i = 0; i < 5; i++) {
      final x = 20 + i * 8.2;
      _quad(c, [Offset(x, 26.5), Offset(x + 6, 26.5), Offset(x + 9, 22), Offset(x + 3.5, 22)], const Color(0xFF17181A));
      c.drawLine(Offset(x + .8, 26.8), Offset(x + 5.2, 26.8), Paint()..strokeWidth = .6..color = Colors.white30);
    }
    _quad(c, const [Offset(61, 26.5), Offset(70, 26.5), Offset(74, 21), Offset(66, 21)], const Color(0xFFF2762A), light: .15);
    // ventana transparente con el cassette visible
    final win = RRect.fromRectAndRadius(const Rect.fromLTWH(19, 38, 48, 44), const Radius.circular(3));
    c.drawRRect(win, Paint()..color = const Color(0xFF15171A));
    final cas = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 43, 42, 28), const Radius.circular(2));
    c.drawRRect(cas, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD9D9DD), Color(0xFF8E9096)]).createShader(cas.outerRect));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(25, 46, 36, 12), const Radius.circular(1.5)), Paint()..color = const Color(0xFFF3EBD2));
    for (final x in [33.0, 53.0]) {
      c.drawCircle(Offset(x, 52), 4.2, Paint()..color = const Color(0xFF2A2B2F));
      c.drawCircle(Offset(x, 52), 2.2, Paint()..color = Colors.white);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        c.drawLine(Offset(x + math.cos(a) * 1, 52 + math.sin(a) * 1), Offset(x + math.cos(a) * 2.2, 52 + math.sin(a) * 2.2), Paint()..strokeWidth = .5..color = Colors.black87);
      }
    }
    c.drawRect(const Rect.fromLTWH(37, 62, 16, 5), Paint()..color = const Color(0xFF2B2C30));
    c.drawRRect(win, Paint()..style = PaintingStyle.stroke..strokeWidth = .8..color = Colors.white38);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(20, 39, 46, 17), const Radius.circular(3)),
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)]).createShader(const Rect.fromLTWH(20, 39, 46, 17)),
    );
    // tomas laterales naranjas
    for (final y in [58.0, 68.0]) {
      c.drawCircle(Offset(79.5, y), 2.6, Paint()..color = const Color(0xFFF2762A));
      c.drawCircle(Offset(79.5, y), 1.3, Paint()..color = Colors.black);
    }
    _text(c, 'STOP  REC  REW  PLAY', const Offset(44, 24.2), 2.6, Colors.white54);
  }

  void _dj(Canvas c) {
    _ground(c, 50, 82, 46, 6);
    _box(c, const Rect.fromLTWH(3, 30, 94, 46), 8, const Color(0xFF2B2B34), rad: 5);
    for (final x in [24.0, 76.0]) {
      _puck(c, Offset(x, 53), 21, 11.5, 3.5, const Color(0xFF9CA0AA));
      _puck(c, Offset(x, 52), 19, 10.2, 2, const Color(0xFF111113));
      _grooves(c, Offset(x, 52), 19, 10.2, [.9, .75, .6, .45]);
      c.drawOval(Rect.fromCenter(center: Offset(x, 52), width: 38, height: 20.4), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = _gold);
      _puck(c, Offset(x, 51), 5.5, 2.9, .8, const Color(0xFFD6492F));
      _ball(c, Offset(x, 50.5), 1.2, _steel);
    }
    _box(c, const Rect.fromLTWH(41, 33, 18, 38), 3, const Color(0xFF444450), rad: 2.5);
    for (var i = 0; i < 3; i++) {
      final x = 45.0 + i * 5;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - .7, 38, 1.4, 16), const Radius.circular(.7)), Paint()..color = Colors.black87);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.9, 42 + i * 3.0, 3.8, 3.4), const Radius.circular(.8)), Paint()..color = i == 1 ? _gold : _steel);
    }
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(44, 61, 12, 2.2), const Radius.circular(1)), Paint()..color = Colors.black87);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48, 59.8, 4, 4.6), const Radius.circular(.8)), Paint()..color = _steel);
    _knob(c, const Offset(45.5, 67), 2.2);
    _knob(c, const Offset(54.5, 67), 2.2);
    for (var i = 0; i < 24; i++) {
      for (final x in [24.0, 76.0]) {
        final a = i * 2 * math.pi / 24;
        c.drawCircle(Offset(x + math.cos(a) * 17.2, 52.4 + math.sin(a) * 9.3), .4, Paint()..color = _gold);
      }
    }
  }

  /// Grabadora de carrete plateada (aluminio cepillado), como la foto de referencia.
  void _reel(Canvas c) {
    _ground(c, 50, 91, 42, 5);
    const al = Color(0xFFB9B4AA);
    _box(c, const Rect.fromLTWH(14, 38, 72, 46), 7, al, rad: 3);
    // cepillado
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 38, 72, 46), const Radius.circular(3)));
    for (var i = 0; i < 40; i++) {
      c.drawLine(Offset(14, 38 + i * 1.15), Offset(86, 38 + i * 1.15), Paint()..strokeWidth = .25..color = (i.isEven ? Colors.white : Colors.black).withOpacity(.09));
    }
    c.restore();
    // carretes de aluminio con tres aberturas y cinta
    for (final cx in [31.0, 69.0]) {
      final o = Offset(cx, 25);
      c.drawCircle(o.translate(2, 3), 23, Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      final rect = Rect.fromCircle(center: o, radius: 23);
      c.drawCircle(o, 23, Paint()..shader = const SweepGradient(colors: [Color(0xFFEDEBE6), Color(0xFF9C9A94), Color(0xFFE2E0DA), Color(0xFF8E8C86), Color(0xFFEDEBE6)]).createShader(rect));
      c.drawCircle(o, 22.2, Paint()..style = PaintingStyle.stroke..strokeWidth = .6..color = Colors.white70);
      for (var i = 0; i < 3; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / 3;
        final p = Path()
          ..moveTo(o.dx + math.cos(a - .72) * 9, o.dy + math.sin(a - .72) * 9)
          ..lineTo(o.dx + math.cos(a - .5) * 20, o.dy + math.sin(a - .5) * 20)
          ..arcTo(Rect.fromCircle(center: o, radius: 20), a - .5, 1.0, false)
          ..lineTo(o.dx + math.cos(a + .72) * 9, o.dy + math.sin(a + .72) * 9)
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFF5B4A36));
        c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = .6..color = Colors.black54);
        c.drawArc(Rect.fromCircle(center: o, radius: 14), a - .45, .9, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0x553B2D1E));
      }
      _ball(c, o, 7.2, const Color(0xFF2B2A28));
      c.drawCircle(o, 2.6, Paint()..color = const Color(0xFFCFCDC8));
      c.drawLine(o, o.translate(-2.6, 13), Paint()..strokeWidth = 1..color = Colors.white70);
    }
    // bloque de cabezales y rodillos
    _box(c, const Rect.fromLTWH(37, 50, 26, 10), 2, const Color(0xFF1C1C1E), rad: 2);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(39, 52, 22, 3), const Radius.circular(1)), Paint()..color = const Color(0xFF3A3A3E));
    _knob(c, const Offset(24, 55), 4.4);
    _knob(c, const Offset(76, 55), 4.8);
    // palancas y botón rojo
    for (final x in [66.0, 73.0]) {
      c.drawLine(Offset(x, 66), Offset(x + 1.5, 58), Paint()..strokeWidth = 3..strokeCap = StrokeCap.round..color = const Color(0xFF2A2A2C));
      c.drawLine(Offset(x, 66), Offset(x + 1.5, 58), Paint()..strokeWidth = .8..strokeCap = StrokeCap.round..color = Colors.white54);
    }
    _ball(c, const Offset(58, 62), 2.4, const Color(0xFFD8302A));
    // vúmetros en ventana oscura
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(38, 70, 30, 12), const Radius.circular(1.5)), Paint()..color = const Color(0xFF111113));
    for (final x in [39.5, 53.5]) {
      final r = Rect.fromLTWH(x, 71.2, 13, 9.6);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1)), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFC46A), Color(0xFFE5822A)]).createShader(r));
      c.drawArc(Rect.fromLTWH(x + 1.5, 72.5, 10, 10), math.pi * 1.15, math.pi * .7, false, Paint()..style = PaintingStyle.stroke..strokeWidth = .4..color = Colors.black54);
      c.drawLine(Offset(x + 6.5, r.bottom - .6), Offset(x + 9.5, r.top + 1.6), Paint()..strokeWidth = .6..color = const Color(0xFF8A1A10));
    }
    // perillas de volumen y tomas
    _knob(c, const Offset(21, 76), 3.4);
    _knob(c, const Offset(31, 76), 3.4);
    for (final y in [70.0, 78.0]) {
      c.drawCircle(Offset(79, y), 2.3, Paint()..color = const Color(0xFF1B1B1D));
      c.drawCircle(Offset(79, y), 1.1, Paint()..color = const Color(0xFF7A7A80));
    }
    _text(c, 'FOUR TRACK STEREOPHONIC', const Offset(50, 85.2), 2.4, const Color(0xFF4A4741));
  }

  void _eq(Canvas c) {
    _ground(c, 50, 86, 44, 6);
    const silver = Color(0xFFB9BCC2);
    _box(c, const Rect.fromLTWH(6, 18, 88, 62), 8, silver, rad: 5);
    final pr = RRect.fromRectAndRadius(const Rect.fromLTWH(6, 18, 88, 62), const Radius.circular(5));
    c.drawRRect(pr, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66FFFFFF), Color(0x00FFFFFF), Color(0x33000000)]).createShader(pr.outerRect));
    // LED de encendido
    c.drawCircle(const Offset(13, 24), 1.8, Paint()..color = const Color(0xFF45E08A));
    c.drawCircle(const Offset(13, 24), 3.4, Paint()..color = const Color(0x5545E08A));
    // medidor
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(60, 21, 28, 6), const Radius.circular(2)), Paint()..color = const Color(0xFF14161C));
    for (var i = 0; i < 9; i++) {
      c.drawRect(Rect.fromLTWH(62 + i * 2.8, 22.4, 2, 3.2), Paint()..color = i < 6 ? const Color(0xFF45E08A) : (i < 8 ? const Color(0xFFE6C34A) : const Color(0xFFE0453A)));
    }
    // 5 deslizadores con LED
    const ys = [.35, .6, .45, .25, .55];
    for (var i = 0; i < 5; i++) {
      final x = 18.0 + i * 16;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.2, 36, 2.4, 32), const Radius.circular(1.2)), Paint()..color = const Color(0xFF101116));
      for (var k = 0; k < 7; k++) {
        c.drawLine(Offset(x - 5.5, 36 + k * 32 / 6), Offset(x - 3.6, 36 + k * 32 / 6), Paint()..strokeWidth = .5..color = Colors.black45);
      }
      final y = 36 + 32 * ys[i];
      final r = Rect.fromLTWH(x - 5, y - 3, 10, 6);
      c.drawRRect(RRect.fromRectAndRadius(r.translate(0, 1.2), const Radius.circular(1.6)), Paint()..color = Colors.black54);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.6)), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF2F3F5), Color(0xFF9EA2AA), Color(0xFF6E727A)]).createShader(r));
      c.drawLine(Offset(x - 4, y), Offset(x + 4, y), Paint()..strokeWidth = .6..color = Colors.black54);
      c.drawCircle(Offset(x, 73), 1.5, Paint()..color = const Color(0xFF45E08A));
    }
  }

  void _gear(Canvas c) {
    _ground(c, 50, 88, 36, 5);
    const o = Offset(50, 48);
    Path gear(double dy) {
      final p = Path();
      var first = true;
      const teeth = 10;
      for (var i = 0; i < teeth; i++) {
        final a = i * 2 * math.pi / teeth;
        final w = math.pi / teeth;
        final pts = [
          [a - w * .78, 31.0],
          [a - w * .46, 40.0],
          [a + w * .46, 40.0],
          [a + w * .78, 31.0],
        ];
        for (final q in pts) {
          final x = o.dx + math.cos(q[0]) * q[1];
          final y = o.dy + dy + math.sin(q[0]) * q[1] * .86;
          if (first) {
            first = false;
            p.moveTo(x, y);
          } else {
            p.lineTo(x, y);
          }
        }
      }
      p.close();
      return p;
    }

    // extrusión
    for (var d = 9.0; d > 0; d -= 1.0) {
      c.drawPath(gear(d), Paint()..color = Color.lerp(const Color(0xFF3B3D45), const Color(0xFF8C8F99), 1 - d / 9)!);
    }
    final top = gear(0);
    final rect = Rect.fromCircle(center: o, radius: 40);
    c.drawPath(top, Paint()..shader = const SweepGradient(colors: [Color(0xFFF2F3F7), Color(0xFF858893), Color(0xFFDADCE3), Color(0xFF6F727D), Color(0xFFF2F3F7)]).createShader(rect));
    c.drawPath(top, Paint()..style = PaintingStyle.stroke..strokeWidth = .9..color = Colors.white60);
    // anillo y agujero
    c.drawOval(Rect.fromCenter(center: o, width: 44, height: 38), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0x55000000));
    c.drawOval(Rect.fromCenter(center: o.translate(0, 1.2), width: 27, height: 23.5), Paint()..color = Colors.black);
    c.drawOval(Rect.fromCenter(center: o, width: 27, height: 23.5), Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0C0C0E), Color(0xFF3C3E46)]).createShader(Rect.fromCenter(center: o, width: 27, height: 23.5)));
    c.drawOval(Rect.fromCenter(center: o, width: 27, height: 23.5), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = _gold);
    // brillo
    c.drawArc(Rect.fromCenter(center: o, width: 56, height: 48), math.pi * 1.05, .7, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round..color = Colors.white54);
  }

  void _album(Canvas c, Rect r, Color a, Color b, double depth) {
    c.drawRect(r.translate(depth, -depth), Paint()..color = const Color(0xFFEFE8D6));
    c.drawRect(r.translate(depth * .5, -depth * .5), Paint()..color = const Color(0xFFD8D0BC));
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(1.6));
    c.drawRRect(rr, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]).createShader(r));
    c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = .7..color = Colors.white38);
  }

  void _magnifier(Canvas c, Offset lens, double r) {
    final h = Offset(lens.dx + r * .72, lens.dy + r * .72);
    final e = Offset(lens.dx + r * 1.75, lens.dy + r * 1.75);
    c.drawLine(h.translate(1.5, 2), e.translate(1.5, 2), Paint()..strokeCap = StrokeCap.round..strokeWidth = 7..color = Colors.black45);
    c.drawLine(h, e, Paint()..strokeCap = StrokeCap.round..strokeWidth = 6.4..shader = const LinearGradient(colors: [Color(0xFF4A3322), Color(0xFF1E1410)]).createShader(Rect.fromPoints(h, e)));
    final rect = Rect.fromCircle(center: lens, radius: r);
    c.drawCircle(lens, r, Paint()..shader = const RadialGradient(center: Alignment(-.4, -.4), colors: [Color(0x66DDF1FF), Color(0x2288BBE0)]).createShader(rect));
    c.drawCircle(lens, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 4.2..shader = const SweepGradient(colors: [Color(0xFFF4F5F8), Color(0xFF7C7F8A), Color(0xFFDCDEE4), Color(0xFF6A6D78), Color(0xFFF4F5F8)]).createShader(rect));
    c.drawArc(Rect.fromCircle(center: lens, radius: r * .66), math.pi * 1.05, 1.0, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..color = Colors.white70);
  }

  void _covers(Canvas c) {
    _ground(c, 46, 88, 36, 4.5);
    _album(c, const Rect.fromLTWH(26, 18, 46, 46), const Color(0xFF7A3B8C), const Color(0xFF2E1740), 3);
    _album(c, const Rect.fromLTWH(14, 26, 46, 46), const Color(0xFFD36B3A), const Color(0xFF5E2312), 3);
    _album(c, const Rect.fromLTWH(8, 34, 46, 46), const Color(0xFF3B78B5), const Color(0xFF16345A), 3);
    // dibujo de la portada del frente
    c.drawCircle(const Offset(22, 48), 5, Paint()..color = const Color(0xFFF3D36B));
    c.drawPath(Path()..moveTo(8, 80)..lineTo(26, 58)..lineTo(38, 70)..lineTo(46, 61)..lineTo(54, 72)..lineTo(54, 80)..close(), Paint()..color = const Color(0xFF1B3A63));
    _gloss(c, const Rect.fromLTWH(8, 34, 46, 46), rad: 1.6);
    _magnifier(c, const Offset(62, 62), 15);
  }

  void _search(Canvas c) {
    _ground(c, 46, 88, 36, 4.5);
    // disco de vinilo
    const o = Offset(42, 44);
    _puck(c, o, 30, 30, 0, const Color(0xFF17171A));
    _grooves(c, o, 30, 30, [.92, .8, .68, .56]);
    c.drawCircle(o, 10, Paint()..color = const Color(0xFFD6492F));
    c.drawCircle(o, 10, Paint()..style = PaintingStyle.stroke..strokeWidth = .6..color = Colors.white38);
    c.drawCircle(o, 1.8, Paint()..color = Colors.black);
    // nota musical
    final note = Paint()..color = Colors.white;
    c.drawOval(Rect.fromCenter(center: const Offset(40, 52), width: 7, height: 5), note);
    c.drawRect(const Rect.fromLTWH(43, 34, 1.4, 17.5), note);
    c.drawPath(Path()..moveTo(44.4, 34)..quadraticBezierTo(50, 38, 49, 45)..lineTo(47.6, 44)..quadraticBezierTo(48.6, 39.5, 44.4, 37.5)..close(), note);
    _magnifier(c, const Offset(66, 64), 16);
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) => old.kind != kind;
}
