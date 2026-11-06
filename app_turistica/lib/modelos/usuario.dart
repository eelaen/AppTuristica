/// Datos de la persona que inició sesión, tal como los devuelve el backend.
class Usuario {
  final int id;
  final String nombre;
  final String email;
  final String rol; // 'usuario' o 'empresa'

  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
  });

  /// true si es un lugar turístico (y no un turista)
  bool get esEmpresa => rol == 'empresa';

  /// Iniciales para el círculo del perfil (por ejemplo "María López" -> "ML")
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    return partes
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
        .join();
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
    );
  }
}