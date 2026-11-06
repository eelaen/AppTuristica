import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/tema.dart';
import '../modelos/publicacion.dart';

/// Tarjeta del feed: autor, foto, etiqueta de oferta, descripción,
/// likes/comentarios y botón para ver la empresa.
/// No sabe nada del backend: solo muestra datos y avisa qué se tocó.
class TarjetaPublicacion extends StatelessWidget {
  final Publicacion publicacion;
  final VoidCallback alDarLike;
  final VoidCallback alComentar;
  final VoidCallback alTocarCuenta;
  final VoidCallback? alGuardar;
  final VoidCallback? alAbrir; // "Ver publicación completa"
  final VoidCallback? alVerEmpresa; // "Ver empresa y contacto"

  const TarjetaPublicacion({
    super.key,
    required this.publicacion,
    required this.alDarLike,
    required this.alComentar,
    required this.alTocarCuenta,
    this.alGuardar,
    this.alAbrir,
    this.alVerEmpresa,
  });

  @override
  Widget build(BuildContext context) {
    final p = publicacion;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tema.superficie(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezado(context, p),
          const SizedBox(height: 10),
          _foto(context, p),
          const SizedBox(height: 10),
          if (p.esOferta) _etiquetaOferta(context),
                   if (p.descripcion != null && p.descripcion!.isNotEmpty)
            GestureDetector(
              onTap: alAbrir,
              child: Text(
                p.descripcion!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
          const SizedBox(height: 8),
          _acciones(context, p),
          GestureDetector(
            onTap: alAbrir ?? alComentar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Ver publicación completa →',
                style: TextStyle(
                  color: Tema.acento(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (p.esEmpresa && p.lugarId != null && alVerEmpresa != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: alVerEmpresa,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Ver empresa y contacto'),
              ),
            ),
        ],
      ),
    );
  }

  /// Avatar + nombre (+ verificado) + "Turista · Ubicación"
  Widget _encabezado(BuildContext context, Publicacion p) {
    return InkWell(
      onTap: alTocarCuenta,
      borderRadius: BorderRadius.circular(12),
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
              size: 22,
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
                      child: Text(
                        p.usuarioNombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
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
                  style:
                      TextStyle(fontSize: 13, color: Tema.suave(context)),
                ),
              ],
            ),
          ),
          Icon(Icons.more_horiz, color: Tema.suave(context)),
        ],
      ),
    );
  }

    /// Foto con esquinas redondeadas
  Widget _foto(BuildContext context, Publicacion p) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          ApiConfig.imagen(p.imagen),
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (context, hijo, progreso) {
            if (progreso == null) return hijo;
            return Container(
              color: Tema.chipDe(context),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            color: Tema.chipDe(context),
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined,
                color: Tema.suave(context)),
          ),
        ),
      ),
    );
  }

  Widget _etiquetaOferta(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Tema.chipDe(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Oferta especial',
          style: TextStyle(
            color: Tema.acento(context),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// Corazón + número, comentario + número, y guardar a la derecha
  Widget _acciones(BuildContext context, Publicacion p) {
    final suave = Tema.suave(context);
    return Row(
      children: [
        InkWell(
          onTap: alDarLike,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Icon(
                p.yoDiLike ? Icons.favorite : Icons.favorite_border,
                size: 22,
                color: p.yoDiLike ? Tema.coral : suave,
              ),
              const SizedBox(width: 4),
              Text('${p.likes}', style: TextStyle(color: suave)),
            ],
          ),
        ),
        const SizedBox(width: 18),
        InkWell(
          onTap: alComentar,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 21, color: suave),
              const SizedBox(width: 4),
              Text('${p.comentarios}', style: TextStyle(color: suave)),
            ],
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: alGuardar,
          child: Icon(Icons.bookmark_border, size: 22, color: suave),
        ),
      ],
    );
  }
}
