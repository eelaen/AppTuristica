import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tema.dart';
import '../modelos/publicacion.dart';
import '../proveedores/sesion_proveedor.dart';
import '../servicios/publicaciones_servicio.dart';
import '../widgets/tarjeta_publicacion.dart';
import 'login_pantalla.dart';
import 'lugar_perfil_pantalla.dart';
import 'publicacion_pantalla.dart';
import 'perfil_usuario_pantalla.dart';

/// Inicio: encabezado, acceso a Explorar y el feed de publicaciones
/// con filtro Todos / Turistas / Empresas. Es pública: se ve sin cuenta.
/// La barra inferior la maneja PrincipalPantalla.
class InicioPantalla extends StatefulWidget {
  final VoidCallback alIrAExplorar; // cambia a la pestaña Explorar
  final int recarga; // cuando cambia, se vuelve a pedir el feed

  const InicioPantalla({
    super.key,
    required this.alIrAExplorar,
    this.recarga = 0,
  });

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  // (texto que se ve, valor que se manda al backend)
  static const _filtros = [
    ('Todos', null),
    ('Turistas', 'turistas'),
    ('Empresas', 'empresas'),
  ];

  String? _autor; // null = todos
  late Future<List<Publicacion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  @override
  void didUpdateWidget(covariant InicioPantalla anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.recarga != widget.recarga) _recargar();
  }

  Future<List<Publicacion>> _cargar() =>
      PublicacionesServicio.feed(autor: _autor);

  void _recargar() => setState(() => _futuro = _cargar());

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Ejecuta [accion] solo si hay sesión; si no, abre el login primero.
  Future<void> _conSesion(VoidCallback accion) async {
    final sesion = context.read<SesionProveedor>();
    if (sesion.estaLogueado) {
      accion();
      return;
    }
    final entro = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPantalla()),
    );
    if (entro == true && mounted) {
      _recargar();
      accion();
    }
  }

  void _abrirExplorar() => widget.alIrAExplorar();

  

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          final nuevo = _cargar();
          setState(() => _futuro = nuevo);
          try {
            await nuevo;
          } catch (_) {
            // el error se muestra en pantalla
          }
        },
        child: FutureBuilder<List<Publicacion>>(
          future: _futuro,
          builder: (context, snapshot) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _encabezado(),
                _bienvenida(),
                _tarjetaExplorar(),
                _tituloPublicaciones(),
                _filtrosAutor(),
                ..._contenidoFeed(snapshot),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- Piezas de la pantalla ----------------
  /// Nombre de la app y campana de notificaciones
  Widget _encabezado() {
    return Container(
      color: Tema.superficie(context),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tema.nombreApp.toUpperCase(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Tema.acento(context),
                  ),
                ),
                Text(
                  Tema.lema,
                  style: TextStyle(fontSize: 13, color: Tema.suave(context)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => _aviso('Las notificaciones vienen después'),
            icon: Icon(Icons.notifications_none,
                size: 28, color: Tema.acento(context)),
          ),
        ],
      ),
    );
  }
  Widget _bienvenida() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Descubre La Ceiba',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Inspírate, explora y encuentra tu próxima aventura.',
            style: TextStyle(fontSize: 15, color: Tema.suave(context)),
          ),
        ],
      ),
    );
  }

  /// "¿A dónde quieres ir?" -> lleva a la pestaña Explorar
  Widget _tarjetaExplorar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Tema.primario,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _abrirExplorar,
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿A dónde quieres ir?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Explora destinos turísticos',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tituloPublicaciones() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 26, 16, 10),
      child: Text(
        'Publicaciones',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Todos / Turistas / Empresas
  Widget _filtrosAutor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: _filtros.map((f) {
          final seleccionado = f.$2 == _autor;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (seleccionado) return;
                  setState(() => _autor = f.$2);
                  _recargar();
                },
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: seleccionado
                        ? Tema.primarioClaro
                        : Tema.chipDe(context),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    f.$1,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: seleccionado
                          ? Colors.white
                          : Tema.suave(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Cargando, error, vacío o las tarjetas
  List<Widget> _contenidoFeed(AsyncSnapshot<List<Publicacion>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (snapshot.hasError) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'No se pudo cargar el feed.\nRevisa que el backend y MySQL estén encendidos.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _recargar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ];
    }

    final publicaciones = snapshot.data ?? [];
    if (publicaciones.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: Text('Aún no hay publicaciones')),
        ),
      ];
    }

       return publicaciones.map((p) {
      return TarjetaPublicacion(
        publicacion: p,
        alDarLike: () =>
            _conSesion(() => _aviso('Dar like se conecta en el siguiente paso')),
        alComentar: () =>
            _aviso('Los comentarios se conectan en un paso próximo'),
         alTocarCuenta: () {
          if (p.esEmpresa && p.lugarId != null) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LugarPerfilPantalla(lugarId: p.lugarId!)));
          } else {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PerfilUsuarioPantalla(usuarioId: p.usuarioId)));
          }
        },
        alGuardar: () => _conSesion(
            () => _aviso('Guardar se conecta cuando hagamos Mi viaje')),
       alAbrir: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PublicacionPantalla(publicacion: p))),
        alVerEmpresa: () {
          if (p.lugarId == null) return;
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => LugarPerfilPantalla(lugarId: p.lugarId!)));
        },
      );
    }).toList();
  }
}