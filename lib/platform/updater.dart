import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

/// Dirección del appcast (asset del último release de GitHub).
const String kAppcastUrl =
    'https://github.com/pytngdfv1-ai/vinyl-solutions-windows/releases/latest/download/appcast.xml';

/// Busca actualizaciones al abrir y cada 6 horas (WinSparkle pregunta si instalar).
Future<void> initUpdater() async {
  if (!Platform.isWindows || kDebugMode) return;
  try {
    await autoUpdater.setFeedURL(kAppcastUrl);
    await autoUpdater.checkForUpdates();
    await autoUpdater.setScheduledCheckInterval(21600);
  } catch (e) {
    debugPrint('Actualizador no disponible: $e');
  }
}
