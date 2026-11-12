import 'package:flutter/material.dart';

import '../data/cajon.dart';
import '../data/play_mode.dart';
import '../data/ui_settings.dart';
import '../data/vinyl_store.dart';
import '../models/vinyl.dart';
import '../theme.dart';
import '../widgets/ring_360.dart';
import 'covers_screen.dart';
import 'crate_screen.dart';
import 'home_screen.dart';

/// Un reproductor (tocadiscos, deck o cinta abierta): todas las bibliotecas, vistas y
/// reproducidas en la versión de ese reproductor.
class ModeScreen extends StatefulWidget {
  const ModeScreen({super.key, required this.store, required this.mode});
  final VinylStore store;
  final PlayMode mode;

  @override
  State<ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends State<ModeScreen> {
  @override
  void initState() {
    super.initState();
    ViewMode.current = widget.mode;
  }

  @override
  void dispose() {
    ViewMode.current = null;
    super.dispose();
  }

  String get _title => switch (widget.mode) {
        PlayMode.disc => 'Tocadiscos',
        PlayMode.cassette => 'Deck de cassettes',
        PlayMode.reel => 'Cinta abierta',
      };

  void _open(Cajon c) {
    final page = !UiSettings.libRing.value && (c.kind == CajonKind.covers || c.kind == CajonKind.singles)
        ? CoversScreen(store: widget.store, cajon: c) as Widget
        : CrateScreen(store: widget.store, cajon: c, title: c.name);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) {
      ViewMode.current = widget.mode;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final all = widget.store.items;
          final cajones = [
            for (final c in Cajon.all)
              if (all.any(c.matches)) c,
          ];
          if (cajones.isEmpty) {
            return const Center(child: Text('Aún no hay bibliotecas', style: TextStyle(color: Colors.white70)));
          }
          final lists = <List<Vinyl>>[
            for (final c in cajones)
              all.where(c.matches).toList()..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase())),
          ];
          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.1),
                radius: 1.0,
                colors: [Color(0xFF1B1B22), Color(0xFF050507)],
              ),
            ),
            child: Ring360(
              count: cajones.length,
              aspect: 0.86,
              scale: 1.6,
              itemBuilder: (_, i) => HomeCard(label: cajones[i].name, covers: lists[i]),
              onFront: (i) => _open(cajones[i]),
              caption: (i) => (cajones[i].name, '${lists[i].length} · ${_title.toLowerCase()}'),
            ),
          );
        },
      ),
      backgroundColor: AppColors.ink,
    );
  }
}
