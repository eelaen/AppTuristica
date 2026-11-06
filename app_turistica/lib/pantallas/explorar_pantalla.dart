import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../config/tema.dart';
import '../modelos/categoria.dart';
import '../modelos/lugar_explorar.dart';
import '../servicios/explorar_servicio.dart';

/// Explorar. Dos modos:
/// - Normal: categorías, mapa con todos los lugares y destinos recomendados.
/// - Búsqueda (cuando se escribe algo): solo los resultados, o "Sin resultados".
class ExplorarPantalla extends StatefulWidget {
  const ExplorarPantalla({super.key});

  @override
  State<ExplorarPantalla> createState() => _ExplorarPantallaState();
}

class _ExplorarPantallaState extends State<ExplorarPantalla> {
  static const _centroLaCeiba = LatLng(15.7597, -86.7822);
  static const _chipsVisibles = 4; // las demás van en "Ver todas"

  final _mapa = MapController();
  final _buscador = TextEditingController();
  Timer? _espera;
  bool _mapaListo = false;

  // --- Modo normal ---
  List<Categoria> _categorias = [];
  List<LugarExplorar> _lugares = [];
  String? _categoriaSlug; // null = Todos
  int? _seleccionado; // lugar tocado en el mapa
  bool _cargando = true;
  bool _error = false;

  // --- Modo búsqueda ---
  List<LugarExplorar> _resultados = [];
  bool _buscandoCargando = false;
  bool _errorBusqueda = false;

  /// true cuando hay texto en el buscador
  bool get _enBusqueda => _buscador.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _buscador.dispose();
    _mapa.dispose();
    super.dispose();
  }

  // ---------------- Datos ----------------

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final resultados = await Future.wait([
        ExplorarServicio.categorias(),
        ExplorarServicio.lugares(categoria: _categoriaSlug),
      ]);
      if (!mounted) return;
      setState(() {
        _categorias = resultados[0] as List<Categoria>;
        _lugares = resultados[1] as List<LugarExplorar>;
        _cargando = false;
      });
      _ajustarMapa();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  /// Modo normal: pide los lugares de la categoría elegida
  Future<void> _cargarLugares() async {
    try {
      final lugares = await ExplorarServicio.lugares(categoria: _categoriaSlug);
      if (!mounted) return;
      setState(() {
        _lugares = lugares;
        _seleccionado = null;
        _error = false;
      });
      _ajustarMapa();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
    }
  }

  /// Modo búsqueda: pide los lugares que coinciden con el texto
  Future<void> _buscar() async {
    final consulta = _buscador.text.trim();
    if (consulta.isEmpty) return;
    setState(() {
      _buscandoCargando = true;
      _errorBusqueda = false;
    });
    try {
      final resultados = await ExplorarServicio.lugares(busqueda: consulta);
      if (!mounted || _buscador.text.trim() != consulta) return; // ya escribió otra cosa
      setState(() {
        _resultados = resultados;
        _buscandoCargando = false;
      });
    } catch (_) {
      if (!mounted || _buscador.text.trim() != consulta) return;
      setState(() {
        _buscandoCargando = false;
        _errorBusqueda = true;
      });
    }
  }

  // ---------------- Acciones ----------------

  /// Cada letra: cambia de modo al instante y busca cuando deja de escribir
  void _alEscribir(String _) {
    _espera?.cancel();
    if (_enBusqueda) {
      _mapaListo = false; // el mapa se quita; al volver se arma de nuevo
      setState(() {
        _buscandoCargando = true;
        _errorBusqueda = false;
        _seleccionado = null;
      });
      _espera = Timer(const Duration(milliseconds: 450), _buscar);
    } else {
      _salirDeBusqueda();
    }
  }

  void _limpiarBusqueda() {
    _buscador.clear();
    _espera?.cancel();
    FocusScope.of(context).unfocus();
    _salirDeBusqueda();
  }

  void _salirDeBusqueda() {
    setState(() {
      _resultados = [];
      _buscandoCargando = false;
      _errorBusqueda = false;
    });
  }

  void _elegirCategoria(String? slug) {
    if (slug == _categoriaSlug) return;
    setState(() => _categoriaSlug = slug);
    _cargarLugares();
  }

  /// Encuadra el mapa para que se vean todos los lugares con ubicación
  void _ajustarMapa() {
    if (!_mapaListo) return;
    final puntos = [
      for (final l in _lugares)
        if (l.tieneUbicacion) LatLng(l.latitud!, l.longitud!)
    ];
    if (puntos.isEmpty) {
      _mapa.move(_centroLaCeiba, 11);
    } else if (puntos.length == 1) {
      _mapa.move(puntos.first, 13);
    } else {
      _mapa.fitCamera(CameraFit.coordinates(
        coordinates: puntos,
        padding: const EdgeInsets.all(40),
        maxZoom: 14,
      ));
    }
  }

  /// Marca un lugar (tarjeta sobre el mapa) y centra el mapa en él
  void _seleccionar(LugarExplorar l) {
    setState(() => _seleccionado = l.id);
    if (l.tieneUbicacion && _mapaListo) {
      _mapa.move(LatLng(l.latitud!, l.longitud!), 14);
    }
  }

  void _verDetalle(LugarExplorar l) {
    // Aquí se abrirá la pantalla de detalle del lugar (siguiente paso)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Aquí se abrirá el detalle de ${l.nombre}'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _verTodasLasCategorias() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Categorías',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Todos', _categoriaSlug == null, () {
                    Navigator.pop(ctx);
                    _elegirCategoria(null);
                  }),
                  for (final c in _categorias)
                    _chip(c.nombre, c.slug == _categoriaSlug, () {
                      Navigator.pop(ctx);
                      _elegirCategoria(c.slug);
                    }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Pantalla ----------------

  @override
  Widget build(BuildContext context) {
    final buscando = _enBusqueda;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => buscando ? _buscar() : _cargarTodo(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _titulo(),
            _barraBusqueda(),
            if (buscando)
              _seccionResultados()
            else ...[
              _seccionCategorias(),
              _seccionMapa(),
              _seccionDestinos(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _titulo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Explorar destinos',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Tema.acento(context))),
          const SizedBox(height: 4),
          Text('Encuentra lugares y experiencias en La Ceiba y sus alrededores.',
              style: TextStyle(fontSize: 14, color: Tema.suave(context))),
        ],
      ),
    );
  }

  Widget _barraBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _buscador,
        onChanged: _alEscribir,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar lugares o empresas...',
          prefixIcon: Icon(Icons.search, color: Tema.acento(context)),
          suffixIcon: _enBusqueda
              ? IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(Icons.close),
                  onPressed: _limpiarBusqueda,
                )
              : null,
          filled: true,
          fillColor: Tema.superficie(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _chip(String texto, bool activo, VoidCallback alTocar) {
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: activo ? Tema.primarioClaro : Tema.chipDe(context),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: activo ? Colors.white : Tema.suave(context),
          ),
        ),
      ),
    );
  }

  // ---------------- Modo búsqueda ----------------

  Widget _seccionResultados() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resultados',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_buscandoCargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorBusqueda)
            Column(
              children: [
                const Text(
                  'No se pudo buscar.\nRevisa que el backend esté encendido.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _buscar, child: const Text('Reintentar')),
              ],
            )
          else if (_resultados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Tema.suave(context)),
                    const SizedBox(height: 10),
                    const Text('Sin resultados',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Prueba con otro nombre o categoría.',
                        style: TextStyle(color: Tema.suave(context))),
                  ],
                ),
              ),
            )
          else
            for (final l in _resultados)
              _tarjetaLugar(l, alTocar: () => _verDetalle(l), mostrarTipo: true),
        ],
      ),
    );
  }

  // ---------------- Modo normal ----------------

  Widget _seccionCategorias() {
    // Se ven las primeras; si la elegida está entre las ocultas, también se muestra
    final visibles = _categorias.take(_chipsVisibles).toList();
    final elegida = _categorias.where((c) => c.slug == _categoriaSlug);
    if (elegida.isNotEmpty && !visibles.contains(elegida.first)) {
      visibles.add(elegida.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text('Categorías',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              if (_categorias.length > _chipsVisibles)
                GestureDetector(
                  onTap: _verTodasLasCategorias,
                  child: Text('Ver todas',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Tema.acento(context))),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip('Todos', _categoriaSlug == null, () => _elegirCategoria(null)),
              for (final c in visibles) ...[
                const SizedBox(width: 8),
                _chip(c.nombre, c.slug == _categoriaSlug,
                    () => _elegirCategoria(c.slug)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _seccionMapa() {
    final sel = _lugares.where((l) => l.id == _seleccionado).firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 320,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCenter: _centroLaCeiba,
                  initialZoom: 11,
                  onMapReady: () {
                    _mapaListo = true;
                    _ajustarMapa();
                  },
                  // Tocar un espacio vacío del mapa cierra la tarjeta
                  onTap: (_, _) => setState(() => _seleccionado = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app_turistica',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final l in _lugares)
                        if (l.tieneUbicacion)
                          Marker(
                            point: LatLng(l.latitud!, l.longitud!),
                            width: 48,
                            height: 48,
                            child: GestureDetector(
                              onTap: () => _seleccionar(l),
                              child: Icon(
                                Icons.location_on,
                                size: l.id == _seleccionado ? 44 : 34,
                                color: l.id == _seleccionado
                                    ? Tema.coral
                                    : Tema.primarioClaro,
                              ),
                            ),
                          ),
                    ],
                  ),
                  const SimpleAttributionWidget(source: Text('OpenStreetMap')),
                ],
              ),
              // Tarjeta con la info del lugar tocado
              if (sel != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 24,
                  child: _infoLugar(sel),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta que aparece sobre el mapa al tocar un marcador
  Widget _infoLugar(LugarExplorar l) {
    final detalle = [
      if (l.categorias.isNotEmpty) l.categorias.join(', '),
      if (l.direccion != null && l.direccion!.isNotEmpty) l.direccion!,
    ].join(' · ');

    return Material(
      color: Tema.superficie(context),
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _foto(l, 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(l.nombre,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          if (l.verificado) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 16, color: Tema.acento(context)),
                          ],
                        ],
                      ),
                      if (detalle.isNotEmpty)
                        Text(detalle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: Tema.suave(context))),
                      if (l.promedio != null) _estrellas(l),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _seleccionado = null),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: Tema.suave(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _verDetalle(l),
                child: const Text('Ver más'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionDestinos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Destinos recomendados',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error)
            Column(
              children: [
                const Text(
                  'No se pudieron cargar los lugares.\nRevisa que el backend esté encendido.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _cargarTodo, child: const Text('Reintentar')),
              ],
            )
          else if (_lugares.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No hay lugares en esta categoría.',
                    style: TextStyle(color: Tema.suave(context))),
              ),
            )
          else
            for (final l in _lugares)
              _tarjetaLugar(l, alTocar: () => _seleccionar(l)),
        ],
      ),
    );
  }

  // ---------------- Piezas compartidas ----------------

  Widget _estrellas(LugarExplorar l) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B301)),
          const SizedBox(width: 2),
          Text('${l.promedio} (${l.totalResenas})',
              style: TextStyle(fontSize: 13, color: Tema.suave(context))),
        ],
      ),
    );
  }

  Widget _tarjetaLugar(
    LugarExplorar l, {
    required VoidCallback alTocar,
    bool mostrarTipo = false,
  }) {
    final activo = l.id == _seleccionado && !mostrarTipo;
    final detalle = [
      if (mostrarTipo) (l.tipo == 'empresa' ? 'Empresa' : 'Destino'),
      if (l.categorias.isNotEmpty) l.categorias.join(', '),
      if (l.direccion != null && l.direccion!.isNotEmpty) l.direccion!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Tema.superficie(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: alTocar,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: activo ? Tema.acento(context) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                _foto(l, 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(l.nombre,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                          if (l.verificado) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified,
                                size: 16, color: Tema.acento(context)),
                          ],
                        ],
                      ),
                      if (detalle.isNotEmpty)
                        Text(detalle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: Tema.suave(context))),
                      if (l.promedio != null) _estrellas(l),
                    ],
                  ),
                ),
                Icon(
                  l.tieneUbicacion
                      ? Icons.location_on_outlined
                      : Icons.location_off_outlined,
                  color: Tema.acento(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _foto(LugarExplorar l, double tamano) {
    final vacio = Container(
      width: tamano,
      height: tamano,
      color: Tema.chipDe(context),
      child: Icon(Icons.landscape_outlined, color: Tema.suave(context)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: l.fotoPortada == null
          ? vacio
          : Image.network(
              ApiConfig.imagen(l.fotoPortada!),
              width: tamano,
              height: tamano,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => vacio,
            ),
    );
  }
}