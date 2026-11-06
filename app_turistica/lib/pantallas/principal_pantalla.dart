import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/tema.dart';
import '../proveedores/sesion_proveedor.dart';
import '../widgets/barra_inferior.dart';
import 'explorar_pantalla.dart';
import 'inicio_pantalla.dart';
import 'login_pantalla.dart';
import 'lugar_perfil_pantalla.dart';
import 'perfil_usuario_pantalla.dart';
import 'subir_publicacion_pantalla.dart';

/// Contiene la barra inferior (siempre visible). Cada pestaña tiene su propio
/// navegador: lo que se abre dentro de una pestaña no tapa la barra.
/// Pestañas: 0 inicio, 1 explorar, 2 crear, 3 mi viaje, 4 perfil.
class PrincipalPantalla extends StatefulWidget {
  const PrincipalPantalla({super.key});

  @override
  State<PrincipalPantalla> createState() => _PrincipalPantallaState();
}

class _PrincipalPantallaState extends State<PrincipalPantalla> {
  int _pestana = 0;
  int _claveSubir = 0; // al cambiar, el formulario de publicar se reinicia
  final _recargaFeed = ValueNotifier<int>(0); // al cambiar, el Inicio pide el feed
  final _llaves = List.generate(5, (_) => GlobalKey<NavigatorState>());

  @override
  void dispose() {
    _recargaFeed.dispose();
    super.dispose();
  }

  /// true si hay sesión; si no, abre el login y devuelve si la persona entró.
  Future<bool> _asegurarSesion() async {
    if (context.read<SesionProveedor>().estaLogueado) return true;
    final entro = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPantalla()),
    );
    if (!mounted) return false;
    if (entro == true) _recargaFeed.value++;
    return entro == true;
  }

  Future<void> _alTocarBarra(int i) async {
    // Crear y Perfil piden sesión
    if ((i == 2 || i == 4) && (!await _asegurarSesion() || !mounted)) return;

    if (i == _pestana) {
      // Tocar la pestaña actual: vuelve a su pantalla inicial
      _llaves[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _pestana = i);
    }
  }

  /// Cada pestaña es un navegador propio
  Widget _tab(int i, WidgetBuilder raiz) {
    return Navigator(
      key: _llaves[i],
      onGenerateRoute: (_) => MaterialPageRoute(builder: raiz),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _llaves[_pestana].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop(); // cierra lo abierto dentro de la pestaña
        } else if (_pestana != 0) {
          setState(() => _pestana = 0); // vuelve al Inicio
        } else {
          SystemNavigator.pop(); // sale de la app
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _pestana,
          children: [
            _tab(
              0,
              (_) => ValueListenableBuilder<int>(
                valueListenable: _recargaFeed,
                builder: (_, recarga, _) => InicioPantalla(
                  alIrAExplorar: () => setState(() => _pestana = 1),
                  recarga: recarga,
                ),
              ),
            ),
            _tab(1, (_) => const ExplorarPantalla()),
            // 2 = Crear: solo se arma cuando se entra (así empieza vacío)
            _pestana == 2
                ? SubirPublicacionPantalla(
                    key: ValueKey(_claveSubir),
                    alPublicar: () {
                      setState(() {
                        _claveSubir++;
                        _pestana = 0;
                      });
                      _recargaFeed.value++;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Publicación creada'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                  )
                : const SizedBox.shrink(),
            _tab(3, (_) => const _MiViajePantalla()),
            _tab(
              4,
              (_) => _PerfilPestana(alIniciarSesion: () => _alTocarBarra(4)),
            ),
          ],
        ),
        bottomNavigationBar:
            BarraInferior(seleccionado: _pestana, alTocar: _alTocarBarra),
      ),
    );
  }
}

/// Contenido de la pestaña Perfil: depende de quién tiene la sesión.
class _PerfilPestana extends StatelessWidget {
  final VoidCallback alIniciarSesion;
  const _PerfilPestana({required this.alIniciarSesion});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<SesionProveedor>().usuario;

    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Inicia sesión para ver tu perfil.',
                  style: TextStyle(color: Tema.suave(context))),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size(180, 44)),
                onPressed: alIniciarSesion,
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      );
    }

    if (usuario.esEmpresa) {
      // La llave hace que se recargue si cambia la persona con sesión
      return LugarPerfilPantalla(key: ValueKey('lugar-${usuario.id}'), esMio: true);
    }
        return PerfilUsuarioPantalla(
        key: ValueKey('usuario-${usuario.id}'), usuarioId: usuario.id);
  }
}

/// Provisional hasta que hagamos los guardados.
class _MiViajePantalla extends StatelessWidget {
  const _MiViajePantalla();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi viaje')),
      body: Center(
        child: Text(
          'Aquí verás los lugares que guardes.',
          style: TextStyle(color: Tema.suave(context)),
        ),
      ),
    );
  }
}