import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/tema.dart';
import 'pantallas/splash_pantalla.dart';
import 'proveedores/sesion_proveedor.dart';
import 'proveedores/tema_proveedor.dart';

/// Punto de arranque de la app.
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Restaura la sesión guardada (si la persona ya había iniciado antes)
        ChangeNotifierProvider(create: (_) => SesionProveedor()..restaurar()),
        // Recuerda si la persona prefiere modo claro, oscuro o el del sistema
        ChangeNotifierProvider(create: (_) => TemaProveedor()..cargar()),
      ],
      child: const LaCeibaApp(),
    ),
  );
}

class LaCeibaApp extends StatelessWidget {
  const LaCeibaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Tema.nombreApp,
      debugShowCheckedModeBanner: false,
      theme: Tema.claro,
      darkTheme: Tema.oscuro,
      themeMode: context.watch<TemaProveedor>().modo,
      home: const SplashPantalla(),
    );
  }
}