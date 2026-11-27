import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../servicios/api_cliente.dart';
import '../servicios/guardados_servicio.dart';
import 'package:provider/provider.dart';
import '../proveedores/sesion_proveedor.dart';
import '../widgets/formulario_resena.dart';
import 'login_pantalla.dart';

/// Detalle de un lugar (destino o empresa): portada, categorías, calificación,
/// descripción, datos de contacto, "Cómo llegar", guardar y fotos de visitantes.
/// Se abre con el id del lugar, desde el mapa, la lista o la búsqueda de Explorar.
class DetalleLugarPantalla extends StatefulWidget {
  final int lugarId;

  /// Para mostrar un título mientras carga (opcional)
  final String? nombreInicial;

  const DetalleLugarPantalla({super.key, required this.lugarId, this.nombreInicial});

  @override
  State<DetalleLugarPantalla> createState() => _DetalleLugarPantallaState();
}

class _DetalleLugarPantallaState extends State<DetalleLugarPantalla> {
  Map<String, dynamic>? _lugar;
  List<String> _fotos = []; // rutas de las fotos de visitantes
  bool _guardado = false;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  /// Hay sesión si ApiCliente tiene un token
  bool get _haySesion => ApiCliente.token != null;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Pide al backend el lugar, sus fotos y si está guardado
  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // 1. El lugar (GET /api/lugares/:id). Si esto falla, se muestra el error.
      final respuesta = await ApiCliente.dio.get('/lugares/${widget.lugarId}');
      final lugar = Map<String, dynamic>.from(respuesta.data['lugar'] as Map);

      // 2. Las fotos de visitantes (GET /api/publicaciones?lugar_id=...).
      //    Si fallan, el detalle se muestra igual, sin fotos.
      var fotos = <String>[];
      try {
        final f = await ApiCliente.dio.get(
          '/publicaciones',
          queryParameters: {'lugar_id': widget.lugarId, 'limite': 30},
        );
        fotos = (f.data['publicaciones'] as List)
            .map((p) => (p as Map)['imagen'] as String)
            .toList();
      } catch (_) {}

      // 3. Si está guardado (solo si hay sesión)
      var guardado = false;
      if (_haySesion) {
        try {
          guardado = await GuardadosServicio.estaGuardado(widget.lugarId);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _lugar = lugar;
        _fotos = fotos;
        _guardado = guardado;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiCliente.mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Guarda o quita el lugar de Mi viaje
  Future<void> _alternarGuardado() async {
    if (!_haySesion) {
      _aviso('Inicia sesión para guardar lugares en tu viaje');
      return;
    }
    if (_guardando) return;

    setState(() => _guardando = true);
    try {
      if (_guardado) {
        await GuardadosServicio.quitar(widget.lugarId);
      } else {
        await GuardadosServicio.guardar(widget.lugarId);
      }
      if (!mounted) return;
      setState(() => _guardado = !_guardado);
      _aviso(_guardado ? 'Guardado en Mi viaje' : 'Quitado de Mi viaje');
    } catch (e) {
      if (!mounted) return;
      _aviso(ApiCliente.mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Abre la app de mapas del celular con la ubicación del lugar
  Future<void> _comoLlegar(double latitud, double longitud) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud',
    );
    try {
      final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abierto && mounted) _aviso('No se pudo abrir el mapa');
    } catch (_) {
      if (mounted) _aviso('No se pudo abrir el mapa');
    }
  }

/// Pide sesión si hace falta y abre el formulario de reseña
Future<void> _dejarResena() async {
  if (!context.read<SesionProveedor>().estaLogueado) {
    final entro = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPantalla()),
    );
    if (entro != true || !mounted) return;
  }
  if (!mounted) return;
  if (context.read<SesionProveedor>().usuario?.esEmpresa ?? false) {
    _aviso('Solo los turistas pueden dejar reseñas');
    return;
  }
  final guardada = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FormularioResena(lugarId: widget.lugarId),
  );
  if (guardada == true && mounted) {
    _aviso('¡Gracias por tu reseña!');
    _cargar(); // recarga para actualizar promedio y total
  }
}


  /// Muestra una foto en grande
  void _verFoto(String ruta) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(ApiConfig.imagen(ruta), fit: BoxFit.contain),
        ),
      ),
    );
  }

  /// Un renglón de información con su icono (dirección, teléfono, horario)
  Widget _fila(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (_lugar?['nombre'] as String?) ?? widget.nombreInicial ?? 'Lugar';

    return Scaffold(
      appBar: AppBar(
        title: Text(nombre, overflow: TextOverflow.ellipsis),
        actions: [
          if (_lugar != null)
            IconButton(
              tooltip: _guardado ? 'Quitar de Mi viaje' : 'Guardar en Mi viaje',
              onPressed: _guardando ? null : _alternarGuardado,
              icon: Icon(_guardado ? Icons.bookmark : Icons.bookmark_border),
            ),
        ],
      ),
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final tema = Theme.of(context);
    final lugar = _lugar!;

    // Se leen los datos del lugar (los opcionales pueden venir vacíos)
    final esDestino = (lugar['tipo'] as String?) != 'empresa';
    final verificado = lugar['verificado'] == true;
    final promedio = (lugar['promedio'] as num?)?.toDouble();
    final total = (lugar['total_resenas'] as num?)?.toInt() ?? 0;
    final descripcion = (lugar['descripcion'] as String?) ?? '';
    final categorias = (lugar['categorias'] as List?) ?? [];
    final direccion = lugar['direccion'] as String?;
    final telefono = lugar['telefono'] as String?;
    final horario = lugar['horario'] as String?;
    final latitud = (lugar['latitud'] as num?)?.toDouble();
    final longitud = (lugar['longitud'] as num?)?.toDouble();
    final portada = (lugar['foto_portada'] as String?) ?? (_fotos.isNotEmpty ? _fotos.first : null);

    return ListView(
      children: [
        // --- Portada ---
        AspectRatio(
          aspectRatio: 16 / 9,
          child: portada != null
              ? Image.network(
                  ApiConfig.imagen(portada),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      Container(color: tema.colorScheme.surfaceContainerHighest),
                )
              : Container(
                  color: tema.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    esDestino ? Icons.landscape_outlined : Icons.storefront_outlined,
                    size: 56,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Nombre y verificado ---
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (lugar['nombre'] as String?) ?? '',
                      style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (verificado)
                    Tooltip(
                      message: 'Empresa verificada',
                      child: Icon(Icons.verified, color: tema.colorScheme.primary),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // --- Tipo y categorías ---
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(esDestino ? 'Destino' : 'Empresa'),
                  ),
                  for (final c in categorias)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text((c as Map)['nombre'] as String),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // --- Calificación ---
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    promedio != null
                        ? '${promedio.toStringAsFixed(1)} ($total ${total == 1 ? 'reseña' : 'reseñas'})'
                        : 'Aún sin reseñas',
                  ),
                ],
              ),

              // --- Descripción ---
              if (descripcion.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(descripcion),
              ],

              // --- Datos (solo los que existen) ---
              if (direccion != null || telefono != null || horario != null) ...[
                const SizedBox(height: 12),
                if (direccion != null) _fila(Icons.place_outlined, direccion),
                if (telefono != null) _fila(Icons.phone_outlined, telefono),
                if (horario != null) _fila(Icons.schedule, horario),
              ],

              // --- Botones ---
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (latitud == null || longitud == null)
                          ? null
                          : () => _comoLlegar(latitud, longitud),
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('Cómo llegar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _guardando ? null : _alternarGuardado,
                      icon: Icon(_guardado ? Icons.bookmark : Icons.bookmark_border),
                      label: Text(_guardado ? 'Guardado' : 'Guardar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
SizedBox(
  width: double.infinity,
  child: FilledButton.tonalIcon(
    onPressed: _dejarResena,
    icon: const Icon(Icons.rate_review_outlined),
    label: Text(total == 0 ? 'Sé el primero en reseñar' : 'Dejar reseña'),
  ),
),

              if (latitud == null || longitud == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Este lugar aún no tiene ubicación en el mapa.',
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                  ),
                ),

              // --- Fotos de visitantes ---
              const SizedBox(height: 24),
              Text(
                'Fotos de visitantes',
                style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (_fotos.isEmpty)
                Text(
                  'Aún no hay fotos de este lugar. ¡Sé la primera persona en subir una!',
                  style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: _fotos.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _verFoto(_fotos[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        ApiConfig.imagen(_fotos[i]),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            Container(color: tema.colorScheme.surfaceContainerHighest),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}