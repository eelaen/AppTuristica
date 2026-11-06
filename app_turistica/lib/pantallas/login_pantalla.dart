import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tema.dart';
import '../proveedores/sesion_proveedor.dart';
import '../servicios/api_cliente.dart';
import 'registro_pantalla.dart';

/// Pantalla de inicio de sesión.
/// Al cerrarse devuelve true si la persona entró, o false si prefirió seguir como visitante.
class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _ocultarPassword = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Valida el formulario y manda correo y contraseña al backend
  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await context
          .read<SesionProveedor>()
          .iniciarSesion(_email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(true); // entró: se cierra la pantalla
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiCliente.mensajeDeError(e);
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo provisional
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Tema.primario,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    Tema.siglas,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Inicia sesión',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Para dar like, comentar y subir fotos.',
                  style: TextStyle(color: Tema.suave(context)),
                ),
                const SizedBox(height: 24),

                // Correo
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    final texto = (valor ?? '').trim();
                    if (texto.isEmpty) return 'Escribe tu correo';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(texto)) {
                      return 'Correo no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contraseña
                TextFormField(
                  controller: _password,
                  obscureText: _ocultarPassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _ocultarPassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      icon: Icon(_ocultarPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _ocultarPassword = !_ocultarPassword),
                    ),
                  ),
                  validator: (valor) =>
                      (valor ?? '').isEmpty ? 'Escribe tu contraseña' : null,
                  onFieldSubmitted: (_) => _entrar(),
                ),

                // Error que manda el backend
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),

                // Botón de entrar
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Tema.primarioClaro,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _cargando ? null : _entrar,
                    child: _cargando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 8),

                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Tema.acento(context),
                    ),
                    onPressed: () async {
                      // Abre el registro; si la cuenta se creó, también se cierra el login
                      final creada = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const RegistroPantalla()),
                      );
                      if (creada == true && context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text('¿No tienes cuenta? Crear cuenta'),
                  ),
                ),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Tema.suave(context),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Seguir explorando sin cuenta'),
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