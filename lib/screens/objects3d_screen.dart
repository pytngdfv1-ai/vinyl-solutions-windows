import 'package:flutter/material.dart';

import '../data/objects3d.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../widgets/cover_art.dart';

/// Ajustes → Objetos 3D: elige qué discos y cassettes tienen objeto (trasera, etiqueta).
class Objects3DScreen extends StatefulWidget {
  const Objects3DScreen({super.key, required this.store});
  final VinylStore store;

  @override
  State<Objects3DScreen> createState() => _Objects3DScreenState();
}

class _Objects3DScreenState extends State<Objects3DScreen> {
  late Set<String> _sel = {...Objects3D.selected.value};
  bool _busy = false;
  int _done = 0, _total = 0;
  String _msg = '';
  int _bytes = 0;
  String _q = '';

  List<Vinyl> get _all => [for (final v in widget.store.items) if (!v.isDivider) v];

  @override
  void initState() {
    super.initState();
    _size();
  }

  Future<void> _size() async {
    final b = await Objects3D.size();
    if (mounted) setState(() => _bytes = b);
  }

  Future<void> _run() async {
    final list = _all;
    final todo = [for (final v in list) if (_sel.contains(v.id) && !Objects3D.has(v.id)) v];
    final drop = [for (final v in list) if (!_sel.contains(v.id) && Objects3D.has(v.id)) v];
    await Objects3D.setSelected(_sel);
    Objects3D.cancel = false;
    setState(() {
      _busy = true;
      _done = 0;
      _total = todo.length + drop.length;
      _msg = '';
    });
    for (final v in drop) {
      if (Objects3D.cancel) break;
      await Objects3D.remove(v);
      if (mounted) setState(() => _done++);
    }
    for (final v in todo) {
      if (Objects3D.cancel) break;
      if (mounted) setState(() => _msg = v.title);
      try {
        await Objects3D.generate(v);
      } catch (_) {}
      if (mounted) setState(() => _done++);
    }
    await _size();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final q = _q.toLowerCase();
    final shown = [for (final v in all) if (q.isEmpty || '${v.artist} ${v.title}'.toLowerCase().contains(q)) v];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetos 3D'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => setState(() => _sel = _sel.length == all.length ? {} : {for (final v in all) v.id}),
            child: Text(_sel.length == all.length ? 'Ninguno' : 'Todos'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Buscar', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (t) => setState(() => _q = t),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text('${_sel.length} elegidos · ${(_bytes / 1048576).toStringAsFixed(1)} MB',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text('$_done/$_total · $_msg', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                      TextButton(onPressed: () => Objects3D.cancel = true, child: const Text('Cancelar')),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final v = shown[i];
                final on = _sel.contains(v.id);
                return CheckboxListTile(
                  dense: true,
                  value: on,
                  onChanged: _busy ? null : (x) => setState(() => x == true ? _sel.add(v.id) : _sel.remove(v.id)),
                  secondary: SizedBox(width: 40, height: 40, child: CoverArt(vinyl: v, radius: 4)),
                  title: Text(v.single && v.tracks.isNotEmpty ? v.tracks.first : v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${v.artist}${Objects3D.has(v.id) ? ' · listo' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _run,
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('Generar y guardar en la nube'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
