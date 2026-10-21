import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'data/koofr_settings.dart';
import 'data/library_settings.dart';
import 'data/library_sync.dart';
import 'data/vinyl_store.dart';
import 'platform/desktop_shell.dart';
import 'platform/updater.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Audio en Windows (just_audio no trae soporte nativo): libmpv vía media_kit.
  JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1180, 800),
      minimumSize: Size(560, 640),
      center: true,
      title: 'VinylSolutions',
      backgroundColor: Color(0xFF0E0E0D),
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  final store = VinylStore();
  await store.load();
  await LibrarySettings.load();
  await KoofrAccounts.load();
  runApp(VinylApp(store: store));
  // Sincroniza las nubes al abrir (en segundo plano) y busca actualizaciones.
  LibrarySync.syncAll(store);
  initUpdater();
}

class VinylApp extends StatelessWidget {
  const VinylApp({super.key, required this.store});

  final VinylStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VinylSolutions',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const DesktopScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE53935),
      ),
      builder: (context, child) => DesktopShortcuts(child: child ?? const SizedBox.shrink()),
      home: HomeScreen(store: store),
    );
  }
}
