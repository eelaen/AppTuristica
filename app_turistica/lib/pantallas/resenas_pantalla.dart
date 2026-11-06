import 'package:flutter/material.dart';
import '../config/tema.dart';
import '../modelos/resena.dart';
import '../servicios/lugar_perfil_servicio.dart';

/// Lista de reseñas de un lugar.
class ResenasPantalla extends StatefulWidget {
  final int lugarId;
  final String nombreLugar;

  const ResenasPantalla({
    super.key,
    required this.lugarId,
    required this.nombreLugar,
  });

  @override
  State<ResenasPantalla> createState() => _ResenasPantallaState();
}

class _ResenasPantallaState extends State<ResenasPantalla> {
  late Future<List<Resena>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = LugarPerfilServicio.resenas(widget.lugarId);
  }

  void _recargar() =>
      setState(() => _futuro = LugarPerfilServicio.resenas(widget.lugarId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reseñas · ${widget.nombreLugar}')),
      body: FutureBuilder<List<Resena>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudieron cargar las reseñas.'),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _recargar, child: const Text('Reintentar')),
                ],
              ),
            );
          }
          final resenas = snapshot.data ?? [];
          if (resenas.isEmpty) {
            return Center(
              child: Text('Aún no hay reseñas.',
                  style: TextStyle(color: Tema.suave(context))),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: resenas.length,
            itemBuilder: (context, i) => _tarjeta(resenas[i]),
          );
        },
      ),
    );
  }

  Widget _tarjeta(Resena r) {
    final f = r.creadoEn;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Tema.superficie(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.usuarioNombre,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (f != null)
                Text('${f.day}/${f.month}/${f.year}',
                    style: TextStyle(fontSize: 12, color: Tema.suave(context))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < r.estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: const Color(0xFFF5B301),
              ),
            ),
          ),
          if (r.texto != null && r.texto!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.texto!, style: const TextStyle(fontSize: 14, height: 1.35)),
          ],
        ],
      ),
    );
  }
}