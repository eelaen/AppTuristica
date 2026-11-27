/// Un lugar turístico, con los datos básicos que devuelve la lista del backend.
class Lugar {
  final int id;
  final String nombre;
  final String tipo; // 'destino' o 'empresa'
  final List<String> categorias;

  const Lugar({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.categorias,
  });

  /// Categorías en un solo texto, por ejemplo "Playas, Naturaleza"
  String get categoria => categorias.join(', ');

  factory Lugar.fromJson(Map<String, dynamic> json) {
    final crudas = (json['categorias'] as List?) ?? const [];
    final nombres = crudas
        .map((c) => c is Map ? (c['nombre'] ?? c['slug'] ?? '') : c)
        .map((c) => c.toString())
        .where((c) => c.isNotEmpty)
        .toList();

    return Lugar(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      tipo: (json['tipo'] as String?) ?? 'destino',
      categorias: nombres,
    );
  }
}