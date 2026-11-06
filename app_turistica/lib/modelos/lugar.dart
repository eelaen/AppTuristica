/// Un lugar turístico, con los datos básicos que devuelve la lista del backend.
class Lugar {
  final int id;
  final String nombre;
  final String categoria;

  const Lugar({
    required this.id,
    required this.nombre,
    required this.categoria,
  });

  factory Lugar.fromJson(Map<String, dynamic> json) {
    return Lugar(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      categoria: json['categoria'] as String,
    );
  }
}