import 'dj_engine.dart';

/// En Windows no hay servicio de notificación multimedia (audio_service no lo soporta):
/// se mantiene la misma interfaz que en Android, sin efecto.
class AppAudio {
  AppAudio._();

  static AppAudio? instance = AppAudio._();

  static Future<void> init() async {}

  void attachDj(DjEngine e) {}

  void detachDj() {}
}
