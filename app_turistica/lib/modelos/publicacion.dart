/// Una publicación del feed, tal como la devuelve el backend.
class Publicacion {
  final int id;
  final String imagen; // ruta, por ejemplo /uploads/publicaciones/abc.jpg
  final String? descripcion;
  final String ubicacion; // texto, por ejemplo "Cayos Cochinos"
  final String tipo; // 'publicacion' u 'oferta'
  final int usuarioId;
  final String usuarioNombre;
  final String usuarioRol; // 'usuario' o 'empresa'
  final bool autorVerificado;
  final int? lugarId; // null si es un turista que no etiquetó lugar
  final String? lugarNombre;
  final int likes;
  final int comentarios;
  final bool yoDiLike;

  const Publicacion({
    required this.id,
    required this.imagen,
    required this.descripcion,
    required this.ubicacion,
    required this.tipo,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.usuarioRol,
    required this.autorVerificado,
    required this.lugarId,
    required this.lugarNombre,
    required this.likes,
    required this.comentarios,
    required this.yoDiLike,
  });

  /// true si la publicó un lugar turístico (y no un turista)
  bool get esEmpresa => usuarioRol == 'empresa';

  /// true si es una oferta especial
  bool get esOferta => tipo == 'oferta';

  /// Convierte el JSON del backend en una Publicacion.
  factory Publicacion.fromJson(Map<String, dynamic> json) {
    return Publicacion(
      id: json['id'] as int,
      imagen: json['imagen'] as String,
      descripcion: json['descripcion'] as String?,
      ubicacion: (json['ubicacion'] as String?) ?? 'La Ceiba, Honduras',
      tipo: (json['tipo'] as String?) ?? 'publicacion',
      usuarioId: json['usuario_id'] as int,
      usuarioNombre: json['usuario_nombre'] as String,
      usuarioRol: json['usuario_rol'] as String,
      autorVerificado: json['autor_verificado'] == true,
      lugarId: json['lugar_id'] as int?,
      lugarNombre: json['lugar_nombre'] as String?,
      likes: (json['likes'] as num).toInt(),
      comentarios: (json['comentarios'] as num).toInt(),
      yoDiLike: json['yo_di_like'] == true,
    );
  }
}