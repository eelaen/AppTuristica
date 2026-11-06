import '../modelos/categoria.dart';
import '../modelos/lugar_explorar.dart';
import 'api_cliente.dart';

/// Peticiones de la pantalla Explorar: categorías y lugares.
class ExplorarServicio {
  /// GET /api/categorias
  static Future<List<Categoria>> categorias() async {
    final r = await ApiCliente.dio.get('/categorias');
    return (r.data['categorias'] as List)
        .map((e) => Categoria.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/lugares?q=...&categoria=...
  static Future<List<LugarExplorar>> lugares({String? busqueda, String? categoria}) async {
    final r = await ApiCliente.dio.get(
      '/lugares',
      queryParameters: {
        if (busqueda != null && busqueda.isNotEmpty) 'q': busqueda,
        if (categoria != null) 'categoria': categoria,
        'limite': 50,
      },
    );
    return (r.data['lugares'] as List)
        .map((e) => LugarExplorar.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}