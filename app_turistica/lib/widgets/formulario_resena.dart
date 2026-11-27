import 'package:flutter/material.dart';
import '../servicios/api_cliente.dart';
import '../servicios/lugar_perfil_servicio.dart';

class FormularioResena extends StatefulWidget {
  final int lugarId;
  const FormularioResena({super.key, required this.lugarId});

  @override
  State<FormularioResena> createState() => _FormularioResenaState();
}

class _FormularioResenaState extends State<FormularioResena> {
  final _texto = TextEditingController();
  int _estrellas = 0;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await LugarPerfilServicio.enviarResena(
        lugarId: widget.lugarId,
        estrellas: _estrellas,
        texto: _texto.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = ApiCliente.mensajeDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deja tu reseña',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                tooltip: '${i + 1} estrellas',
                onPressed: () => setState(() => _estrellas = i + 1),
                icon: Icon(
                  i < _estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 38,
                  color: const Color(0xFFF5B301),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _texto,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Cuéntanos tu experiencia (opcional)',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_estrellas == 0 || _enviando) ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Publicar reseña'),
            ),
          ),
        ],
      ),
    );
  }
}