import 'package:shared_preferences/shared_preferences.dart';

/// Guarda los tokens de sesión en el dispositivo (acceso y renovación).
///
/// IMPORTANTE: shared_preferences NO cifra. Sirve para desarrollar. Antes de
/// publicar, cámbialo por flutter_secure_storage; el cambio se hace solo aquí.
class AlmacenToken {
  static const _claveAcceso = 'token_sesion';
  static const _claveRenovacion = 'token_renovacion';

  static Future<String?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveAcceso);
  }

  static Future<String?> leerRenovacion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveRenovacion);
  }

  /// Guarda el par completo (acceso + renovación)
  static Future<void> guardarPar(String acceso, String renovacion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveAcceso, acceso);
    await prefs.setString(_claveRenovacion, renovacion);
  }

  static Future<void> borrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveAcceso);
    await prefs.remove(_claveRenovacion);
  }
}