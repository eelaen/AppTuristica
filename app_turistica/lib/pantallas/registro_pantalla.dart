import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/tema.dart';
import '../modelos/categoria.dart';
import '../proveedores/sesion_proveedor.dart';
import '../servicios/api_cliente.dart';
import '../servicios/explorar_servicio.dart';
import 'elegir_ubicacion_pantalla.dart';

/// Pantalla de registro. La persona elige si es turista o un lugar turístico,
/// y el formulario cambia según lo que elija.
/// Al cerrarse devuelve true si la cuenta se creó (y ya inició sesión).
class RegistroPantalla extends StatefulWidget {
  const RegistroPantalla({super.key});

  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  final _formulario = GlobalKey<FormState>();

  // Campos comunes
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  // Campos del lugar turístico
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _horario = TextEditingController();

  List<Categoria> _categorias = [];
  final Set<String> _elegidas = {}; // slugs de las categorías marcadas
  bool _cargandoCategorias = false;
  bool _errorCategorias = false;
  String? _errorSeleccion; // "Elige al menos una categoría"

  LatLng? _ubicacion;

  bool _esEmpresa = false;
  bool _ocultarPassword = true;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _email, _password, _descripcion, _direccion, _telefono, _horario]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    setState(() {
      _cargandoCategorias = true;
      _errorCategorias = false;
    });
    try {
      final lista = await ExplorarServicio.categorias();
      if (!mounted) return;
      setState(() => _categorias = lista);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorCategorias = true);
    } finally {
      if (mounted) setState(() => _cargandoCategorias = false);
    }
  }

  Future<void> _elegirUbicacion() async {
    final punto = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => ElegirUbicacionPantalla(inicial: _ubicacion),
      ),
    );
    if (punto != null && mounted) setState(() => _ubicacion = punto);
  }

  // ---------------- Validaciones (iguales a las del backend) ----------------

  String? _validarNombre(String? v) {
    final t = (v ?? '').trim();
    if (t.length < 2 || t.length > 100) return 'Debe tener entre 2 y 100 caracteres';
    return null;
  }

  String? _validarEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Escribe tu correo';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) return 'Correo no válido';
    return null;
  }

  String? _validarPassword(String? v) {
    final t = v ?? '';
    if (t.length < 8 || t.length > 72) return 'Debe tener entre 8 y 72 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(t) || !RegExp(r'\d').hasMatch(t)) {
      return 'Debe incluir letras y números';
    }
    return null;
  }

  String? _validarDescripcion(String? v) {
    final t = (v ?? '').trim();
    if (t.length < 10 || t.length > 1000) return 'Cuéntanos qué ofreces (entre 10 y 1000 caracteres)';
    return null;
  }

  String? _validarDireccion(String? v) {
    if ((v ?? '').trim().length > 255) return 'Es demasiado larga';
    return null;
  }

  String? _validarTelefono(String? v) {
    final t = (v ?? '').trim();
    if (t.isNotEmpty && !RegExp(r'^[0-9+\-\s()]{7,20}$').hasMatch(t)) return 'Teléfono no válido';
    return null;
  }

  String? _validarHorario(String? v) {
    if ((v ?? '').trim().length > 100) return 'Es demasiado largo';
    return null;
  }

  // ---------------- Envío ----------------

  Future<void> _crearCuenta() async {
    final formularioOk = _formulario.currentState!.validate();

    // Las categorías no son un campo de texto: se revisan aparte
    final faltanCategorias = _esEmpresa && _elegidas.isEmpty;
    setState(() => _errorSeleccion =
        faltanCategorias ? 'Elige al menos una categoría' : null);
    if (!formularioOk || faltanCategorias) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    final sesion = context.read<SesionProveedor>();
    try {
      if (_esEmpresa) {
        await sesion.registrarEmpresa(
          nombreLugar: _nombre.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          descripcion: _descripcion.text.trim(),
          categorias: _elegidas.toList(),
          direccion: _direccion.text.trim(),
          telefono: _telefono.text.trim(),
          horario: _horario.text.trim(),
          latitud: _ubicacion == null
              ? null
              : double.parse(_ubicacion!.latitude.toStringAsFixed(6)),
          longitud: _ubicacion == null
              ? null
              : double.parse(_ubicacion!.longitude.toStringAsFixed(6)),
        );
      } else {
        await sesion.registrarUsuario(
          nombre: _nombre.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true); // cuenta creada y sesión iniciada
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiCliente.mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  // ---------------- Pantalla ----------------

  Widget _campo({
    required TextEditingController controlador,
    required String etiqueta,
    String? ayuda,
    bool opcional = false,
    TextInputType? teclado,
    int maxLineas = 1,
    required String? Function(String?) validar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controlador,
        keyboardType: teclado,
        maxLines: maxLineas,
        decoration: InputDecoration(
          labelText: opcional ? '$etiqueta (opcional)' : etiqueta,
          hintText: ayuda,
          alignLabelWithHint: maxLineas > 1,
        ),
        validator: validar,
      ),
    );
  }

  /// Chips para marcar una o varias categorías
  Widget _selectorCategorias() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Categorías',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Puedes elegir más de una',
              style: TextStyle(fontSize: 13, color: Tema.suave(context))),
          const SizedBox(height: 10),
          if (_cargandoCategorias)
            const LinearProgressIndicator()
          else if (_errorCategorias)
            Row(
              children: [
                const Expanded(child: Text('No se pudieron cargar las categorías.')),
                TextButton(
                    onPressed: _cargarCategorias,
                    child: const Text('Reintentar')),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categorias)
                  FilterChip(
                    label: Text(c.nombre),
                    selected: _elegidas.contains(c.slug),
                    showCheckmark: false,
                    selectedColor: Tema.primarioClaro,
                    backgroundColor: Tema.chipDe(context),
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _elegidas.contains(c.slug)
                          ? Colors.white
                          : Tema.suave(context),
                    ),
                    onSelected: (marcada) => setState(() {
                      marcada ? _elegidas.add(c.slug) : _elegidas.remove(c.slug);
                      _errorSeleccion = null;
                    }),
                  ),
              ],
            ),
          if (_errorSeleccion != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errorSeleccion!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }

  /// Botón para elegir la ubicación en el mapa
  Widget _selectorUbicacion() {
    final p = _ubicacion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Tema.chipDe(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _elegirUbicacion,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(p == null ? Icons.add_location_alt_outlined : Icons.check_circle,
                    color: Tema.acento(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p == null
                            ? 'Marcar ubicación en el mapa'
                            : 'Ubicación marcada',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Tema.acento(context)),
                      ),
                      Text(
                        p == null
                            ? 'Así los turistas te encuentran en Explorar (opcional)'
                            : 'Toca para cambiarla',
                        style: TextStyle(
                            fontSize: 13, color: Tema.suave(context)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Tema.suave(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Crear cuenta',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '¿Cómo quieres usar ${Tema.nombreApp}?',
                  style: TextStyle(color: Tema.suave(context)),
                ),
                const SizedBox(height: 16),

                // Turista o lugar turístico
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.person_outline),
                        label: Text('Turista'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.place_outlined),
                        label: Text('Lugar turístico'),
                      ),
                    ],
                    selected: {_esEmpresa},
                    onSelectionChanged: (seleccion) =>
                        setState(() => _esEmpresa = seleccion.first),
                  ),
                ),
                const SizedBox(height: 24),

                _campo(
                  controlador: _nombre,
                  etiqueta: _esEmpresa ? 'Nombre del lugar turístico' : 'Nombre',
                  validar: _validarNombre,
                ),

                // Campos que solo pide un lugar turístico
                if (_esEmpresa) ...[
                  _campo(
                    controlador: _descripcion,
                    etiqueta: '¿Qué ofrece?',
                    ayuda: 'Rafting, senderismo, comida típica...',
                    teclado: TextInputType.multiline,
                    maxLineas: 3,
                    validar: _validarDescripcion,
                  ),
                  _selectorCategorias(),
                  _campo(
                    controlador: _direccion,
                    etiqueta: 'Dirección o referencia',
                    ayuda: 'Carretera a Yoro, km 12',
                    opcional: true,
                    validar: _validarDireccion,
                  ),
                  _selectorUbicacion(),
                  _campo(
                    controlador: _telefono,
                    etiqueta: 'Teléfono de contacto',
                    ayuda: '9999-9999',
                    opcional: true,
                    teclado: TextInputType.phone,
                    validar: _validarTelefono,
                  ),
                  _campo(
                    controlador: _horario,
                    etiqueta: 'Horario',
                    ayuda: '8:00 am a 5:00 pm',
                    opcional: true,
                    validar: _validarHorario,
                  ),
                ],

                // Cuenta
                _campo(
                  controlador: _email,
                  etiqueta: 'Correo electrónico',
                  teclado: TextInputType.emailAddress,
                  validar: _validarEmail,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _password,
                    obscureText: _ocultarPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      helperText: 'Mínimo 8 caracteres, con letras y números',
                      suffixIcon: IconButton(
                        tooltip: _ocultarPassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        icon: Icon(_ocultarPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                      ),
                    ),
                    validator: _validarPassword,
                  ),
                ),

                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _cargando ? null : _crearCuenta,
                    child: _cargando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Crear cuenta'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('¿Ya tienes cuenta? Inicia sesión'),
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