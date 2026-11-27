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

  /// GET /api/lugares?q=...&categoria=...&tipo=...&orden=...&limite=...
  ///
  /// Todos los filtros son opcionales:
  /// - [busqueda]: texto que se busca en el nombre o la categoría
  /// - [categoria]: el slug de la categoría (playas, naturaleza...)
  /// - [tipo]: 'destino' o 'empresa'
  /// - [orden]: 'recomendados' (mejor puntaje primero); si no se indica, por nombre
  /// - [limite]: cuántos lugares pedir (por defecto 50)
  static Future<List<LugarExplorar>> lugares({
    String? busqueda,
    String? categoria,
    String? tipo,
    String? orden,
    int? limite,
  }) async {
    final r = await ApiCliente.dio.get(
      '/lugares',
      queryParameters: {
        if (busqueda != null && busqueda.isNotEmpty) 'q': busqueda,
        if (categoria != null) 'categoria': categoria,
        if (tipo != null) 'tipo': tipo,
        if (orden != null) 'orden': orden,
        'limite': limite ?? 50,
      },
    );
    return (r.data['lugares'] as List)
        .map((e) => LugarExplorar.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}