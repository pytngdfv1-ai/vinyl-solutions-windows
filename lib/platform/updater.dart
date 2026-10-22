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
    // En segundo plano: solo muestra ventana si hay una versión nueva (sin errores si aún no hay Release).
    await autoUpdater.checkForUpdates(inBackground: true);
    await autoUpdater.setScheduledCheckInterval(21600);
  } catch (e) {
    debugPrint('Actualizador no disponible: $e');
  }
}
