import 'package:flutter/material.dart';
import '../config/api_config.dart';

/// Foto de perfil redonda. Si no hay foto (o falla al cargar),
/// muestra el avatar tradicional: fondo gris con silueta de persona.
class AvatarPerfil extends StatelessWidget {
  final String? foto; // ruta, por ejemplo /uploads/perfiles/abc.jpg
  final double tamano;

  const AvatarPerfil({super.key, this.foto, this.tamano = 44});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final fondo = oscuro ? const Color(0xFF3A4440) : const Color(0xFFD5DAD8);
    final silueta = oscuro ? const Color(0xFF7F8A85) : const Color(0xFF9AA5A0);

    // La silueta: cabeza (círculo) y hombros (óvalo), recortados por el círculo
    final respaldo = Container(
      width: tamano,
      height: tamano,
      color: fondo,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: tamano * 0.20,
            child: Container(
              width: tamano * 0.36,
              height: tamano * 0.36,
              decoration: BoxDecoration(color: silueta, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            top: tamano * 0.62,
            child: Container(
              width: tamano * 0.80,
              height: tamano * 0.70,
              decoration: BoxDecoration(
                color: silueta,
                borderRadius: BorderRadius.circular(tamano),
              ),
            ),
          ),
        ],
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: (foto == null || foto!.isEmpty)
            ? respaldo
            : Image.network(
                ApiConfig.imagen(foto!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => respaldo,
              ),
      ),
    );
  }
}