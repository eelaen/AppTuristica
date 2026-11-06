/// Un lugar tal como lo muestra Explorar (lista y mapa).
class LugarExplorar {
  final int id;
  final String nombre;
  final String tipo; // 'destino' o 'empresa'
  final bool verificado;
  final String? direccion;
  final String? fotoPortada;
  final double? latitud;
  final double? longitud;
  final double? promedio;
  final int totalResenas;
  final List<String> categorias; // nombres

  const LugarExplorar({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.verificado,
    required this.direccion,
    required this.fotoPortada,
    required this.latitud,
    required this.longitud,
    required this.promedio,
    required this.totalResenas,
    required this.categorias,
  });

  /// true si tiene coordenadas y se puede poner en el mapa
  bool get tieneUbicacion => latitud != null && longitud != null;

  static double? _numero(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory LugarExplorar.fromJson(Map<String, dynamic> json) {
    final crudas = (json['categorias'] as List?) ?? const [];
    final nombres = crudas
        .map((c) => c is Map ? (c['nombre'] ?? c['slug'] ?? '') : c)
        .map((c) => c.toString())
        .where((c) => c.isNotEmpty)
        .toList();

    return LugarExplorar(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      tipo: (json['tipo'] as String?) ?? 'empresa',
      verificado: json['verificado'] == true,
      direccion: json['direccion'] as String?,
      fotoPortada: json['foto_portada'] as String?,
      latitud: _numero(json['latitud']),
      longitud: _numero(json['longitud']),
      promedio: _numero(json['promedio']),
      totalResenas: _numero(json['total_resenas'])?.toInt() ?? 0,
      categorias: nombres,
    );
  }
}