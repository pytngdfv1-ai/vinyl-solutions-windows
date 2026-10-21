import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../data/koofr_settings.dart';

/// Servidor local (solo 127.0.0.1) que reenvía el audio de Koofr añadiendo las
/// credenciales. Sirve de plan B en Windows si el reproductor no envía bien las
/// cabeceras. Solo reenvía a servidores de Koofr; las credenciales nunca salen
/// hacia otros destinos.
class KoofrProxy {
  KoofrProxy._();
  static final KoofrProxy instance = KoofrProxy._();

  HttpServer? _server;
  final http.Client _client = http.Client();

  Future<void> _ensure() async {
    if (_server != null) return;
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = s;
    s.listen(_handle, onError: (_) {});
  }

  /// URL local equivalente a [url] (de Koofr) que el reproductor puede abrir.
  Future<Uri> wrap(String url) async {
    await _ensure();
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _server!.port,
      path: '/t',
      queryParameters: {'u': url},
    );
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final target = req.uri.queryParameters['u'];
      if (target == null || !KoofrSettings.isKoofrUrl(target)) {
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
        return;
      }
      final out = http.Request(req.method == 'HEAD' ? 'HEAD' : 'GET', Uri.parse(target))
        ..headers.addAll(KoofrSettings.headersFor(target) ?? const {});
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) out.headers[HttpHeaders.rangeHeader] = range;
      final res = await _client.send(out);
      req.response.statusCode = res.statusCode;
      for (final h in const [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
      ]) {
        final v = res.headers[h];
        if (v != null) req.response.headers.set(h, v);
      }
      await req.response.addStream(res.stream);
      await req.response.close();
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.badGateway;
        await req.response.close();
      } catch (_) {}
    }
  }
}
