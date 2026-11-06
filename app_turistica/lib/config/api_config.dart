import 'package:flutter/foundation.dart';

/// Dirección del backend. Es el ÚNICO lugar donde se escribe.
class ApiConfig {
  // Permite cambiarla al ejecutar, sin tocar el código. Sirve para el celular real:
  // flutter run --dart-define=API_URL=http://192.168.1.15:3000
  static const String _urlManual = String.fromEnvironment('API_URL');

  /// Dirección base del servidor.
  static String get baseUrl {
    if (_urlManual.isNotEmpty) return _urlManual;
    // El emulador de Android ve a tu PC como 10.0.2.2 (localhost sería el emulador mismo)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    // Windows, Chrome, etc.
    return 'http://localhost:3000';
  }

  /// Dirección de la API, por ejemplo http://localhost:3000/api
  static String get apiUrl => '$baseUrl/api';

  /// Convierte la ruta que guarda el backend (/uploads/...) en una dirección completa.
  static String imagen(String ruta) => '$baseUrl$ruta';
}