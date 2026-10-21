import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/player_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Atajos de escritorio: Espacio = play/pausa, ←/→ = tema anterior/siguiente,
/// Esc = volver. Se ignoran mientras se escribe en un campo de texto.
class DesktopShortcuts extends StatelessWidget {
  const DesktopShortcuts({super.key, required this.child});

  final Widget child;

  static bool _typing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx != null && ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || _typing()) return KeyEventResult.ignored;
    final audio = PlayerService.instance;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      navigatorKey.currentState?.maybePop();
      return KeyEventResult.handled;
    }
    if (audio.nowPlaying.value == null) return KeyEventResult.ignored;
    final p = audio.player;
    if (k == LogicalKeyboardKey.space) {
      p.playing ? p.pause() : p.play();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      audio.goTrack((p.currentIndex ?? 0) - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      audio.goTrack((p.currentIndex ?? 0) + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(autofocus: true, onKeyEvent: _onKey, child: child);
}

/// Permite arrastrar con el ratón listas y páginas (PageView, etc.).
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
