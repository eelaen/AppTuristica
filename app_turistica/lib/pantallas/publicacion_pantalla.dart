import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/tema.dart';
import '../modelos/publicacion.dart';
import 'lugar_perfil_pantalla.dart';

/// Una publicación completa: foto grande, autor y descripción entera.
class PublicacionPantalla extends StatelessWidget {
  final Publicacion publicacion;

  const PublicacionPantalla({super.key, required this.publicacion});

  @override
  Widget build(BuildContext context) {
    final p = publicacion;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicación')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Autor
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: p.esEmpresa
                      ? Tema.chipDe(context)
                      : Tema.coral.withValues(alpha: 0.18),
                  child: Icon(
                    p.esEmpresa ? Icons.storefront_outlined : Icons.person_outline,
                    color: p.esEmpresa ? Tema.acento(context) : Tema.coral,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(p.usuarioNombre,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          if (p.autorVerificado) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 16, color: Tema.acento(context)),
                          ],
                        ],
                      ),
                      Text(
                        '${p.esEmpresa ? 'Empresa' : 'Turista'} · ${p.ubicacion}',
                        style: TextStyle(
                            fontSize: 13, color: Tema.suave(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Foto (completa, sin recortar)
          Image.network(
            ApiConfig.imagen(p.imagen),
            width: double.infinity,
            fit: BoxFit.fitWidth,
            loadingBuilder: (context, hijo, progreso) {
              if (progreso == null) return hijo;
              return Container(
                height: 260,
                color: Tema.chipDe(context),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              height: 260,
              color: Tema.chipDe(context),
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined,
                  color: Tema.suave(context)),
            ),
          ),

          // Likes y comentarios
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(
                  p.yoDiLike ? Icons.favorite : Icons.favorite_border,
                  size: 22,
                  color: p.yoDiLike ? Tema.coral : Tema.suave(context),
                ),
                const SizedBox(width: 4),
                Text('${p.likes}',
                    style: TextStyle(color: Tema.suave(context))),
                const SizedBox(width: 18),
                Icon(Icons.chat_bubble_outline,
                    size: 21, color: Tema.suave(context)),
                const SizedBox(width: 4),
                Text('${p.comentarios}',
                    style: TextStyle(color: Tema.suave(context))),
              ],
            ),
          ),

          // Descripción completa
          if (p.descripcion != null && p.descripcion!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SelectableText(
                p.descripcion!,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),

          // Botón para ir al lugar
          if (p.lugarId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LugarPerfilPantalla(lugarId: p.lugarId!),
                )),
                icon: const Icon(Icons.place_outlined),
                label: Text(p.lugarNombre ?? 'Ver lugar'),
              ),
            ),
        ],
      ),
    );
  }
}