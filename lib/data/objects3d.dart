import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vinyl.dart';
import '../widgets/cassette_3d.dart' show backCoverOf;
import 'koofr_client.dart';
import 'koofr_settings.dart';
import 'thumb_cache.dart';

/// Objetos 3D por disco/cassette: imágenes generadas (trasera, etiqueta) que se guardan
/// en el equipo y en la nube (carpeta `_3d`), y se leen en vez de regenerarse.
class Objects3D {
  static const folder = '_3d';
  static const kinds = ['back_disc', 'back_tape', 'label_disc', 'label_tape'];

  /// Ids elegidos en Ajustes.
  static final ValueNotifier<Set<String>> selected = ValueNotifier<Set<String>>({});

  /// Imágenes ya generadas: id -> {tipo -> ruta}. Sirve para consultar sin esperar.
  static final ValueNotifier<int> version = ValueNotifier<int>(0);
  static final Map<String, Map<String, String>> _paths = {};
  static Directory? _dir;
  static bool cancel = false;

  static Future<Directory> _root() async {
    final d = _dir;
    if (d != null) return d;
    final base = await getApplicationSupportDirectory();
    final n = Directory('${base.path}/objects3d');
    await n.create(recursive: true);
    return _dir = n;
  }

  static String hash(String s) {
    var a = 0x811c9dc5;
    var b = 0x811c9dc5;
    final u = s.codeUnits;
    for (var i = 0; i < u.length; i++) {
      a = ((a ^ u[i]) * 0x01000193) & 0xFFFFFFFF;
      b = ((b ^ u[u.length - 1 - i]) * 0x01000193) & 0xFFFFFFFF;
    }
    return '${a.toRadixString(16)}${b.toRadixString(16)}';
  }

  static String _file(String id, String kind) => '${hash(id)}_$kind.${kind.startsWith('back') ? 'jpg' : 'png'}';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      selected.value = (p.getStringList('obj3d_sel') ?? const []).toSet();
    } catch (_) {}
    try {
      final d = await _root();
      final byHash = <String, Map<String, String>>{};
      await for (final e in d.list()) {
        if (e is! File) continue;
        final n = e.uri.pathSegments.last;
        final i = n.indexOf('_');
        if (i < 0) continue;
        final k = n.substring(i + 1).split('.').first;
        if (!kinds.contains(k)) continue;
        (byHash[n.substring(0, i)] ??= {})[k] = Uri.file(e.path).toString();
      }
      _hashPaths
        ..clear()
        ..addAll(byHash);
    } catch (_) {}
  }

  static final Map<String, Map<String, String>> _hashPaths = {};

  /// URL local (file://) de una imagen generada, o null.
  static String? pathOf(String id, String kind) => _hashPaths[hash(id)]?[kind];

  static bool has(String id) => _hashPaths[hash(id)]?['back_disc'] != null;

  static Future<void> setSelected(Set<String> ids) async {
    selected.value = ids;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('obj3d_sel', ids.toList());
    } catch (_) {}
  }

  /// Bytes de una portada (archivo local, o descarga cacheada).
  static Future<ui.Image?> _image(String? url, {int width = 700}) async {
    if (url == null || url.isEmpty) return null;
    try {
      final File? f = url.startsWith('file:') ? File(Uri.parse(url).toFilePath()) : await ThumbCache.get(url);
      if (f == null) return null;
      final codec = await ui.instantiateImageCodec(await f.readAsBytes(), targetWidth: width);
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  static void _cover(Canvas c, ui.Image im, Rect dst) {
    final s = math.max(dst.width / im.width, dst.height / im.height);
    final w = dst.width / s, h = dst.height / s;
    final src = Rect.fromLTWH((im.width - w) / 2, (im.height - h) / 2, w, h);
    c.drawImageRect(im, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  static void _text(Canvas c, String t, Offset o, double maxW,
      {double size = 20, FontWeight w = FontWeight.w400, Color color = const Color(0xFFFFFFFF), int lines = 1, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: size, fontWeight: w, color: color, height: 1.25, shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 4)])),
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
      textAlign: align,
    )..layout(maxWidth: maxW);
    tp.paint(c, o);
  }

  /// Trasera: la real (contraportada guardada) o una genérica con la portada difuminada y los temas.
  static Future<ui.Image> _back(Vinyl v, ui.Image? cover, ui.Image? real, double w, double h) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final r = Rect.fromLTWH(0, 0, w, h);
    final hue = HSLColor.fromAHSL(1, v.hue % 360, .45, .22).toColor();
    c.drawRect(r, Paint()..color = hue);
    final bg = real ?? cover;
    if (bg != null) {
      c.saveLayer(r, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.clamp));
      _cover(c, bg, r.inflate(40));
      c.restore();
    }
    c.drawRect(r, Paint()..color = Color(real != null ? 0x66000000 : 0x99000000));
    if (real != null) {
      final s = math.min(w / real.width, h / real.height);
      final dw = real.width * s, dh = real.height * s;
      c.drawImageRect(real, Rect.fromLTWH(0, 0, real.width.toDouble(), real.height.toDouble()),
          Rect.fromLTWH((w - dw) / 2, (h - dh) / 2, dw, dh), Paint()..filterQuality = FilterQuality.medium);
    } else {
      final pad = w * .07;
      final title = v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title;
      var y = pad;
      if (cover != null) {
        final sz = w * .24;
        final rr = RRect.fromRectAndRadius(Rect.fromLTWH(pad, y, sz, sz), const Radius.circular(6));
        c.save();
        c.clipRRect(rr);
        _cover(c, cover, rr.outerRect);
        c.restore();
        _text(c, v.artist.toUpperCase(), Offset(pad * 2 + sz, y), w - sz - pad * 3, size: w * .045, w: FontWeight.w800, lines: 2);
        _text(c, title, Offset(pad * 2 + sz, y + w * .12), w - sz - pad * 3, size: w * .05, lines: 3, color: const Color(0xCCFFFFFF));
        y += sz + pad;
      } else {
        _text(c, v.artist.toUpperCase(), Offset(pad, y), w - pad * 2, size: w * .055, w: FontWeight.w800);
        _text(c, title, Offset(pad, y + w * .08), w - pad * 2, size: w * .05, lines: 2, color: const Color(0xCCFFFFFF));
        y += w * .22;
      }
      c.drawLine(Offset(pad, y), Offset(w - pad, y), Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 1.5);
      y += pad * .6;
      final fs = w * .042;
      final rows = math.max(1, ((h - y - pad) / (fs * 1.55)).floor());
      final n = math.min(v.tracks.length, rows);
      for (var i = 0; i < n; i++) {
        final more = i == n - 1 && v.tracks.length > n;
        _text(c, more ? '… +${v.tracks.length - n + 1} más' : '${i + 1}. ${v.tracks[i]}', Offset(pad, y + i * fs * 1.55), w - pad * 2,
            size: fs, color: const Color(0xDDFFFFFF));
      }
    }
    return rec.endRecording().toImage(w.round(), h.round());
  }

  static Future<ui.Image> _labelDisc(Vinyl v, ui.Image? cover, double s) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final o = Offset(s / 2, s / 2);
    final hue = HSLColor.fromAHSL(1, v.hue % 360, .6, .42).toColor();
    c.drawCircle(o, s / 2, Paint()..color = hue);
    if (cover != null) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: s * .4)));
      _cover(c, cover, Rect.fromCircle(center: o, radius: s * .4));
      c.restore();
      c.drawCircle(o, s * .4, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0x55000000));
    }
    c.drawCircle(o, s * .045, Paint()..color = const Color(0xFF0B0B0D));
    c.drawCircle(o, s * .06, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x66FFFFFF));
    return rec.endRecording().toImage(s.round(), s.round());
  }

  static Future<ui.Image> _labelTape(Vinyl v, double w, double h) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final hue = HSLColor.fromAHSL(1, v.hue % 360, .5, .5).toColor();
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(h * .06));
    c.drawRRect(r, Paint()..color = const Color(0xFFF1EAD6));
    c.drawRect(Rect.fromLTWH(0, 0, w, h * .2), Paint()..color = hue);
    for (var i = 0; i < 4; i++) {
      final y = h * (.42 + i * .14);
      c.drawLine(Offset(w * .06, y), Offset(w * .94, y), Paint()..color = const Color(0x553B6EA8)..strokeWidth = 1.5);
    }
    final title = v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title;
    _text(c, 'A', Offset(w * .05, h * .02), w * .1, size: h * .16, w: FontWeight.w900);
    _text(c, v.artist, Offset(w * .06, h * .27), w * .88, size: h * .13, w: FontWeight.w700, color: const Color(0xFF1F2A44));
    _text(c, title, Offset(w * .06, h * .43), w * .88, size: h * .12, lines: 2, color: const Color(0xFF1F2A44));
    return rec.endRecording().toImage(w.round(), h.round());
  }

  /// Imágenes para el visor 3D (usa lo generado si existe; si no, las arma al vuelo).
  static Future<ui.Image?> loadImage(String? url, {int width = 700}) => _image(url, width: width);

  static Future<ui.Image> backImage(Vinyl v, {required bool tape}) async {
    final gen = backCoverOf(v) != null ? null : pathOf(v.id, tape ? 'back_tape' : 'back_disc');
    if (gen != null) {
      final im = await _image(gen, width: 700);
      if (im != null) return im;
    }
    final cover = await _image(v.coverUrl);
    final real = await _image(backCoverOf(v));
    return _back(v, cover, real, tape ? 460 : 560, tape ? 730 : 560);
  }

  static Future<ui.Image> labelImage(Vinyl v, {required bool tape}) async {
    final gen = pathOf(v.id, tape ? 'label_tape' : 'label_disc');
    if (gen != null) {
      final im = await _image(gen, width: tape ? 520 : 360);
      if (im != null) return im;
    }
    return tape ? _labelTape(v, 520, 300) : _labelDisc(v, await _image(v.coverUrl), 360);
  }

  static Future<Uint8List> _jpg(ui.Image im) async {
    final bd = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return compute(_encodeJpg, (bd.buffer.asUint8List(), im.width, im.height));
  }

  static Future<Uint8List> _png(ui.Image im) async => (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

  /// Genera y guarda (equipo + nube) las imágenes de [v]. Devuelve true si quedó completo.
  static Future<bool> generate(Vinyl v) async {
    final cover = await _image(v.coverUrl);
    final back = backCoverOf(v);
    final real = await _image(back);
    final out = <String, Uint8List>{
      'back_disc': await _jpg(await _back(v, cover, real, 560, 560)),
      'back_tape': await _jpg(await _back(v, cover, real, 460, 730)),
      'label_disc': await _png(await _labelDisc(v, cover, 360)),
      'label_tape': await _png(await _labelTape(v, 520, 300)),
    };
    final d = await _root();
    final h = hash(v.id);
    for (final e in out.entries) {
      final f = File('${d.path}/${_file(v.id, e.key)}');
      await f.writeAsBytes(e.value, flush: true);
      (_hashPaths[h] ??= {})[e.key] = Uri.file(f.path).toString();
    }
    version.value++;
    try {
      await _upload(v, out);
    } catch (_) {}
    return true;
  }

  static KoofrClient? _client(Vinyl v) {
    if (v.trackUrls.isEmpty) return null;
    final a = KoofrAccounts.byUrl(v.trackUrls.first);
    return a == null ? null : KoofrClient(a);
  }

  static Future<void> _upload(Vinyl v, Map<String, Uint8List> files) async {
    final cl = _client(v);
    if (cl == null) return;
    await cl.ensureDir([folder]);
    for (final e in files.entries) {
      await cl.putBytes([folder], _file(v.id, e.key), e.value,
          type: e.key.startsWith('back') ? 'image/jpeg' : 'image/png');
    }
  }

  /// Al cargar la biblioteca: lo elegido que falte en el equipo se baja de la nube
  /// (sin regenerar). Devuelve cuántos faltan por generar.
  static Future<int> sync(List<Vinyl> all) async {
    final sel = selected.value;
    final pending = <Vinyl>[for (final v in all) if (sel.contains(v.id) && !has(v.id)) v];
    if (pending.isEmpty) return 0;
    final byAcct = <String, List<Vinyl>>{};
    for (final v in pending) {
      final a = v.trackUrls.isEmpty ? null : KoofrAccounts.byUrl(v.trackUrls.first);
      if (a != null) (byAcct[a.id] ??= []).add(v);
    }
    final d = await _root();
    for (final g in byAcct.values) {
      try {
        final cl = _client(g.first)!;
        final names = {for (final e in await cl.browse([folder])) if (!e.isDir) e.name};
        for (final v in g) {
          for (final k in kinds) {
            final n = _file(v.id, k);
            if (!names.contains(n)) continue;
            final url = cl.urlOf([folder, n]);
            final f = File('${d.path}/$n');
            final bytes = await ThumbCache.rawBytes(url);
            if (bytes == null) continue;
            await f.writeAsBytes(bytes, flush: true);
            (_hashPaths[hash(v.id)] ??= {})[k] = Uri.file(f.path).toString();
          }
        }
      } catch (_) {}
    }
    version.value++;
    return pending.where((v) => !has(v.id)).length;
  }

  /// Quita lo generado de ítems que ya no están elegidos (equipo y nube).
  static Future<void> remove(Vinyl v) async {
    final d = await _root();
    for (final k in kinds) {
      try {
        await File('${d.path}/${_file(v.id, k)}').delete();
      } catch (_) {}
    }
    _hashPaths.remove(hash(v.id));
    try {
      final cl = _client(v);
      if (cl != null) {
        for (final k in kinds) {
          await cl.remove([folder, _file(v.id, k)], isDir: false);
        }
      }
    } catch (_) {}
    version.value++;
  }

  /// Espacio usado en el equipo (bytes).
  static Future<int> size() async {
    var n = 0;
    final d = await _root();
    await for (final e in d.list()) {
      if (e is File) n += await e.length();
    }
    return n;
  }
}

Uint8List _encodeJpg((Uint8List, int, int) a) {
  final im = img.Image.fromBytes(width: a.$2, height: a.$3, bytes: a.$1.buffer, numChannels: 4);
  return Uint8List.fromList(img.encodeJpg(im, quality: 84));
}
