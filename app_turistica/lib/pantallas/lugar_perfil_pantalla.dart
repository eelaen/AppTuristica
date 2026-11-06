import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/tema.dart';
import '../modelos/lugar_detalle.dart';
import '../modelos/publicacion.dart';
import '../proveedores/sesion_proveedor.dart';
import '../proveedores/tema_proveedor.dart';
import '../servicios/api_cliente.dart';
import '../servicios/lugar_perfil_servicio.dart';
import 'login_pantalla.dart';
import 'resenas_pantalla.dart';
import 'subir_publicacion_pantalla.dart';
import 'publicacion_pantalla.dart';

/// Perfil de un lugar turístico o empresa.
/// - Visitante: ve la info, deja reseña y puede llamar.
/// - Dueño (esMio o su cuenta): edita perfil, ve reseñas y publica.
class LugarPerfilPantalla extends StatefulWidget {
  final int? lugarId;
  final bool esMio; // true = abre el lugar de quien tiene la sesión

  const LugarPerfilPantalla({super.key, this.lugarId, this.esMio = false})
      : assert(lugarId != null || esMio);

  @override
  State<LugarPerfilPantalla> createState() => _LugarPerfilPantallaState();
}

class _LugarPerfilPantallaState extends State<LugarPerfilPantalla> {
  LugarDetalle? _lugar;
  List<Publicacion> _propias = [];
  List<Publicacion> _etiquetadas = [];
  int _pestana = 0; // 0 propias, 1 etiquetado
  bool _primeraCarga = true;
  bool _cargando = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final lugar = widget.esMio
          ? await LugarPerfilServicio.mio()
          : await LugarPerfilServicio.detalle(widget.lugarId!);
      final fotos = await Future.wait([
        LugarPerfilServicio.publicaciones(lugar.id, autor: 'empresas'),
        LugarPerfilServicio.publicaciones(lugar.id, autor: 'turistas'),
      ]);
      if (!mounted) return;
      setState(() {
        _lugar = lugar;
        _propias = fotos[0];
        _etiquetadas = fotos[1];
        if (_primeraCarga) {
          // Un destino sin cuenta no tiene publicaciones propias
          _pestana = lugar.usuarioId == null ? 1 : 0;
          _primeraCarga = false;
        }
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _abrir(Uri uri, String falla) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _aviso(falla);
    } catch (_) {
      if (mounted) _aviso(falla);
    }
  }

  void _llamar(LugarDetalle l) {
    final numero = l.telefono!.replaceAll(RegExp(r'[^0-9+]'), '');
    _abrir(Uri(scheme: 'tel', path: numero), 'No se pudo abrir el teléfono');
  }

  void _comoLlegar(LugarDetalle l) {
    _abrir(
      Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${l.latitud},${l.longitud}'),
      'No se pudo abrir el mapa',
    );
  }

  Future<void> _crearPublicacion() async {
    final publicada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SubirPublicacionPantalla()),
    );
    if (publicada == true && mounted) {
      _cargar();
      _aviso('Publicación creada');
    }
  }

  Future<void> _verResenas() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ResenasPantalla(lugarId: _lugar!.id, nombreLugar: _lugar!.nombre),
    ));
    if (mounted) _cargar();
  }

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
      builder: (_) => _FormularioResena(lugarId: _lugar!.id),
    );
    if (guardada == true && mounted) {
      _aviso('¡Gracias por tu reseña!');
      _cargar();
    }
  }

    Future<void> _cerrarSesion() async {
    final sesion = context.read<SesionProveedor>();
    final nav = Navigator.of(context);
    await sesion.cerrarSesion();
    if (nav.canPop()) nav.pop();
  }

  // ---------------- Pantalla ----------------

  @override
  Widget build(BuildContext context) {
    final yo = context.watch<SesionProveedor>().usuario;
    final l = _lugar;
    final dueno = widget.esMio ||
        (yo != null && l?.usuarioId != null && yo.id == l!.usuarioId);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(l?.nombre ?? 'Lugar', overflow: TextOverflow.ellipsis),
            ),
            if (l?.verificado ?? false) ...[
              const SizedBox(width: 6),
              Icon(Icons.verified, size: 20, color: Tema.acento(context)),
            ],
          ],
        ),
        actions: dueno ? _accionesDueno() : null,
      ),
      body: _cuerpo(dueno),
    );
  }

  /// "+", modo claro/oscuro y menú (solo para el dueño)
  List<Widget> _accionesDueno() {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return [
      IconButton(
        tooltip: 'Nueva publicación',
        icon: const Icon(Icons.add_box_outlined),
        onPressed: _crearPublicacion,
      ),
      IconButton(
        tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
        icon: Icon(oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        onPressed: () => context
            .read<TemaProveedor>()
            .cambiar(oscuro ? ThemeMode.light : ThemeMode.dark),
      ),
      PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'salir') _cerrarSesion();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
        ],
      ),
    ];
  }

  Widget _cuerpo(bool dueno) {
    if (_cargando && _lugar == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error && _lugar == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No se pudo cargar este lugar.\nRevisa que el backend esté encendido.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final l = _lugar!;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _cabecera(l),
          if (l.descripcion != null && l.descripcion!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(l.descripcion!,
                  style: const TextStyle(fontSize: 14, height: 1.35)),
            ),
          _etiquetas(l),
          _ubicacion(l),
          _botones(l, dueno),
          _pestanas(),
          _contenidoPestana(),
        ],
      ),
    );
  }

  /// Imagen a la izquierda y tres números a la derecha
  Widget _cabecera(LugarDetalle l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _avatar(l),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                _dato('${l.totalLikes}', 'Me gusta'),
                _dato('${l.totalPublicaciones}', 'Publicaciones'),
                _dato(
                  l.promedio?.toStringAsFixed(1) ?? '–',
                  'Reseñas (${l.totalResenas})',
                  icono: l.promedio != null ? Icons.star_rounded : null,
                  alTocar: _verResenas,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(LugarDetalle l) {
    final vacio = Container(
      color: Tema.chipDe(context),
      child: Icon(
        l.esEmpresa ? Icons.storefront_outlined : Icons.landscape_outlined,
        size: 38,
        color: Tema.acento(context),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 84,
        height: 84,
        child: l.fotoPortada == null
            ? vacio
            : Image.network(
                ApiConfig.imagen(l.fotoPortada!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => vacio,
              ),
      ),
    );
  }

  Widget _dato(String valor, String etiqueta,
      {IconData? icono, VoidCallback? alTocar}) {
    return Expanded(
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(valor,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  if (icono != null)
                    Icon(icono, size: 18, color: const Color(0xFFF5B301)),
                ],
              ),
              const SizedBox(height: 2),
              Text(etiqueta,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Tema.suave(context))),
            ],
          ),
        ),
      ),
    );
  }

  /// Horario (si hay) y categorías
  Widget _etiquetas(LugarDetalle l) {
    final chips = <Widget>[
      if (l.horario != null && l.horario!.isNotEmpty)
        _chip(Icons.schedule_outlined, l.horario!),
      for (final c in l.categorias) _chip(null, c),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _chip(IconData? icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Tema.chipDe(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 15, color: Tema.acento(context)),
            const SizedBox(width: 5),
          ],
          Text(texto,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Tema.acento(context))),
        ],
      ),
    );
  }

  /// Recuadro de ubicación (al tocarlo abre "Cómo llegar")
  Widget _ubicacion(LugarDetalle l) {
    final tieneDireccion = l.direccion != null && l.direccion!.isNotEmpty;
    if (!tieneDireccion && !l.tieneUbicacion) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Tema.superficie(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: l.tieneUbicacion ? () => _comoLlegar(l) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.place_outlined, color: Tema.acento(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tieneDireccion ? l.direccion! : 'Ver en el mapa',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (l.tieneUbicacion)
                  Icon(Icons.directions_outlined,
                      size: 22, color: Tema.acento(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dueño: Editar perfil + Ver reseñas. Visitante: Dejar reseña + teléfono.
  Widget _botones(LugarDetalle l, bool dueno) {
    final tieneTelefono = l.telefono != null && l.telefono!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          if (dueno) ...[
            Expanded(
              child: _botonSecundario(
                'Editar perfil',
                () => _aviso(
                    'Editar el perfil (foto, horario...) viene en el siguiente paso'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _botonSecundario('Ver reseñas', _verResenas)),
          ] else ...[
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  shape: const StadiumBorder(),
                ),
                onPressed: _dejarResena,
                child: const Text('Dejar reseña'),
              ),
            ),
            if (tieneTelefono) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Llamar',
                onPressed: () => _llamar(l),
                icon: const Icon(Icons.call_outlined),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _botonSecundario(String texto, VoidCallback alTocar) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(42),
        shape: const StadiumBorder(),
      ),
      onPressed: alTocar,
      child: Text(texto),
    );
  }

  // ---------------- Pestañas y cuadrícula ----------------

  Widget _pestanas() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Row(
            children: [
              _botonPestana(Icons.grid_on_outlined, 0, 'Publicaciones propias'),
              _botonPestana(Icons.assignment_ind_outlined, 1, 'Etiquetado'),
            ],
          ),
          Divider(height: 1, color: Tema.borde(context)),
        ],
      ),
    );
  }

  Widget _botonPestana(IconData icono, int indice, String etiqueta) {
    final activa = _pestana == indice;
    return Expanded(
      child: Semantics(
        label: etiqueta,
        button: true,
        child: InkWell(
          onTap: () => setState(() => _pestana = indice),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: activa ? Tema.acento(context) : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Icon(icono,
                color: activa ? Tema.acento(context) : Tema.suave(context)),
          ),
        ),
      ),
    );
  }

  Widget _contenidoPestana() {
    final fotos = _pestana == 0 ? _propias : _etiquetadas;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Deslizar cambia de pestaña, como en Instagram
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200 && _pestana == 0) setState(() => _pestana = 1);
        if (v > 200 && _pestana == 1) setState(() => _pestana = 0);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: fotos.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                child: Center(
                  child: Text(
                    _pestana == 0
                        ? 'Aún no ha publicado fotos.'
                        : 'Nadie ha etiquetado este lugar todavía.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Tema.suave(context)),
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                itemCount: fotos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (context, i) {
                  final p = fotos[i];
                  return GestureDetector(
                                       onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PublicacionPantalla(publicacion: p))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        ApiConfig.imagen(p.imagen),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: Tema.chipDe(context),
                          child: Icon(Icons.broken_image_outlined,
                              color: Tema.suave(context)),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Hoja para dejar una reseña (estrellas + comentario opcional)
class _FormularioResena extends StatefulWidget {
  final int lugarId;
  const _FormularioResena({required this.lugarId});

  @override
  State<_FormularioResena> createState() => _FormularioResenaState();
}

class _FormularioResenaState extends State<_FormularioResena> {
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