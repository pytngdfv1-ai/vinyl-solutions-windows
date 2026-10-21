import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/library_settings.dart';
import '../data/local_scanner.dart';
import '../data/vinyl_store.dart';

/// Agrega a la biblioteca una carpeta de música del equipo.
class LocalScreen extends StatefulWidget {
  const LocalScreen({super.key, required this.store});

  final VinylStore store;

  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen> {
  bool _busy = false;
  String _status = '';

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _status = 'Eligiendo carpeta…';
    });
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) {
        setState(() => _status = '');
        return;
      }
      setState(() => _status = 'Leyendo carpeta…');
      final scanner = LocalScanner();
      final result = await scanner.scan(
        path,
        onProgress: (n) {
          if (mounted) setState(() => _status = 'Leyendo $n…');
        },
      );
      await widget.store.addAlbums(result.albums);
      if (!mounted) return;
      setState(() => _status = result.albums.isEmpty
          ? 'No encontré álbumes completos. ${scanner.diagnostic}\n'
              '${result.summary(LibrarySettings.minTracks)}'
          : result.summary(LibrarySettings.minTracks));
    } on LocalException catch (e) {
      if (mounted) setState(() => _status = e.message);
    } catch (e) {
      if (mounted) setState(() => _status = 'No se pudo leer la carpeta: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carpeta local')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Elige una carpeta de tu equipo con tu música.\n'
            'Cada carpeta con audio es un álbum y su carpeta padre es el artista. '
            'Agrega cover.jpg en el álbum para la carátula.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: const Text('Elegir carpeta'),
            onPressed: _busy ? null : _pick,
          ),
          const SizedBox(height: 12),
          Text(_status),
        ],
      ),
    );
  }
}
