import 'package:flutter/material.dart';

import '../data/koofr_client.dart';
import '../data/koofr_settings.dart';
import '../theme.dart';

/// Abre el explorador de la nube (elige la cuenta si hay más de una).
Future<void> openCloudExplorer(BuildContext context) async {
  final accts = KoofrAccounts.list;
  if (accts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primero agrega una cuenta de la nube')));
    return;
  }
  KoofrSettings? a = accts.first;
  if (accts.length > 1) {
    a = await showDialog<KoofrSettings>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('¿Qué nube?'),
        children: [
          for (final x in accts) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, x), child: Text(x.name)),
        ],
      ),
    );
  }
  if (a == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CloudExplorerScreen(account: a!)));
}

/// Explorador de archivos de la nube: mover, renombrar, borrar y crear carpetas.
class CloudExplorerScreen extends StatefulWidget {
  const CloudExplorerScreen({super.key, required this.account});
  final KoofrSettings account;

  @override
  State<CloudExplorerScreen> createState() => _CloudExplorerScreenState();
}

class _CloudExplorerScreenState extends State<CloudExplorerScreen> {
  late final KoofrClient _c = KoofrClient(widget.account);
  List<String> _path = [];
  List<CloudEntry> _items = [];
  final Set<String> _sel = {};
  bool _loading = true;
  String? _error;
  String _progress = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sel.clear();
    });
    try {
      final r = await _c.browse(_path);
      if (!mounted) return;
      setState(() {
        _items = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  String _size(int b) {
    if (b <= 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(2)} GB';
  }

  List<String> _p(String name) => [..._path, name];

  Future<void> _run(Future<void> Function() job, String done) async {
    try {
      await job();
      _msg('$done. Sincroniza la biblioteca para ver los cambios.');
    } catch (e) {
      _msg('$e');
    }
    await _load();
  }

  Future<bool> _confirm(String title, String body, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
        ],
      ),
    );
    return r == true;
  }

  Future<String?> _ask(String title, {String initial = ''}) async {
    final t = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: t, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, t.text), child: const Text('Aceptar')),
        ],
      ),
    );
    t.dispose();
    return r?.trim().isEmpty == true ? null : r?.trim();
  }

  Future<void> _newFolder() async {
    final n = await _ask('Nueva carpeta');
    if (n == null) return;
    await _run(() => _c.ensureDir(_p(KoofrClient.cleanName(n))), 'Carpeta creada');
  }

  Future<void> _rename(CloudEntry e) async {
    final n = await _ask('Renombrar', initial: e.name);
    if (n == null || n == e.name) return;
    await _run(() => _c.rename(_p(e.name), n, isDir: e.isDir), 'Renombrado');
  }

  Future<void> _delete(List<CloudEntry> es) async {
    final ok = await _confirm(
      'Borrar',
      'Se borrará ${es.length == 1 ? '"${es.first.name}"' : '${es.length} elementos'} de la nube. No se puede deshacer.',
      'Borrar',
    );
    if (!ok) return;
    await _run(() async {
      for (final e in es) {
        await _c.remove(_p(e.name), isDir: e.isDir);
      }
    }, 'Borrado');
  }

  Future<void> _move(List<CloudEntry> es) async {
    final dest = await _pickFolder();
    if (dest == null) return;
    await _run(() async {
      for (final e in es) {
        await _c.moveInto(_p(e.name), dest, isDir: e.isDir);
      }
    }, 'Movido');
  }

  /// Elegir carpeta destino navegando por la nube.
  Future<List<String>?> _pickFolder() {
    var cur = <String>[..._path];
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: Text('Mover a: /${cur.join('/')}', style: const TextStyle(fontSize: 14)),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: FutureBuilder<List<CloudEntry>>(
              key: ValueKey(cur.join('/')),
              future: _c.browse(cur),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final dirs = snap.data!.where((e) => e.isDir).toList();
                return ListView(
                  children: [
                    if (cur.isNotEmpty)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.arrow_upward),
                        title: const Text('Subir un nivel'),
                        onTap: () => setL(() => cur = cur.sublist(0, cur.length - 1)),
                      ),
                    for (final d in dirs)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.folder, color: AppColors.gold),
                        title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => setL(() => cur = [...cur, d.name]),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, cur), child: const Text('Mover aquí')),
          ],
        ),
      ),
    );
  }

  Future<void> _findEmpty() async {
    setState(() {
      _loading = true;
      _progress = '';
    });
    List<List<String>> found;
    try {
      found = await _c.foldersWithoutAudio(_path, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
    } catch (e) {
      _msg('$e');
      await _load();
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (found.isEmpty) {
      _msg('No hay carpetas sin música aquí');
      return;
    }
    final chosen = {for (final f in found) f.join('/'): true};
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: Text('Carpetas sin música (${found.length})'),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: ListView(
              children: [
                for (final f in found)
                  CheckboxListTile(
                    dense: true,
                    value: chosen[f.join('/')],
                    onChanged: (v) => setL(() => chosen[f.join('/')] = v ?? false),
                    title: Text(f.last, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(f.join(' / '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cerrar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mover a _sin_musica')),
          ],
        ),
      ),
    );
    if (go != true) return;
    // Se mueven a una carpeta aparte en vez de borrarse: nada se pierde.
    await _run(() async {
      for (final f in found.where((f) => chosen[f.join('/')] == true)) {
        await _c.execute(MovePlan(f, ['_sin_musica', ...f], isDir: true));
      }
    }, 'Movidas a _sin_musica');
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _sel.isNotEmpty;
    final selected = [for (final e in _items) if (_sel.contains(e.name)) e];
    return PopScope(
      canPop: _path.isEmpty && !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (selecting) {
          setState(_sel.clear);
        } else {
          _path = _path.sublist(0, _path.length - 1);
          _load();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(selecting ? '${_sel.length} seleccionados' : widget.account.name),
          actions: selecting
              ? [
                  IconButton(icon: const Icon(Icons.drive_file_move_outline), tooltip: 'Mover', onPressed: () => _move(selected)),
                  IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Borrar', onPressed: () => _delete(selected)),
                ]
              : [
                  IconButton(icon: const Icon(Icons.create_new_folder_outlined), tooltip: 'Nueva carpeta', onPressed: _newFolder),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'empty') _findEmpty();
                      if (v == 'reload') _load();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'empty', child: Text('Buscar carpetas sin música')),
                      PopupMenuItem(value: 'reload', child: Text('Actualizar')),
                    ],
                  ),
                ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (var i = 0; i <= _path.length; i++)
                    Center(
                      child: InkWell(
                        onTap: i == _path.length
                            ? null
                            : () {
                                _path = _path.sublist(0, i);
                                _load();
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${i == 0 ? 'Inicio' : _path[i - 1]}${i == _path.length ? '' : '  ›'}',
                            style: TextStyle(color: i == _path.length ? AppColors.gold : Colors.white70, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            if (_progress.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(_progress, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                            ],
                          ],
                        ),
                      ),
                    )
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
                      : _items.isEmpty
                          ? const Center(child: Text('Carpeta vacía', style: TextStyle(color: Colors.white60)))
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (_, i) {
                                final e = _items[i];
                                final on = _sel.contains(e.name);
                                return ListTile(
                                  dense: true,
                                  selected: on,
                                  leading: Icon(
                                    on ? Icons.check_circle : (e.isDir ? Icons.folder : Icons.insert_drive_file_outlined),
                                    color: on || e.isDir ? AppColors.gold : Colors.white54,
                                  ),
                                  title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: e.isDir || e.size == 0 ? null : Text(_size(e.size), style: const TextStyle(fontSize: 11)),
                                  trailing: selecting
                                      ? null
                                      : PopupMenuButton<String>(
                                          onSelected: (v) {
                                            if (v == 'ren') _rename(e);
                                            if (v == 'mov') _move([e]);
                                            if (v == 'del') _delete([e]);
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'ren', child: Text('Renombrar')),
                                            PopupMenuItem(value: 'mov', child: Text('Mover…')),
                                            PopupMenuItem(value: 'del', child: Text('Borrar')),
                                          ],
                                        ),
                                  onLongPress: () => setState(() => _sel.add(e.name)),
                                  onTap: () {
                                    if (selecting) {
                                      setState(() => on ? _sel.remove(e.name) : _sel.add(e.name));
                                    } else if (e.isDir) {
                                      _path = _p(e.name);
                                      _load();
                                    }
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
