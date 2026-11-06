import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tema.dart';
import '../proveedores/sesion_proveedor.dart';
import '../proveedores/tema_proveedor.dart';

/// Perfil PROVISIONAL: datos de la sesión, apariencia y cerrar sesión.
class PerfilPantalla extends StatelessWidget {
  const PerfilPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<SesionProveedor>().usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: usuario == null
          ? const Center(child: Text('No hay sesión iniciada'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        usuario.esEmpresa ? Tema.turquesa : Tema.arena,
                    child: Text(
                      usuario.iniciales,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color:
                            usuario.esEmpresa ? Colors.white : Tema.azulOscuro,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    usuario.nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(usuario.email,
                      style: TextStyle(color: Tema.suave(context))),
                  const SizedBox(height: 4),
                  Text(
                    usuario.esEmpresa ? 'Lugar turístico' : 'Turista',
                    style: TextStyle(color: Tema.acento(context)),
                  ),

                  // --- Apariencia ---
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Apariencia',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Consumer<TemaProveedor>(
                    builder: (context, tema, _) => SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Claro'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Oscuro'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('Sistema'),
                          ),
                        ],
                        selected: {tema.modo},
                        onSelectionChanged: (s) => tema.cambiar(s.first),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                           onPressed: () async {
                        final nav = Navigator.of(context);
                        await context.read<SesionProveedor>().cerrarSesion();
                        if (nav.canPop()) nav.pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}