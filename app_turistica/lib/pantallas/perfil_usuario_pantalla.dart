import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../config/tema.dart';
import '../modelos/perfil_usuario.dart';
import '../modelos/publicacion.dart';
import '../proveedores/sesion_proveedor.dart';
import '../proveedores/tema_proveedor.dart';
import '../servicios/usuario_perfil_servicio.dart';
import 'publicacion_pantalla.dart';
import 'subir_publicacion_pantalla.dart';

/// Perfil de un turista. Si es el de quien tiene la sesión, muestra
/// las opciones de dueño (+, modo oscuro, editar y cerrar sesión).
class PerfilUsuarioPantalla extends StatefulWidget {
  final int usuarioId;

  const PerfilUsuarioPantalla({super.key, required this.usuarioId});

  @override
  State<PerfilUsuarioPantalla> createState() => _PerfilUsuarioPantallaState();
}

class _PerfilUsuarioPantallaState extends State<PerfilUsuarioPantalla> {
  PerfilUsuario? _perfil;
  List<Publicacion> _fotos = [];
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
      final r = await Future.wait([
        UsuarioPerfilServicio.perfil(widget.usuarioId),
        UsuarioPerfilServicio.publicaciones(widget.usuarioId),
      ]);
      if (!mounted) return;
      setState(() {
        _perfil = r[0] as PerfilUsuario;
        _fotos = r[1] as List<Publicacion>;
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

  Future<void> _crearPublicacion() async {
    final publicada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SubirPublicacionPantalla()),
    );
    if (publicada == true && mounted) {
      _cargar();
      _aviso('Publicación creada');
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
    final dueno = yo != null && yo.id == widget.usuarioId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_perfil?.nombre ?? 'Perfil', overflow: TextOverflow.ellipsis),
        actions: dueno ? _accionesDueno() : null,
      ),
      body: _cuerpo(dueno),
    );
  }

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
    if (_cargando && _perfil == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error && _perfil == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No se pudo cargar este perfil.\nRevisa que el backend esté encendido.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final p = _perfil!;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _cabecera(p),
          _biografia(p, dueno),
          if (dueno) _botonEditar(),
          _tituloFotos(dueno),
          _cuadricula(dueno),
        ],
      ),
    );
  }

  /// Foto a la izquierda y tres números a la derecha
  Widget _cabecera(PerfilUsuario p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _avatar(p),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                _dato('${p.totalPublicaciones}', 'Publicaciones'),
                _dato('${p.totalLikes}', 'Me gusta'),
                _dato('${p.totalLugares}', 'Lugares'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(PerfilUsuario p) {
    final vacio = Container(
      color: Tema.chipDe(context),
      child: Icon(Icons.person_outline, size: 40, color: Tema.acento(context)),
    );
    return ClipOval(
      child: SizedBox(
        width: 84,
        height: 84,
        child: p.fotoPerfil == null
            ? vacio
            : Image.network(
                ApiConfig.imagen(p.fotoPerfil!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => vacio,
              ),
      ),
    );
  }

  Widget _dato(String valor, String etiqueta) {
    return Expanded(
      child: Column(
        children: [
          Text(valor,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(etiqueta,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Tema.suave(context))),
        ],
      ),
    );
  }

  Widget _biografia(PerfilUsuario p, bool dueno) {
    final tiene = p.biografia != null && p.biografia!.isNotEmpty;
    if (!tiene && !dueno) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Text(
        tiene ? p.biografia! : 'Aún no tienes biografía. Cuéntanos de ti.',
        style: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: tiene ? null : Tema.suave(context),
        ),
      ),
    );
  }

  Widget _botonEditar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(42),
          shape: const StadiumBorder(),
        ),
        onPressed: () => _aviso('Editar el perfil (foto, biografía) viene en el siguiente paso'),
        child: const Text('Editar perfil'),
      ),
    );
  }

  Widget _tituloFotos(bool dueno) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        dueno ? 'Mis fotografías' : 'Fotografías',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _cuadricula(bool dueno) {
    if (_fotos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Center(
          child: Text(
            dueno
                ? 'Aún no has publicado fotos.\nToca Crear y comparte tu primer viaje.'
                : 'Aún no ha publicado fotos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tema.suave(context)),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _fotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, i) {
        final foto = _fotos[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PublicacionPantalla(publicacion: foto))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              ApiConfig.imagen(foto.imagen),
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
    );
  }
}