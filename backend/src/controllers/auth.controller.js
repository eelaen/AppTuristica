// Lógica de autenticación: registro (usuario y empresa), login y perfil.
const bcrypt = require('bcryptjs')
const pool = require('../config/db')
const { crearAccessToken, crearSesion } = require('../utils/sesiones')
const { limpiar, opcional, validarCuenta, validarLugar,coordenada } = require('../utils/validar')
const {
  resolverCategorias,
  guardarCategorias,
  adjuntarCategorias
} = require('../utils/categorias')

const RONDAS = 10 // qué tan "pesado" es el encriptado (más alto = más seguro y más lento)

// ---------------------------------------------------------------
// POST /api/auth/registro/usuario
// Crea una cuenta de turista. Solo guarda una fila en la tabla usuarios.
// Body: { nombre, email, password }
// ---------------------------------------------------------------
async function registrarUsuario(req, res, next) {
  try {
    // 1. Leer y limpiar los datos
    const nombre = limpiar(req.body.nombre)
    const email = limpiar(req.body.email).toLowerCase()
    const { password } = req.body

    // 2. Validar
    const error = validarCuenta({ nombre, email, password })
    if (error) return res.status(400).json({ mensaje: error })

    // 3. Encriptar la contraseña (nunca se guarda la real)
    const hash = await bcrypt.hash(password, RONDAS)

    // 4. Guardar. Los "?" evitan la inyección de SQL
    const [resultado] = await pool.query(
      'INSERT INTO usuarios (nombre, email, password, rol) VALUES (?, ?, ?, ?)',
      [nombre, email, hash, 'usuario']
    )

    // 5. Responder (sin devolver la contraseña)
    res.status(201).json({
      mensaje: 'Cuenta creada correctamente',
      usuario: { id: resultado.insertId, nombre, email, rol: 'usuario' }
    })
  } catch (err) {
    // El correo ya existe (la columna email es UNIQUE)
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ mensaje: 'Ese correo ya está registrado' })
    }
    next(err)
  }
}

// ---------------------------------------------------------------
// POST /api/auth/registro/empresa
// Crea la cuenta de empresa Y su lugar turístico en una transacción:
// si falla uno de los pasos, no se guarda ninguno.
// Body: { nombre_lugar, email, password, descripcion, categorias: ["naturaleza", ...],
//         direccion?, telefono?, horario? }
// ---------------------------------------------------------------
async function registrarEmpresa(req, res, next) {
  // Conexión exclusiva: la transacción debe usar siempre la misma conexión
  const conexion = await pool.getConnection()
  try {
    // 1. Leer y limpiar los datos
    const nombre = limpiar(req.body.nombre_lugar) // el nombre de la cuenta es el del lugar
    const email = limpiar(req.body.email).toLowerCase()
    const { password } = req.body
    const descripcion = limpiar(req.body.descripcion)
    const direccion = opcional(req.body.direccion)
    const telefono = opcional(req.body.telefono)
    const horario = opcional(req.body.horario)

    // 2. Validar la cuenta, el lugar y las categorías (estas contra la base de datos)
    const error =
      validarCuenta({ nombre, email, password }) ||
      validarLugar({ descripcion, direccion, telefono, horario })
    if (error) return res.status(400).json({ mensaje: error })

    const categorias = await resolverCategorias(conexion, req.body.categorias)
    if (categorias.error) return res.status(400).json({ mensaje: categorias.error })


          // Ubicación en el mapa (opcional, pero si viene deben ser las dos)
    let latitud = null
    let longitud = null
    if (req.body.latitud !== undefined || req.body.longitud !== undefined) {
      const lat = coordenada(req.body.latitud, 90)
      const lng = coordenada(req.body.longitud, 180)
      if (lat === undefined || lng === undefined) {
        return res.status(400).json({ mensaje: 'La ubicación no es válida' })
      }
      latitud = lat
      longitud = lng
    }

    // 3. Encriptar la contraseña
    const hash = await bcrypt.hash(password, RONDAS)

    // 4. Transacción: crear cuenta + lugar + categorías
    await conexion.beginTransaction()

    const [usuario] = await conexion.query(
      'INSERT INTO usuarios (nombre, email, password, rol) VALUES (?, ?, ?, ?)',
      [nombre, email, hash, 'empresa']
    )

       const [lugar] = await conexion.query(
      `INSERT INTO lugares
         (usuario_id, tipo, nombre, descripcion, direccion, telefono, horario, latitud, longitud)
       VALUES (?, 'empresa', ?, ?, ?, ?, ?, ?, ?)`,
      [usuario.insertId, nombre, descripcion, direccion, telefono, horario, latitud, longitud]
    )

    await guardarCategorias(conexion, lugar.insertId, categorias.ids)

    await conexion.commit() // todo salió bien: se guarda todo junto

    // 5. Responder
    res.status(201).json({
      mensaje: 'Cuenta de lugar turístico creada correctamente',
      usuario: { id: usuario.insertId, nombre, email, rol: 'empresa' },
      lugar: { id: lugar.insertId, nombre, tipo: 'empresa' }
    })
  } catch (err) {
    await conexion.rollback() // algo falló: se deshace todo
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ mensaje: 'Ese correo ya está registrado' })
    }
    next(err)
  } finally {
    conexion.release() // devolver la conexión al pool, pase lo que pase
  }
}

// ---------------------------------------------------------------
// POST /api/auth/login
// Comprueba correo y contraseña y devuelve un token de acceso (JWT corto)
// y un token de renovación.
// Body: { email, password }
// ---------------------------------------------------------------

// Hash de mentira: se usa cuando el correo no existe, para que la respuesta
// tarde lo mismo y nadie pueda adivinar qué correos están registrados.
const HASH_FALSO = bcrypt.hashSync('contrasena-falsa-123', RONDAS)

async function login(req, res, next) {
  try {
    const email = limpiar(req.body.email).toLowerCase()
    const { password } = req.body

    if (!email || typeof password !== 'string' || !password) {
      return res.status(400).json({ mensaje: 'Escribe tu correo y tu contraseña' })
    }

    // Buscar al usuario por correo
    const [filas] = await pool.query(
      'SELECT id, nombre, email, password, rol FROM usuarios WHERE email = ?',
      [email]
    )
    const usuario = filas[0]

    // Siempre se compara una contraseña, exista o no el correo
    const coincide = await bcrypt.compare(password, usuario ? usuario.password : HASH_FALSO)

    // Mismo mensaje para "correo no existe" y "contraseña mala"
    if (!usuario || !coincide) {
      return res.status(401).json({ mensaje: 'Correo o contraseña incorrectos' })
    }

    // Crear la sesión: un token de acceso corto (JWT) y un token de renovación
    // (de este solo se guarda la huella en la base de datos)
    const token = crearAccessToken(usuario)
    const refreshToken = await crearSesion(pool, usuario.id)

    res.json({
      mensaje: 'Sesión iniciada',
      token,
      refreshToken,
      usuario: { id: usuario.id, nombre: usuario.nombre, email: usuario.email, rol: usuario.rol }
    })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// GET /api/auth/perfil   (ruta protegida: necesita token)
// Devuelve los datos de quien tiene la sesión iniciada.
// Si es empresa, incluye también los datos de su lugar.
// ---------------------------------------------------------------
async function perfil(req, res, next) {
  try {
    // req.usuario lo llena el middleware verificarToken
    const [filas] = await pool.query(
      `SELECT id, nombre, email, rol, biografia, foto_perfil, creado_en
       FROM usuarios WHERE id = ?`,
      [req.usuario.id]
    )
    const usuario = filas[0]
    if (!usuario) return res.status(404).json({ mensaje: 'Usuario no encontrado' })

    let lugar = null
    if (usuario.rol === 'empresa') {
      const [lugares] = await pool.query(
        `SELECT id, nombre, descripcion, direccion, telefono, horario, foto_portada,
                latitud, longitud, verificado
         FROM lugares WHERE usuario_id = ?`,
        [usuario.id]
      )
      if (lugares[0]) {
        const [conCategorias] = await adjuntarCategorias(pool, [lugares[0]])
        lugar = { ...conCategorias, verificado: Boolean(conCategorias.verificado) }
      }
    }

    res.json({ usuario, lugar })
  } catch (err) {
    next(err)
  }
}

module.exports = { registrarUsuario, registrarEmpresa, login, perfil }