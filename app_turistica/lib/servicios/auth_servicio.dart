import '../modelos/usuario.dart';
import 'api_cliente.dart';

/// Lo que devuelve el backend al iniciar sesión.
class RespuestaLogin {
  final String token;
  final String refreshToken;
  final Usuario usuario;
  const RespuestaLogin({
    required this.token,
    required this.refreshToken,
    required this.usuario,
  });
}

/// Peticiones de autenticación.
class AuthServicio {
  /// Inicia sesión. Ruta del backend: POST /api/auth/login
   static Future<RespuestaLogin> login({
    required String email,
    required String password,
  }) async {
    final respuesta = await ApiCliente.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return RespuestaLogin(
      token: respuesta.data['token'] as String,
      refreshToken: respuesta.data['refreshToken'] as String,
      usuario: Usuario.fromJson(respuesta.data['usuario'] as Map<String, dynamic>),
    );
  }

  /// Cierra la sesión de este dispositivo en el servidor. POST /api/auth/cerrar-sesion
  static Future<void> cerrarSesion(String refreshToken) async {
    await ApiCliente.dio
        .post('/auth/cerrar-sesion', data: {'refreshToken': refreshToken});
  }
  /// Crea una cuenta de turista. Ruta del backend: POST /api/auth/registro/usuario
  static Future<void> registrarUsuario({
    required String nombre,
    required String email,
    required String password,
  }) async {
    await ApiCliente.dio.post(
      '/auth/registro/usuario',
      data: {'nombre': nombre, 'email': email, 'password': password},
    );
  }

  /// Crea una cuenta de lugar turístico (cuenta + lugar).
  /// Ruta del backend: POST /api/auth/registro/empresa
  /// Los campos opcionales vacíos no se envían.
    static Future<void> registrarEmpresa({
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
    await ApiCliente.dio.post(
      '/auth/registro/empresa',
      data: {
        'nombre_lugar': nombreLugar,
        'email': email,
        'password': password,
        'descripcion': descripcion,
        'categorias': categorias,
        if (direccion.isNotEmpty) 'direccion': direccion,
        if (telefono.isNotEmpty) 'telefono': telefono,
        if (horario.isNotEmpty) 'horario': horario,
        if (latitud != null && longitud != null) ...{
          'latitud': latitud,
          'longitud': longitud,
        },
      },
    );
  }
  /// Pide los datos de quien tiene la sesión (usa el token guardado).
  /// Ruta del backend: GET /api/auth/perfil
  static Future<Usuario> perfil() async {
    final respuesta = await ApiCliente.dio.get('/auth/perfil');
    return Usuario.fromJson(respuesta.data['usuario'] as Map<String, dynamic>);
  }
}