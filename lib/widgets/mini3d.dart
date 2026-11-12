import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Motor 3D mínimo: caras con textura, perspectiva, giro libre, descarte de caras traseras,
/// orden por profundidad e iluminación simple. Sin dependencias.
class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;
  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
}

class Face3 {
  Face3(this.pts, this.normal, {this.image, this.uv, this.color = const Color(0xFF1B1B20)});
  final List<V3> pts;
  final V3 normal;
  final ui.Image? image;
  final List<Offset>? uv; // coordenadas en píxeles de la imagen
  final Color color;
}

/// Subrectángulo de [im] con la proporción [aspect] (ancho/alto), centrado, como 4 uv: TL, TR, BR, BL.
List<Offset> coverUv(ui.Image im, double aspect) {
  final iw = im.width.toDouble(), ih = im.height.toDouble();
  var w = iw, h = iw / aspect;
  if (h > ih) {
    h = ih;
    w = ih * aspect;
  }
  final l = (iw - w) / 2, t = (ih - h) / 2;
  return [Offset(l, t), Offset(l + w, t), Offset(l + w, t + h), Offset(l, t + h)];
}

/// Caja de ancho [w], alto [h] y fondo [d] centrada en [c]. Frente hacia la cámara (z negativo).
List<Face3> box3(V3 c, double w, double h, double d,
    {ui.Image? front, ui.Image? back, List<Offset>? frontUv, List<Offset>? backUv, Color side = const Color(0xFF1B1B20), Color? frontColor, Color? backColor}) {
  final x = w / 2, y = h / 2, z = d / 2;
  V3 p(double a, double b, double e) => V3(c.x + a, c.y + b, c.z + e);
  List<Offset> full(ui.Image? i) => i == null ? const [] : [Offset.zero, Offset(i.width.toDouble(), 0), Offset(i.width.toDouble(), i.height.toDouble()), Offset(0, i.height.toDouble())];
  return [
    Face3([p(-x, -y, -z), p(x, -y, -z), p(x, y, -z), p(-x, y, -z)], const V3(0, 0, -1),
        image: front, uv: front == null ? null : (frontUv ?? full(front)), color: frontColor ?? side),
    Face3([p(x, -y, z), p(-x, -y, z), p(-x, y, z), p(x, y, z)], const V3(0, 0, 1),
        image: back, uv: back == null ? null : (backUv ?? full(back)), color: backColor ?? side),
    Face3([p(-x, -y, z), p(-x, -y, -z), p(-x, y, -z), p(-x, y, z)], const V3(-1, 0, 0), color: side),
    Face3([p(x, -y, -z), p(x, -y, z), p(x, y, z), p(x, y, -z)], const V3(1, 0, 0), color: side),
    Face3([p(-x, -y, z), p(x, -y, z), p(x, -y, -z), p(-x, -y, -z)], const V3(0, -1, 0), color: side),
    Face3([p(-x, y, -z), p(x, y, -z), p(x, y, z), p(-x, y, z)], const V3(0, 1, 0), color: side),
  ];
}

/// Disco (cilindro fino): [face] se ve de frente y, espejada, por detrás.
List<Face3> disc3(V3 c, double r, double t, ui.Image? face, {int n = 44, Color side = const Color(0xFF0A0A0C)}) {
  final out = <Face3>[];
  final fw = face?.width.toDouble() ?? 1, fh = face?.height.toDouble() ?? 1;
  final front = <V3>[], back = <V3>[], uvF = <Offset>[], uvB = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = i * 2 * math.pi / n;
    final ca = math.cos(a), sa = math.sin(a);
    front.add(V3(c.x + ca * r, c.y + sa * r, c.z - t / 2));
    back.add(V3(c.x + ca * r, c.y + sa * r, c.z + t / 2));
    uvF.add(Offset(fw / 2 + ca * fw / 2, fh / 2 + sa * fh / 2));
    uvB.add(Offset(fw / 2 - ca * fw / 2, fh / 2 + sa * fh / 2));
  }
  out.add(Face3(front, const V3(0, 0, -1), image: face, uv: face == null ? null : uvF, color: side));
  out.add(Face3(back.reversed.toList(), const V3(0, 0, 1), image: face, uv: face == null ? null : uvB.reversed.toList(), color: side));
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n;
    final m = (i + .5) * 2 * math.pi / n;
    out.add(Face3([front[i], front[j], back[j], back[i]], V3(math.cos(m), math.sin(m), 0), color: side));
  }
  return out;
}

class Scene3DPainter extends CustomPainter {
  Scene3DPainter(this.faces, this.yaw, this.pitch, {this.scale = .3, this.shift = Offset.zero, this.pan = Offset.zero});
  final List<Face3> faces;
  final double yaw, pitch, scale;
  final Offset shift;
  final Offset pan; // desplazamiento en píxeles

  static const _cam = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = math.cos(yaw), sy = math.sin(yaw), cp = math.cos(pitch), sp = math.sin(pitch);
    V3 rot(V3 p) {
      final x = p.x * cy + p.z * sy;
      final z0 = -p.x * sy + p.z * cy;
      return V3(x, p.y * cp - z0 * sp, p.y * sp + z0 * cp);
    }

    final k = size.shortestSide * scale;
    Offset proj(V3 p) {
      final s = _cam / (_cam + p.z);
      return Offset(size.width / 2 + pan.dx + shift.dx * k + p.x * s * k, size.height / 2 + pan.dy + shift.dy * k + p.y * s * k);
    }

    // sombra
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width / 2 + pan.dx, size.height * .5 + pan.dy + k * 1.25), width: k * 2.6, height: k * .3),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    final vis = <(double, Face3, List<V3>, double)>[];
    for (final f in faces) {
      final rp = [for (final p in f.pts) rot(p)];
      var cx = 0.0, cyy = 0.0, cz = 0.0;
      for (final p in rp) {
        cx += p.x;
        cyy += p.y;
        cz += p.z;
      }
      cx /= rp.length;
      cyy /= rp.length;
      cz /= rp.length;
      final n = rot(f.normal);
      final dot = n.x * cx + n.y * cyy + n.z * (cz + _cam);
      if (dot >= 0) continue;
      final lit = (n.x * .2 + n.y * .3 + n.z * -.93).clamp(0.0, 1.0);
      vis.add((cz, f, rp, .5 + .5 * lit));
    }
    vis.sort((a, b) => b.$1.compareTo(a.$1));

    for (final (_, f, rp, b) in vis) {
      final pts = [for (final p in rp) proj(p)];
      final path = Path()..addPolygon(pts, true);
      final img = f.image;
      if (img != null && f.uv != null) {
        final pos = Float32List(pts.length * 2), tex = Float32List(pts.length * 2);
        for (var i = 0; i < pts.length; i++) {
          pos[i * 2] = pts[i].dx;
          pos[i * 2 + 1] = pts[i].dy;
          tex[i * 2] = f.uv![i].dx;
          tex[i * 2 + 1] = f.uv![i].dy;
        }
        final idx = <int>[];
        for (var i = 1; i < pts.length - 1; i++) {
          idx.addAll([0, i, i + 1]);
        }
        final shader = ui.ImageShader(img, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage, filterQuality: FilterQuality.medium);
        canvas.drawVertices(
          ui.Vertices.raw(ui.VertexMode.triangles, pos, textureCoordinates: tex, indices: Uint16List.fromList(idx)),
          BlendMode.srcOver,
          Paint()
            ..shader = shader
            ..isAntiAlias = true,
        );
        canvas.drawPath(path, Paint()..color = Color.fromRGBO(0, 0, 0, (1 - b).clamp(0.0, .6)));
      } else {
        canvas.drawPath(path, Paint()..color = Color.lerp(f.color, Colors.black, (1 - b).clamp(0.0, .6))!);
        canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = .6..color = const Color(0x22FFFFFF));
      }
    }
  }

  @override
  bool shouldRepaint(covariant Scene3DPainter o) => true;
}
