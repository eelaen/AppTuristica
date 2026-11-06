import 'package:flutter/material.dart';

/// Marca, colores y tema de la app. Para cambiar nombre o paleta, se cambia SOLO aquí.
class Tema {
  // ============ MARCA (cámbialo cuando la definas) ============
  static const nombreApp = 'CeibaGo';
  static const lema = 'Descubre el Caribe hondureño';
  static const siglas = 'CeibaGo';
  static const lemaSplash = 'La Ceiba, La Novia de Honduras';
  static const ubicacionActual = 'La Ceiba, Honduras';

  // ============ PALETA ============
  static const primario = Color(0xFF1B4D3E); // verde oscuro (tarjetas, splash)
  static const primarioClaro = Color(0xFF1F7A63); // botones y filtros activos
  static const fondo = Color(0xFFF5F8F6);
  static const chip = Color(0xFFE6F0EC);
  static const textoSuave = Color(0xFF6B7B74);
  static const coral = Color(0xFFF2784B); // corazón del like

  // Colores del diseño anterior: ahora apuntan a la paleta nueva
  static const turquesa = primarioClaro;
  static const azulOscuro = primario;
  static const arena = chip;

  // ============ TEMAS ============
  static ThemeData get claro => _construir(Brightness.light);
  static ThemeData get oscuro => _construir(Brightness.dark);

  static ThemeData _construir(Brightness brillo) {
    final esOscuro = brillo == Brightness.dark;
    final acentoTexto = esOscuro ? const Color(0xFF5CC4A5) : primarioClaro;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primario, brightness: brillo),
      scaffoldBackgroundColor: esOscuro ? const Color(0xFF0F1512) : fondo,

      // Botones rellenos (Iniciar sesión, Crear cuenta, Publicar...)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primarioClaro,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
      ),

      // Enlaces de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: acentoTexto),
      ),

      // Campos de texto: recuadro redondeado
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: esOscuro ? const Color(0xFF2B3A34) : const Color(0xFFB7C4BE),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: acentoTexto, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: acentoTexto),
      ),
    );
  }

  // ============ COLORES QUE CAMBIAN SEGÚN EL MODO ============
  static bool _esOscuro(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color superficie(BuildContext c) =>
      _esOscuro(c) ? const Color(0xFF1A2420) : Colors.white;

  static Color chipDe(BuildContext c) =>
      _esOscuro(c) ? const Color(0xFF24332D) : chip;

  static Color suave(BuildContext c) =>
      _esOscuro(c) ? const Color(0xFF9DB0A8) : textoSuave;

  static Color acento(BuildContext c) =>
      _esOscuro(c) ? const Color(0xFF5CC4A5) : primarioClaro;

  static Color borde(BuildContext c) =>
      _esOscuro(c) ? const Color(0xFF2B3A34) : const Color(0xFFE3E8E5);
}