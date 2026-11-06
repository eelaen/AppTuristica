/// Una reseña que un turista dejó en un lugar.
class Resena {
  final int id;
  final String usuarioNombre;
  final int estrellas;
  final String? texto;
  final DateTime? creadoEn;

  const Resena({
    required this.id,
    required this.usuarioNombre,
    required this.estrellas,
    required this.texto,
    required this.creadoEn,
  });

  factory Resena.fromJson(Map<String, dynamic> json) => Resena(
        id: json['id'] as int,
        usuarioNombre: json['usuario_nombre'] as String,
        estrellas: (json['estrellas'] as num).toInt(),
        texto: json['texto'] as String?,
        creadoEn: DateTime.tryParse('${json['creado_en']}')?.toLocal(),
      );
}