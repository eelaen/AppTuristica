import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../modelos/publicacion.dart';
import 'api_cliente.dart';

/// Peticiones relacionadas con las publicaciones.
class PublicacionesServicio {
  /// Pide el feed.
  /// [autor]: 'turistas', 'empresas' o null (todos).
  /// [categoria]: slug de categoría, o null.
  /// Ruta del backend: GET /api/publicaciones
  static Future<List<Publicacion>> feed({
    String? autor,
    String? categoria,
    int pagina = 1,
  }) async {
    final respuesta = await ApiCliente.dio.get(
      '/publicaciones',
      queryParameters: {
        if (autor != null) 'autor': autor,
        if (categoria != null) 'categoria': categoria,
        'pagina': pagina,
        'limite': 20,
      },
    );
    final lista = respuesta.data['publicaciones'] as List;
    return lista
        .map((e) => Publicacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sube una foto. Ruta del backend: POST /api/publicaciones (form-data)
  /// - Turista: debe enviar [lugarId] (el lugar que etiqueta).
  /// - Lugar turístico: no envía [lugarId]; el backend usa su propio lugar.
  static Future<void> crear({
    required Uint8List bytes,
    required String nombreArchivo,
    int? lugarId,
    String? descripcion,
  }) async {
    final formulario = FormData.fromMap({
      'imagen': MultipartFile.fromBytes(
        bytes,
        filename: nombreArchivo,
        // Sin esto, se envía como "application/octet-stream" y el backend lo rechaza
        contentType: DioMediaType.parse(_tipoDeImagen(nombreArchivo)),
      ),
      if (lugarId != null) 'lugar_id': lugarId,
      if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
    });
    await ApiCliente.dio.post('/publicaciones', data: formulario);
  }

  /// Tipo de imagen según la extensión del archivo
  static String _tipoDeImagen(String nombreArchivo) {
    final extension = nombreArchivo.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // jpg y jpeg
    }
  }
}