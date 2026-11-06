import '../modelos/lugar.dart';
import 'api_cliente.dart';

/// Peticiones relacionadas con los lugares turísticos.
class LugaresServicio {
  /// Pide la lista de lugares (hasta 50). Con [busqueda] filtra por nombre o categoría.
  /// Ruta del backend: GET /api/lugares
  static Future<List<Lugar>> listar({String? busqueda}) async {
    final respuesta = await ApiCliente.dio.get(
      '/lugares',
      queryParameters: {
        'limite': 50,
        if (busqueda != null && busqueda.isNotEmpty) 'q': busqueda,
      },
    );
    final lista = respuesta.data['lugares'] as List;
    return lista.map((e) => Lugar.fromJson(e as Map<String, dynamic>)).toList();
  }
}