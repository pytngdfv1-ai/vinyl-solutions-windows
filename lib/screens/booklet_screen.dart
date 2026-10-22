import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

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

/// Un PDF del álbum, mostrado dentro de la app.
class _PdfTab extends StatefulWidget {
  const _PdfTab({required this.url});

  final String url;

  @override
  State<_PdfTab> createState() => _PdfTabState();
}

class _PdfTabState extends State<_PdfTab> with AutomaticKeepAliveClientMixin {
  Uint8List? _bytes;
  String? _error;

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
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir el PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final b = _bytes;
    if (b == null) return const Center(child: CircularProgressIndicator());
    return PdfViewer.data(
      b,
      sourceName: widget.url,
      params: PdfViewerParams(
        backgroundColor: Colors.black,
        errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo abrir el PDF: $error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
