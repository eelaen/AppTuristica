import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'almacen_token.dart';

/// Cliente HTTP único de la app. Todas las peticiones al backend pasan por aquí:
/// la dirección, los tiempos de espera, el token y su renovación automática.
class ApiCliente {
  /// Token de acceso de la sesión actual (null si no hay sesión).
  static String? token;

  /// Se llama cuando la sesión ya no se puede renovar (SesionProveedor la escucha).
  static void Function()? alSesionExpirada;

  static final BaseOptions _opciones = BaseOptions(
    baseUrl: ApiConfig.apiUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  );

  /// Cliente sin interceptores, solo para pedir la renovación
  static final Dio _sinInterceptores = Dio(_opciones);

  static final Dio dio = _crear();

  /// Si ya hay una renovación en curso, todas las peticiones esperan a esa misma
  static Future<bool>? _renovando;

  static Dio _crear() {
    final cliente = Dio(_opciones);

    cliente.interceptors.add(InterceptorsWrapper(
      // Antes de cada petición: si hay sesión, se agrega el token
      onRequest: (opciones, handler) {
        final t = token;
        if (t != null) opciones.headers['Authorization'] = 'Bearer $t';
        handler.next(opciones);
      },

      // Si el token venció (401), se renueva y se repite la petición
      onError: (error, handler) async {
        final opciones = error.requestOptions;
        final enviado = opciones.headers['Authorization'];

        final sePuedeRenovar = error.response?.statusCode == 401 &&
            enviado != null && // era una petición con sesión
            !opciones.path.contains('/auth/') && // no el login ni la renovación
            opciones.extra['reintentado'] != true;

        if (!sePuedeRenovar) return handler.next(error);

        // Si otra petición ya renovó mientras esta viajaba, basta con repetirla
        if (enviado == 'Bearer $token') {
          _renovando ??= _renovar().whenComplete(() => _renovando = null);
          final ok = await _renovando!;
          if (!ok) return handler.next(error);
        }

        try {
          opciones.extra['reintentado'] = true;
          opciones.headers['Authorization'] = 'Bearer $token';
          // Un FormData solo se puede enviar una vez: se reconstruye
          if (opciones.data is FormData) {
            opciones.data = (opciones.data as FormData).clone();
          }
          final respuesta = await cliente.fetch(opciones);
          handler.resolve(respuesta);
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ));

    return cliente;
  }

  /// Cambia el token de renovación por un par nuevo. true si salió bien.
  static Future<bool> _renovar() async {
    final renovacion = await AlmacenToken.leerRenovacion();
    if (renovacion == null) {
      await _expirar();
      return false;
    }
    try {
      final r = await _sinInterceptores
          .post('/auth/renovar', data: {'refreshToken': renovacion});
      final nuevoAcceso = r.data['token'] as String;
      final nuevaRenovacion = r.data['refreshToken'] as String;
      token = nuevoAcceso;
      await AlmacenToken.guardarPar(nuevoAcceso, nuevaRenovacion);
      return true;
    } on DioException catch (e) {
      final codigo = e.response?.statusCode;
      // 400/401: la sesión de verdad ya no sirve. Si solo falló la conexión, se conserva.
      if (codigo == 400 || codigo == 401) await _expirar();
      return false;
    }
  }

  static Future<void> _expirar() async {
    token = null;
    await AlmacenToken.borrar();
    alSesionExpirada?.call();
  }

  /// Convierte un error en un mensaje que se le puede mostrar a la persona.
  static String mensajeDeError(Object error) {
    if (error is DioException) {
      final datos = error.response?.data;
      if (datos is Map && datos['mensaje'] is String) {
        return datos['mensaje'] as String;
      }
      if (error.response == null) {
        return 'No se pudo conectar con el servidor. Revisa tu conexión.';
      }
    }
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }
}