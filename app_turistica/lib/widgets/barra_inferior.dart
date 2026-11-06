import 'package:flutter/material.dart';
import '../config/tema.dart';

/// Barra inferior: Inicio, Explorar, Crear, Mi viaje y Perfil.
class BarraInferior extends StatelessWidget {
  final int seleccionado; // 0 inicio, 1 explorar, 2 crear, 3 mi viaje, 4 perfil
  final ValueChanged<int> alTocar;

  const BarraInferior({
    super.key,
    required this.seleccionado,
    required this.alTocar,
  });

  static const _iconos = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.add_box_outlined,
    Icons.favorite_border,
    Icons.person_outline,
  ];
  static const _iconosActivos = [
    Icons.home_rounded,
    Icons.explore,
    Icons.add_box,
    Icons.favorite,
    Icons.person,
  ];
  static const _etiquetas = ['Inicio', 'Explorar', 'Crear', 'Mi viaje', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tema.superficie(context),
        border: Border(top: BorderSide(color: Tema.borde(context))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(_iconos.length, (i) {
              final activo = i == seleccionado;
              final color = activo ? Tema.acento(context) : Tema.suave(context);
              return Expanded(
                child: Semantics(
                  label: _etiquetas[i],
                  button: true,
                  child: InkWell(
                    onTap: () => alTocar(i),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(activo ? _iconosActivos[i] : _iconos[i],
                            size: 26, color: color),
                        const SizedBox(height: 2),
                        Text(
                          _etiquetas[i],
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight:
                                activo ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}