import 'dart:typed_data';
import 'package:dio/dio.dart';
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
  /// PUT /api/lugares/mio (form-data)
  /// Edita el lugar de la empresa con sesión. El nombre no se puede cambiar.
  /// Solo se envía lo que no sea null. Si [bytes] viene, se sube como foto de perfil.
  static Future<void> editarMio({
    String? descripcion,
    String? direccion,
    String? telefono,
    String? horario,
    Uint8List? bytes,
    String? nombreArchivo,
  }) async {
    final formulario = FormData.fromMap({
      if (descripcion != null) 'descripcion': descripcion,
      if (direccion != null) 'direccion': direccion,
      if (telefono != null) 'telefono': telefono,
      if (horario != null) 'horario': horario,
      if (bytes != null && nombreArchivo != null)
        'imagen': MultipartFile.fromBytes(
          bytes,
          filename: nombreArchivo,
          contentType: DioMediaType.parse(_tipoDeImagen(nombreArchivo)),
        ),
    });
    await ApiCliente.dio.put('/lugares/mio', data: formulario);
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
