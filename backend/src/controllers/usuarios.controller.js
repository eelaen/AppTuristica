// Perfil público de una persona (turista): datos básicos y sus números.
const pool = require('../config/db')
const path = require('path')
const { limpiar, opcional } = require('../utils/validar')
const { DIR_PERFILES, esImagenReal, borrarArchivo } = require('../utils/imagen')

const aEntero = (valor, defecto) => {
  const n = Number.parseInt(valor, 10)
  return Number.isInteger(n) && n > 0 ? n : defecto
}

// GET /api/usuarios/:id  (pública). No se devuelve el correo.
async function ver(req, res, next) {
  try {
    const id = aEntero(req.params.id, null)
    if (!id) return res.status(400).json({ mensaje: 'Id no válido' })

    const [filas] = await pool.query(
      `SELECT u.id, u.nombre, u.rol, u.biografia, u.foto_perfil, u.creado_en,
              (SELECT COUNT(*) FROM publicaciones p
                 WHERE p.usuario_id = u.id) AS total_publicaciones,
              (SELECT COUNT(*) FROM likes k
                 JOIN publicaciones p2 ON p2.id = k.publicacion_id
                 WHERE p2.usuario_id = u.id) AS total_likes,
              (SELECT COUNT(DISTINCT p3.lugar_id) FROM publicaciones p3
                 WHERE p3.usuario_id = u.id AND p3.lugar_id IS NOT NULL) AS total_lugares
       FROM usuarios u
       WHERE u.id = ?`,
      [id]
    )
    if (!filas[0]) return res.status(404).json({ mensaje: 'Usuario no encontrado' })

    res.json({ usuario: filas[0] })
  } catch (err) {
    next(err)
  }
}
// Borra la foto recién subida y responde con el error
async function rechazar(res, archivo, codigo, mensaje) {
  if (archivo) await borrarArchivo(archivo.path)
  return res.status(codigo).json({ mensaje })
}

// PUT /api/usuarios/me  (necesita token, solo turistas)
// form-data: nombre?, biografia?, imagen? (foto de perfil)
// Lo que no se envía, se queda como estaba.
async function editar(req, res, next) {
  const archivo = req.file
  try {
    const body = req.body || {}

    const [filas] = await pool.query(
      'SELECT nombre, biografia, foto_perfil FROM usuarios WHERE id = ?',
      [req.usuario.id]
    )
    const actual = filas[0]
    if (!actual) return rechazar(res, archivo, 404, 'Usuario no encontrado')

    let nombre = actual.nombre
    if (body.nombre !== undefined) {
      nombre = limpiar(body.nombre)
      if (!nombre || nombre.length > 50) {
        return rechazar(res, archivo, 400, 'El nombre es obligatorio (máximo 50 caracteres)')
      }
    }

    let biografia = actual.biografia
    if (body.biografia !== undefined) {
      biografia = opcional(body.biografia)
      if (biografia && biografia.length > 300) {
        return rechazar(res, archivo, 400, 'La biografía es demasiado larga (máximo 300)')
      }
    }

    let fotoPerfil = actual.foto_perfil
    if (archivo) {
      if (!(await esImagenReal(archivo.path))) {
        return rechazar(res, archivo, 400, 'El archivo no es una imagen válida')
      }
      fotoPerfil = `/uploads/perfiles/${archivo.filename}`
    }

    await pool.query(
      'UPDATE usuarios SET nombre = ?, biografia = ?, foto_perfil = ? WHERE id = ?',
      [nombre, biografia, fotoPerfil, req.usuario.id]
    )

    // Si subió una foto nueva, se borra la anterior
    if (archivo && actual.foto_perfil) {
      await borrarArchivo(path.join(DIR_PERFILES, path.basename(actual.foto_perfil)))
    }

    res.json({
      mensaje: 'Perfil actualizado',
      usuario: { id: req.usuario.id, nombre, biografia, foto_perfil: fotoPerfil }
    })
  } catch (err) {
    if (archivo) await borrarArchivo(archivo.path)
    next(err)
  }
}

module.exports = { ver, editar }