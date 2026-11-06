/// El detalle completo de un lugar (para su perfil).
class LugarDetalle {
  final int id;
  final int? usuarioId; // dueño de la cuenta (null en destinos sin cuenta)
  final String nombre;
  final String tipo; // 'destino' o 'empresa'
  final bool verificado;
  final String? descripcion;
  final String? direccion;
  final String? telefono;
  final String? horario;
  final String? fotoPortada;
  final double? latitud;
  final double? longitud;
  final double? promedio;
  final int totalResenas;
  final int totalPublicaciones;
  final int totalLikes;
  final List<String> categorias;

  const LugarDetalle({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.tipo,
    required this.verificado,
    required this.descripcion,
    required this.direccion,
    required this.telefono,
    required this.horario,
    required this.fotoPortada,
    required this.latitud,
    required this.longitud,
    required this.promedio,
    required this.totalResenas,
    required this.totalPublicaciones,
    required this.totalLikes,
    required this.categorias,
  });

  bool get esEmpresa => tipo == 'empresa';
  bool get tieneUbicacion => latitud != null && longitud != null;

  static double? _numero(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory LugarDetalle.fromJson(Map<String, dynamic> json) {
    final crudas = (json['categorias'] as List?) ?? const [];
    final nombres = crudas
        .map((c) => c is Map ? (c['nombre'] ?? c['slug'] ?? '') : c)
        .map((c) => c.toString())
        .where((c) => c.isNotEmpty)
        .toList();

    return LugarDetalle(
      id: json['id'] as int,
      usuarioId: json['usuario_id'] as int?,
      nombre: json['nombre'] as String,
      tipo: (json['tipo'] as String?) ?? 'empresa',
      verificado: json['verificado'] == true,
      descripcion: json['descripcion'] as String?,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      horario: json['horario'] as String?,
      fotoPortada: json['foto_portada'] as String?,
      latitud: _numero(json['latitud']),
      longitud: _numero(json['longitud']),
      promedio: _numero(json['promedio']),
      totalResenas: _numero(json['total_resenas'])?.toInt() ?? 0,
      totalPublicaciones: _numero(json['total_publicaciones'])?.toInt() ?? 0,
      totalLikes: _numero(json['total_likes'])?.toInt() ?? 0,
      categorias: nombres,
    );
  }
}