import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../config/tema.dart';
import '../modelos/lugar_detalle.dart';
import '../servicios/api_cliente.dart';
import '../servicios/lugar_perfil_servicio.dart';

/// Editar la foto, descripción, horario, teléfono y dirección de una empresa.
/// El nombre no se puede cambiar. Devuelve true al cerrarse si se guardó.
class EditarLugarPantalla extends StatefulWidget {
  final LugarDetalle lugar;
  const EditarLugarPantalla({super.key, required this.lugar});

  @override
  State<EditarLugarPantalla> createState() => _EditarLugarPantallaState();
}

class _EditarLugarPantallaState extends State<EditarLugarPantalla> {
  static const _maxBytes = 5 * 1024 * 1024;
  static const _extensiones = ['jpg', 'jpeg', 'png', 'webp'];

  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _descripcion;
  late final TextEditingController _horario;
  late final TextEditingController _telefono;
  late final TextEditingController _direccion;
  final _selector = ImagePicker();

  Uint8List? _bytes;
  String? _nombreArchivo;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final l = widget.lugar;
    _descripcion = TextEditingController(text: l.descripcion ?? '');
    _horario = TextEditingController(text: l.horario ?? '');
    _telefono = TextEditingController(text: l.telefono ?? '');
    _direccion = TextEditingController(text: l.direccion ?? '');
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _horario.dispose();
    _telefono.dispose();
    _direccion.dispose();
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
      await LugarPerfilServicio.editarMio(
        descripcion: _descripcion.text.trim(),
        horario: _horario.text.trim(),
        telefono: _telefono.text.trim(),
        direccion: _direccion.text.trim(),
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
      child: Icon(Icons.storefront_outlined,
          size: 56, color: Tema.acento(context)),
    );
    Widget imagen;
    if (_bytes != null) {
      imagen = Image.memory(_bytes!, fit: BoxFit.cover);
    } else if (widget.lugar.fotoPortada != null) {
      imagen = Image.network(
        ApiConfig.imagen(widget.lugar.fotoPortada!),
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
                // El nombre se muestra pero no se puede editar
                TextFormField(
                  initialValue: widget.lugar.nombre,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    helperText: 'El nombre no se puede cambiar',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcion,
                  maxLength: 500,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _horario,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Horario',
                    hintText: 'Ej: Salidas a las 8:00 am',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _telefono,
                  maxLength: 20,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _direccion,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Ej: Salida desde La Ceiba',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
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