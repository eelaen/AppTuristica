import '../modelos/perfil_usuario.dart';
import '../modelos/publicacion.dart';
import 'api_cliente.dart';

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
}