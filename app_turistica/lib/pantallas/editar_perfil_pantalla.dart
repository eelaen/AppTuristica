import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../config/tema.dart';
import '../modelos/perfil_usuario.dart';
import '../servicios/api_cliente.dart';
import '../servicios/usuario_perfil_servicio.dart';

/// Editar nombre, biografía y foto de perfil de un turista.
/// Devuelve true al cerrarse si se guardó.
class EditarPerfilPantalla extends StatefulWidget {
  final PerfilUsuario perfil;
  const EditarPerfilPantalla({super.key, required this.perfil});

  @override
  State<EditarPerfilPantalla> createState() => _EditarPerfilPantallaState();
}

class _EditarPerfilPantallaState extends State<EditarPerfilPantalla> {
  static const _maxBytes = 5 * 1024 * 1024;
  static const _extensiones = ['jpg', 'jpeg', 'png', 'webp'];

  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _biografia;
  final _selector = ImagePicker();

  Uint8List? _bytes; // foto nueva (si eligió una)
  String? _nombreArchivo;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.perfil.nombre);
    _biografia = TextEditingController(text: widget.perfil.biografia ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _biografia.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    try {
      final archivo = await _selector.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (archivo == null) return;

      final extension = archivo.name.split('.').last.toLowerCase();
      if (!_extensiones.contains(extension)) {
        setState(() => _error = 'Elige una imagen JPG, PNG o WEBP');
        return;
      }
      final bytes = await archivo.readAsBytes();
      if (bytes.length > _maxBytes) {
        if (!mounted) return;
        setState(() => _error = 'La imagen supera los 5 MB');
        return;
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _nombreArchivo = archivo.name;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo abrir la imagen');
    }
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await UsuarioPerfilServicio.editar(
        nombre: _nombre.text.trim(),
        biografia: _biografia.text.trim(),
        bytes: _bytes,
        nombreArchivo: _nombreArchivo,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = ApiCliente.mensajeDeError(e);
      });
    }
  }

  Widget _avatar() {
    final vacio = Container(
      color: Tema.chipDe(context),
      child: Icon(Icons.person_outline, size: 56, color: Tema.acento(context)),
    );
    Widget imagen;
    if (_bytes != null) {
      imagen = Image.memory(_bytes!, fit: BoxFit.cover);
    } else if (widget.perfil.fotoPerfil != null) {
      imagen = Image.network(
        ApiConfig.imagen(widget.perfil.fotoPerfil!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => vacio,
      );
    } else {
      imagen = vacio;
    }
    return ClipOval(child: SizedBox(width: 120, height: 120, child: imagen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formulario,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _guardando ? null : _elegirFoto,
                  child: _avatar(),
                ),
                TextButton(
                  onPressed: _guardando ? null : _elegirFoto,
                  child: const Text('Cambiar foto'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombre,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _biografia,
                  maxLength: 300,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Biografía',
                    hintText: 'Cuéntanos de ti',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}