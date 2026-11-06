import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../modelos/usuario.dart';
import '../servicios/almacen_token.dart';
import '../servicios/api_cliente.dart';
import '../servicios/auth_servicio.dart';

/// Guarda quién tiene la sesión iniciada. Cualquier pantalla puede consultarlo
/// y se actualiza sola cuando alguien entra o sale (Provider).
class SesionProveedor extends ChangeNotifier {
  Usuario? _usuario;

    SesionProveedor() {
    ApiCliente.alSesionExpirada = () {
      _usuario = null;
      notifyListeners();
    };
  }

  /// La persona con sesión, o null si es visitante
  Usuario? get usuario => _usuario;

  bool get estaLogueado => _usuario != null;

  /// Se llama al abrir la app: si hay un token guardado, comprueba que siga siendo válido.
  Future<void> restaurar() async {
    final token = await AlmacenToken.leer();
    if (token == null) return;

    ApiCliente.token = token;
    try {
      _usuario = await AuthServicio.perfil();
    } on DioException catch (e) {
      // 401: el token venció o no sirve, se descarta.
      // Si solo falló la conexión, se conserva para intentar de nuevo después.
      if (e.response?.statusCode == 401) {
        await cerrarSesion();
        return;
      }
    }
    notifyListeners();
  }

  /// Inicia sesión. Si algo falla, el error llega a la pantalla que lo llamó.
  Future<void> iniciarSesion(String email, String password) async {
       final respuesta = await AuthServicio.login(email: email, password: password);
    ApiCliente.token = respuesta.token;
    await AlmacenToken.guardarPar(respuesta.token, respuesta.refreshToken);
    _usuario = respuesta.usuario;
    notifyListeners();
  }

  /// Crea una cuenta de turista y entra con ella.
  Future<void> registrarUsuario({
    required String nombre,
    required String email,
    required String password,
  }) async {
    await AuthServicio.registrarUsuario(nombre: nombre, email: email, password: password);
    await iniciarSesion(email, password);
  }

  /// Crea una cuenta de lugar turístico (con su lugar) y entra con ella.
  Future<void> registrarEmpresa({
    required String nombreLugar,
    required String email,
    required String password,
    required String descripcion,
    required List<String> categorias,
    String direccion = '',
    String telefono = '',
    String horario = '',
    double? latitud,
    double? longitud,
  }) async {
    await AuthServicio.registrarEmpresa(
      nombreLugar: nombreLugar,
      email: email,
      password: password,
      descripcion: descripcion,
      categorias: categorias,
      direccion: direccion,
      telefono: telefono,
      horario: horario,
      latitud: latitud,
      longitud: longitud,
    );
    await iniciarSesion(email, password);
  }
  /// Cierra la sesión: borra el token del dispositivo y de la memoria.
   /// Cierra la sesión: la invalida en el servidor y borra los tokens del dispositivo.
  Future<void> cerrarSesion() async {
    final renovacion = await AlmacenToken.leerRenovacion();
    ApiCliente.token = null;
    await AlmacenToken.borrar();
    _usuario = null;
    notifyListeners();
    if (renovacion != null) {
      try {
        await AuthServicio.cerrarSesion(renovacion);
      } catch (_) {
        // si no hay conexión, igual queda cerrada en el teléfono
      }
    }
  }
}