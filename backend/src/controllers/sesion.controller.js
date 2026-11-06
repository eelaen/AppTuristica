// Lógica de las sesiones: renovar el token de acceso y cerrar sesión.
const pool = require('../config/db')
const {
  hashear,
  crearAccessToken,
  crearSesion,
  cerrarFamilia,
  cerrarTodas: cerrarTodasDeUsuario
} = require('../utils/sesiones')

// Mensaje único para cualquier problema con el token de renovación
// (no se dice si no existe, si venció o si ya se usó)
const SESION_NO_VALIDA = { mensaje: 'Sesión no válida. Inicia sesión de nuevo' }

// Lee el token de renovación del cuerpo de la petición. Devuelve null si no sirve.
function leerRenovacion(req) {
  const token = (req.body || {}).refreshToken
  return typeof token === 'string' && token.length >= 20 && token.length <= 200 ? token : null
}

// ---------------------------------------------------------------
// POST /api/auth/renovar
// Cambia un token de renovación por un par nuevo (acceso + renovación).
// Body: { refreshToken }
// Cada token de renovación sirve UNA sola vez ("rotación").
// ---------------------------------------------------------------
async function renovar(req, res, next) {
  const conexion = await pool.getConnection()
  try {
    const renovacion = leerRenovacion(req)
    if (!renovacion) {
      return res.status(400).json({ mensaje: 'Falta el token de renovación' })
    }

    // 1. Buscar la sesión por la huella del token (y traer los datos actuales de la persona)
    const [filas] = await conexion.query(
      `SELECT s.id, s.usuario_id, s.familia, s.expira_en, s.usado_en,
              u.nombre, u.email, u.rol
       FROM sesiones s
       JOIN usuarios u ON u.id = s.usuario_id
       WHERE s.token_hash = ?`,
      [hashear(renovacion)]
    )
    const sesion = filas[0]
    if (!sesion) return res.status(401).json(SESION_NO_VALIDA)

    // 2. Si el token YA SE USÓ y reaparece, alguien lo copió:
    //    se cancela toda la cadena de ese dispositivo.
    if (sesion.usado_en) {
      await cerrarFamilia(sesion.familia)
      console.warn(`Token de renovación reutilizado (usuario ${sesion.usuario_id}): sesión cancelada`)
      return res.status(401).json(SESION_NO_VALIDA)
    }

    // 3. Si venció, no sirve
    if (new Date(sesion.expira_en) < new Date()) {
      await cerrarFamilia(sesion.familia)
      return res.status(401).json(SESION_NO_VALIDA)
    }

    // 4. Marcar este token como usado y crear el siguiente, todo junto (transacción)
    await conexion.beginTransaction()

    // "AND usado_en IS NULL" evita que dos peticiones usen el mismo token a la vez
    const [marcado] = await conexion.query(
      'UPDATE sesiones SET usado_en = ? WHERE id = ? AND usado_en IS NULL',
      [new Date(), sesion.id]
    )
    if (marcado.affectedRows !== 1) {
      await conexion.rollback()
      await cerrarFamilia(sesion.familia)
      return res.status(401).json(SESION_NO_VALIDA)
    }

    const nuevaRenovacion = await crearSesion(conexion, sesion.usuario_id, sesion.familia)
    await conexion.commit()

    // 5. Responder con los dos tokens nuevos (el rol sale de la base, no de un token viejo)
    const usuario = { id: sesion.usuario_id, nombre: sesion.nombre, email: sesion.email, rol: sesion.rol }
    res.json({
      token: crearAccessToken(usuario),
      refreshToken: nuevaRenovacion,
      usuario
    })
  } catch (err) {
    await conexion.rollback()
    next(err)
  } finally {
    conexion.release()
  }
}

// ---------------------------------------------------------------
// POST /api/auth/cerrar-sesion
// Cierra la sesión de ESTE dispositivo. No pide el token de acceso, porque
// puede que ya haya vencido. Siempre responde bien (aunque ya estuviera cerrada).
// Body: { refreshToken }
// ---------------------------------------------------------------
async function cerrarSesion(req, res, next) {
  try {
    const renovacion = leerRenovacion(req)
    if (renovacion) {
      const [filas] = await pool.query('SELECT familia FROM sesiones WHERE token_hash = ?', [
        hashear(renovacion)
      ])
      if (filas[0]) await cerrarFamilia(filas[0].familia)
    }
    res.json({ mensaje: 'Sesión cerrada' })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// POST /api/auth/cerrar-todas   (necesita token de acceso)
// Cierra la sesión en TODOS los dispositivos de la persona.
// ---------------------------------------------------------------
async function cerrarTodas(req, res, next) {
  try {
    await cerrarTodasDeUsuario(req.usuario.id)
    res.json({ mensaje: 'Se cerró la sesión en todos tus dispositivos' })
  } catch (err) {
    next(err)
  }
}

module.exports = { renovar, cerrarSesion, cerrarTodas }