import '../modelos/lugar_detalle.dart';
import '../modelos/publicacion.dart';
import '../modelos/resena.dart';
import 'api_cliente.dart';

/// Peticiones del perfil de un lugar.
class LugarPerfilServicio {
  /// GET /api/lugares/:id
  static Future<LugarDetalle> detalle(int id) async {
    final r = await ApiCliente.dio.get('/lugares/$id');
    return LugarDetalle.fromJson(r.data['lugar'] as Map<String, dynamic>);
  }

  /// GET /api/lugares/mio (solo empresas): mi propio lugar
  static Future<LugarDetalle> mio() async {
    final r = await ApiCliente.dio.get('/lugares/mio');
    return LugarDetalle.fromJson(r.data['lugar'] as Map<String, dynamic>);
  }

  /// GET /api/publicaciones?lugar_id=...
  /// [autor]: 'empresas' = publicaciones del propio lugar,
  ///          'turistas' = donde lo etiquetaron.
  static Future<List<Publicacion>> publicaciones(int lugarId,
      {String? autor}) async {
    final r = await ApiCliente.dio.get(
      '/publicaciones',
      queryParameters: {
        'lugar_id': lugarId,
        if (autor != null) 'autor': autor,
        'limite': 30,
      },
    );
    return (r.data['publicaciones'] as List)
        .map((e) => Publicacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/lugares/:id/resenas
  static Future<List<Resena>> resenas(int lugarId) async {
    final r = await ApiCliente.dio.get('/lugares/$lugarId/resenas');
    return (r.data['resenas'] as List)
        .map((e) => Resena.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/lugares/:id/resenas (turistas con sesión)
  static Future<void> enviarResena({
    required int lugarId,
    required int estrellas,
    String? texto,
  }) async {
    await ApiCliente.dio.post('/lugares/$lugarId/resenas', data: {
      'estrellas': estrellas,
      if (texto != null && texto.isNotEmpty) 'texto': texto,
    });
  }
}