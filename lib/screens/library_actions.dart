import 'package:flutter/material.dart';

import '../data/ui_settings.dart';

import '../audio/player_service.dart';
import '../data/booklet_lite.dart';
import '../data/discogs.dart';
import '../data/library_settings.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../data/play_mode.dart';
import 'reel_screen.dart';
import 'cloud_explorer_screen.dart';
import 'stage_screen.dart';
import 'objects3d_screen.dart';

/// Abre la pantalla del disco (tocadisco, deck o cinta abierta, según el reproductor elegido).
Future<void> openStage(BuildContext context, VinylStore store, Vinyl v) {
  // Si no estaba sonando, queda anotado en qué reproductor se empezó.
  if (PlayerService.instance.nowPlaying.value?.id != v.id) {
    ViewMode.playingId = v.id;
    ViewMode.playingMode = ViewMode.current;
  }
  if (ViewMode.current == PlayMode.reel) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReelScreen(vinyl: v)));
  }
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => StageScreen(store: store, vinyl: v),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Abre lo que está sonando (chip minimizado) en el reproductor donde se empezó.
Future<void> openPlaying(BuildContext context, VinylStore store, Vinyl v) async {
  final prev = ViewMode.current;
  ViewMode.current = ViewMode.playingId == v.id ? ViewMode.playingMode : null;
  try {
    await openStage(context, store, v);
  } finally {
    ViewMode.current = prev;
  }
}

/// Agrega un disco a mano (biblioteca "Manuales").
Future<void> addDisc(BuildContext context, VinylStore store) async {
  final r = await showDialog<(String, String, int)>(
    context: context,
    builder: (_) => const AddDiscDialog(),
  );
  if (r != null) await store.add(artist: r.$1, title: r.$2, year: r.$3);
}

Future<void> showLibrarySettings(BuildContext context, {VinylStore? store}) async {
  var value = LibrarySettings.minTracks.toDouble();
  var lite = BookletLite.auto;
  var beside = BookletLite.beside;
  final token = TextEditingController(text: Discogs.token);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Ajustes de biblioteca'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mínimo de temas por álbum: ${value.round()}'),
            const SizedBox(height: 4),
            const Text(
              'Las carpetas con menos temas (singles, temas sueltos) se ignoran '
              'al sincronizar o agregar una carpeta.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            Slider(
              value: value,
              min: 1,
              max: 15,
              divisions: 14,
              label: '${value.round()}',
              onChanged: (v) => setLocal(() => value = v),
            ),
            if (store != null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.view_in_ar),
              title: const Text('Objetos 3D'),
              subtitle: const Text('Elige discos y cassettes: trasera y etiqueta', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => Objects3DScreen(store: store!))),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_open),
              title: const Text('Explorador de la nube'),
              subtitle: const Text('Mover, renombrar, borrar y crear carpetas', style: TextStyle(fontSize: 12)),
              onTap: () => openCloudExplorer(ctx),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Menú principal en 360°'),
              subtitle: const Text('Apagado = menú clásico de cajones', style: TextStyle(fontSize: 12)),
              value: UiSettings.homeRing.value,
              onChanged: (x) {
                UiSettings.setHome(x);
                setLocal(() {});
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Dentro de cada biblioteca en 360°'),
              subtitle: const Text('Apagado = caja de discos clásica', style: TextStyle(fontSize: 12)),
              value: UiSettings.libRing.value,
              onChanged: (x) {
                UiSettings.setLib(x);
                setLocal(() {});
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo ahorro'),
              subtitle: const Text(
                'Apaga brillo (shader), sensores, desgaste, sombras dinámicas y animaciones 3D.',
                style: TextStyle(fontSize: 12),
              ),
              value: UiSettings.powerSave.value,
              onChanged: (x) {
                UiSettings.setPowerSave(x);
                setLocal(() {});
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Animaciones al abrir'),
              subtitle: const Text('El disco sale de la funda / el cassette cae al casetero. Toca para saltar.',
                  style: TextStyle(fontSize: 12)),
              value: UiSettings.animations.value,
              onChanged: (x) {
                UiSettings.setAnimations(x);
                setLocal(() {});
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Folletos PDF como imágenes livianas'),
              subtitle: const Text(
                'Al importar, convierte cada PDF a WebP (~1600 px). El PDF original no se borra.',
                style: TextStyle(fontSize: 12),
              ),
              value: lite,
              onChanged: (x) => setLocal(() => lite = x),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Guardar la liviana junto al PDF'),
              subtitle: const Text(
                'Sube las páginas a una carpeta "Libreto liviano" al lado del PDF (nube o equipo).',
                style: TextStyle(fontSize: 12),
              ),
              value: beside,
              onChanged: (x) => setLocal(() => beside = x),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: token,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token de Discogs (opcional)',
                helperText: 'Solo para buscar más portadas. Se guarda cifrado en el equipo.',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) {
    await LibrarySettings.save(value.round());
    await Discogs.save(token.text);
    await BookletLite.setAuto(lite);
    await BookletLite.setBeside(beside);
  }
  token.dispose();
}

Future<void> confirmClearLibrary(BuildContext context, VinylStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Borrar biblioteca'),
      content: const Text(
        'Se borrarán todos los discos de la app. Tus archivos en Koofr no se tocan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await PlayerService.instance.stop();
    await store.clearAll();
  }
}


class AddDiscDialog extends StatefulWidget {
  const AddDiscDialog();

  @override
  State<AddDiscDialog> createState() => AddDiscDialogState();
}

class AddDiscDialogState extends State<AddDiscDialog> {
  final _artist = TextEditingController();
  final _title = TextEditingController();
  final _year = TextEditingController();

  @override
  void dispose() {
    _artist.dispose();
    _title.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar disco'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _artist, decoration: const InputDecoration(labelText: 'Artista')),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
          TextField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Año'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final a = _artist.text.trim();
            final t = _title.text.trim();
            if (a.isEmpty || t.isEmpty) return;
            Navigator.of(context).pop((a, t, int.tryParse(_year.text.trim()) ?? DateTime.now().year));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
