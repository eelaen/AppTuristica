import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda si la app se ve en modo claro, oscuro o el del sistema.
class TemaProveedor extends ChangeNotifier {
  static const _clave = 'modo_tema';
  ThemeMode _modo = ThemeMode.system;

  ThemeMode get modo => _modo;

  /// Se llama una vez al arrancar la app
  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave);
    _modo = ThemeMode.values.firstWhere(
      (m) => m.name == guardado,
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> cambiar(ThemeMode nuevo) async {
    _modo = nuevo;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, nuevo.name);
  }
}