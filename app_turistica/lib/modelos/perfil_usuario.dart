/// Los datos públicos de una persona para mostrar su perfil.
class PerfilUsuario {
  final int id;
  final String nombre;
  final String rol; // 'usuario', 'empresa' o 'admin'
  final String? biografia;
  final String? fotoPerfil;
  final int totalPublicaciones;
  final int totalLikes;
  final int totalLugares;

  const PerfilUsuario({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.biografia,
    required this.fotoPerfil,
    required this.totalPublicaciones,
    required this.totalLikes,
    required this.totalLugares,
  });

  static int _entero(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory PerfilUsuario.fromJson(Map<String, dynamic> json) => PerfilUsuario(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        rol: (json['rol'] as String?) ?? 'usuario',
        biografia: json['biografia'] as String?,
        fotoPerfil: json['foto_perfil'] as String?,
        totalPublicaciones: _entero(json['total_publicaciones']),
        totalLikes: _entero(json['total_likes']),
        totalLugares: _entero(json['total_lugares']),
      );
}