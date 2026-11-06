import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/tema.dart';
import '../modelos/lugar.dart';
import '../proveedores/sesion_proveedor.dart';
import '../servicios/api_cliente.dart';
import '../servicios/lugares_servicio.dart';
import '../servicios/publicaciones_servicio.dart';

/// Pantalla para subir una foto (el botón + de la barra).
/// - Turista: elige la foto y el lugar que etiqueta.
/// - Lugar turístico: elige la foto y se publica en su propio lugar.
/// Al cerrarse devuelve true si se publicó.
class SubirPublicacionPantalla extends StatefulWidget {
  final VoidCallback? alPublicar; // si viene, se usa en vez de cerrar la pantalla

  const SubirPublicacionPantalla({super.key, this.alPublicar});

  @override
  State<SubirPublicacionPantalla> createState() => _SubirPublicacionPantallaState();
}

class _SubirPublicacionPantallaState extends State<SubirPublicacionPantalla> {
  static const _maxBytes = 5 * 1024 * 1024; // 5 MB, igual que el backend
  static const _extensiones = ['jpg', 'jpeg', 'png', 'webp'];

  final _formulario = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _selector = ImagePicker();

  Uint8List? _bytes; // la foto elegida
  String? _nombreArchivo;
  int? _lugarId;

  List<Lugar> _lugares = [];
  bool _cargandoLugares = false;
  String? _errorLugares;

  bool _publicando = false;
  String? _error;

  /// true si quien publica es un lugar turístico
  bool get _esEmpresa => context.read<SesionProveedor>().usuario?.esEmpresa ?? false;

  @override
  void initState() {
    super.initState();
    // Solo el turista necesita la lista de lugares para elegir
    if (!_esEmpresa) _cargarLugares();
  }

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarLugares() async {
    setState(() {
      _cargandoLugares = true;
      _errorLugares = null;
    });
    try {
      final lugares = await LugaresServicio.listar();
      if (!mounted) return;
      setState(() => _lugares = lugares);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorLugares = ApiCliente.mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargandoLugares = false);
    }
  }

  /// Abre la galería (o el explorador de archivos en Windows) para elegir la foto
  Future<void> _elegirFoto() async {
    try {
      final archivo = await _selector.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600, // en el celular reduce el tamaño antes de subirla
        imageQuality: 85,
      );
      if (archivo == null) return; // la persona canceló

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

  Future<void> _publicar() async {
    if (_bytes == null) {
      setState(() => _error = 'Elige una foto para publicar');
      return;
    }
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _publicando = true;
      _error = null;
    });

    try {
      await PublicacionesServicio.crear(
        bytes: _bytes!,
        nombreArchivo: _nombreArchivo!,
        // El lugar turístico no manda lugar_id: el backend usa el suyo
        lugarId: _esEmpresa ? null : _lugarId,
        descripcion: _descripcion.text.trim(),
      );
      if (!mounted) return;
            if (widget.alPublicar != null) {
        widget.alPublicar!(); // viene de la pestaña Crear
      } else {
        Navigator.of(context).pop(true); // abierta desde otro lado (el + del perfil)
      } // publicada
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiCliente.mensajeDeError(e);
        _publicando = false;
      });
    }
  }

  /// El cuadro grande donde se ve la foto (o la invitación a elegirla)
  Widget _areaFoto() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _publicando ? null : _elegirFoto,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(
            color: Tema.chipDe(context),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: _bytes == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 44, color: Tema.acento(context)),
                    const SizedBox(height: 8),
                    Text('Toca para elegir una foto',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Tema.acento(context))),
                    const SizedBox(height: 4),
                    Text('JPG, PNG o WEBP, máximo 5 MB',
                        style: TextStyle(
                            fontSize: 12, color: Tema.suave(context))),
                  ],
                )
              : Image.memory(_bytes!, fit: BoxFit.cover, width: double.infinity),
        ),
      ),
    );
  }

  /// Para el turista: lista para elegir el lugar. Para el lugar turístico: un aviso.
  Widget _selectorLugar() {
    if (_esEmpresa) {
      final nombre = context.read<SesionProveedor>().usuario?.nombre ?? 'tu lugar';
      return Row(
        children: [
          Icon(Icons.place_outlined, color: Tema.acento(context)),
          const SizedBox(width: 8),
          Expanded(child: Text('Se publicará en: $nombre')),
        ],
      );
    }

    if (_cargandoLugares) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_errorLugares != null) {
      return Row(
        children: [
          Expanded(child: Text(_errorLugares!)),
          TextButton(onPressed: _cargarLugares, child: const Text('Reintentar')),
        ],
      );
    }

    return DropdownButtonFormField<int>(
      value: _lugarId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '¿Qué lugar visitaste?'),
      items: [
        for (final lugar in _lugares)
          DropdownMenuItem(
            value: lugar.id,
            child: Text('${lugar.nombre} (${lugar.categoria})',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (valor) => setState(() => _lugarId = valor),
      validator: (valor) => valor == null ? 'Elige el lugar de la foto' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _areaFoto(),
                if (_bytes != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _publicando ? null : _elegirFoto,
                      child: const Text('Cambiar foto'),
                    ),
                  ),
                const SizedBox(height: 16),
                _selectorLugar(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcion,
                  maxLength: 500,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: '¿Qué tal estuvo?',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                // El color y el tamaño del botón los pone el tema
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _publicando ? null : _publicar,
                    child: _publicando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Publicar'),
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