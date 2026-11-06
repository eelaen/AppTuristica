/// Una categoría de lugares (Playas, Naturaleza, Aventura...).
class Categoria {
  final int id;
  final String slug; // lo que se manda al backend, por ejemplo "playas"
  final String nombre; // lo que se ve en pantalla
  final String icono;

  const Categoria({
    required this.id,
    required this.slug,
    required this.nombre,
    required this.icono,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: json['id'] as int,
        slug: json['slug'] as String,
        nombre: json['nombre'] as String,
        icono: (json['icono'] as String?) ?? '',
      );
}