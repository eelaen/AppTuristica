import '../modelos/perfil_usuario.dart';
import '../modelos/publicacion.dart';
import 'api_cliente.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// Peticiones del perfil de una persona.
class UsuarioPerfilServicio {
  /// GET /api/usuarios/:id
  static Future<PerfilUsuario> perfil(int id) async {
    final r = await ApiCliente.dio.get('/usuarios/$id');
    return PerfilUsuario.fromJson(r.data['usuario'] as Map<String, dynamic>);
  }

  /// GET /api/publicaciones?usuario_id=...
  static Future<List<Publicacion>> publicaciones(int usuarioId) async {
    final r = await ApiCliente.dio.get(
      '/publicaciones',
      queryParameters: {'usuario_id': usuarioId, 'limite': 30},
    );
    return (r.data['publicaciones'] as List)
        .map((e) => Publicacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

    /// PUT /api/usuarios/me (form-data)
  /// Solo se envía lo que cambió. Si [bytes] viene, se sube como foto de perfil.
  static Future<void> editar({
    String? nombre,
    String? biografia,
    Uint8List? bytes,
    String? nombreArchivo,
  }) async {
    final formulario = FormData.fromMap({
      if (nombre != null) 'nombre': nombre,
      if (biografia != null) 'biografia': biografia,
      if (bytes != null && nombreArchivo != null)
        'imagen': MultipartFile.fromBytes(
          bytes,
          filename: nombreArchivo,
          contentType: DioMediaType.parse(_tipoDeImagen(nombreArchivo)),
        ),
    });
    await ApiCliente.dio.put('/usuarios/me', data: formulario);
  }

  static String _tipoDeImagen(String nombreArchivo) {
    final extension = nombreArchivo.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}