// Perfil público de una persona (turista): datos básicos y sus números.
const pool = require('../config/db')

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

module.exports = { ver }