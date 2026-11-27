import 'api_cliente.dart';

/// Peticiones de los lugares guardados ("Mi viaje"). Todas necesitan sesión iniciada:
/// ApiCliente agrega el token solo.
class GuardadosServicio {
  /// ¿Este lugar está guardado por la persona con sesión?
  /// Ruta del backend: GET /api/guardados/:lugarId
  static Future<bool> estaGuardado(int lugarId) async {
    final respuesta = await ApiCliente.dio.get('/guardados/$lugarId');
    return respuesta.data['guardado'] == true;
  }

  /// Guarda el lugar. Ruta del backend: POST /api/guardados/:lugarId
  static Future<void> guardar(int lugarId) async {
    await ApiCliente.dio.post('/guardados/$lugarId');
  }

  /// Quita el lugar de Mi viaje. Ruta del backend: DELETE /api/guardados/:lugarId
  static Future<void> quitar(int lugarId) async {
    await ApiCliente.dio.delete('/guardados/$lugarId');
  }

  /// Los lugares guardados, el más reciente primero (para la pantalla Mi viaje).
  /// Cada elemento trae: id, nombre, tipo, imagen, promedio, total_resenas, categorias...
  /// Ruta del backend: GET /api/guardados
  static Future<List<Map<String, dynamic>>> listar() async {
    final respuesta = await ApiCliente.dio.get('/guardados', queryParameters: {'limite': 50});
    final lista = respuesta.data['lugares'] as List;
    return lista.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}