import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

import '../data/fetch_bytes.dart';
import '../models/vinyl.dart';
import '../widgets/cover_art.dart';

/// Libreto del álbum: páginas (imágenes) y PDFs, todo dentro de la app.
class BookletScreen extends StatelessWidget {
  const BookletScreen({super.key, required this.vinyl});

  final Vinyl vinyl;

  static String _name(String url) {
    var n = Uri.parse(url).pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'PDF');
    try {
      n = Uri.decodeComponent(n);
    } catch (_) {}
    return n.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <String>[
      if (vinyl.booklet.isNotEmpty) 'Imágenes (${vinyl.booklet.length})',
      for (final p in vinyl.pdfs) _name(p),
    ];
    final views = <Widget>[
      if (vinyl.booklet.isNotEmpty) _Pages(urls: vinyl.booklet),
      for (final p in vinyl.pdfs) _PdfTab(url: p),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text('Libreto · ${vinyl.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: tabs.length > 1
              ? TabBar(isScrollable: true, tabs: [for (final t in tabs) Tab(text: t)])
              : null,
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: views,
        ),
      ),
    );
  }
}

/// Imágenes del libreto: desliza para cambiar de página, pellizca para ampliar.
class _Pages extends StatefulWidget {
  const _Pages({required this.urls});

  final List<String> urls;

  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  final PageController _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int d) {
    final t = (_page + d).clamp(0, widget.urls.length - 1);
    _pc.animateToPage(t, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    const broken = Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48));
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
      children: [
        PageView.builder(
          controller: _pc,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: buildCoverImage(
                widget.urls[i],
                cacheWidth: 1600,
                fit: BoxFit.contain,
                fallback: broken,
              ),
            ),
          ),
        ),
        if (_page > 0)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: 'Página anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _go(-1),
              ),
            ),
          ),
        if (_page < widget.urls.length - 1)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: 'Página siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _go(1),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('${_page + 1} / ${widget.urls.length}'),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

/// Un PDF del álbum, mostrado dentro de la app. Renderiza cada página como
/// imagen (funciona igual en Windows) y muestra el error real si algo falla.
class _PdfTab extends StatefulWidget {
  const _PdfTab({required this.url});

  final String url;

  @override
  State<_PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<_PdfTab> with AutomaticKeepAliveClientMixin {
  PdfDocument? _doc;
  String? _error;
  final Map<int, Future<Uint8List>> _pages = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await fetchBytes(widget.url);
      final doc = await PdfDocument.openData(bytes);
      if (!mounted) {
        await doc.close();
        return;
      }
      setState(() => _doc = doc);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir el PDF: $e');
    }
  }

  /// Renderiza la página (1..n) a ~1400 px de ancho.
  Future<Uint8List> _render(int n) {
    return _pages.putIfAbsent(n, () async {
      final page = await _doc!.getPage(n);
      try {
        const targetW = 1400.0;
        final h = targetW * page.height / page.width;
        final img = await page.render(
          width: targetW,
          height: h,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        if (img == null) throw Exception('No se pudo dibujar la página $n');
        return img.bytes;
      } finally {
        await page.close();
      }
    });
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final d = _doc;
    if (d == null) return const Center(child: CircularProgressIndicator());
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: d.pagesCount,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: FutureBuilder<Uint8List>(
            future: _render(i + 1),
            builder: (_, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText('Página ${i + 1}: ${snap.error}',
                      style: const TextStyle(color: Colors.redAccent)),
                );
              }
              if (!snap.hasData) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Image.memory(snap.data!, fit: BoxFit.fitWidth, gaplessPlayback: true);
            },
          ),
        ),
      ),
    );
  }
}
