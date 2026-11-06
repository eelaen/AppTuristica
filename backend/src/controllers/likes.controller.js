// Lógica de los likes: dar y quitar like a una publicación.
const pool = require('../config/db')

// Convierte un valor a entero positivo; si no sirve, devuelve el valor por defecto
const aEntero = (valor, defecto) => {
  const n = Number.parseInt(valor, 10)
  return Number.isInteger(n) && n > 0 ? n : defecto
}

// Cuenta cuántos likes tiene una publicación
async function contarLikes(publicacionId) {
  const [filas] = await pool.query(
    'SELECT COUNT(*) AS total FROM likes WHERE publicacion_id = ?',
    [publicacionId]
  )
  return filas[0].total
}

// Revisa que la publicación exista
async function existePublicacion(id) {
  const [filas] = await pool.query('SELECT id FROM publicaciones WHERE id = ?', [id])
  return filas.length > 0
}

// ---------------------------------------------------------------
// POST /api/publicaciones/:id/like   (necesita token)
// Da like. Si ya lo había dado, no pasa nada (no se duplica).
// ---------------------------------------------------------------
async function darLike(req, res, next) {
  try {
    const id = aEntero(req.params.id, null)
    if (!id) return res.status(400).json({ mensaje: 'Id no válido' })
    if (!(await existePublicacion(id))) {
      return res.status(404).json({ mensaje: 'Publicación no encontrada' })
    }

    // INSERT IGNORE: si el like ya existe (llave primaria repetida), lo ignora sin error
    await pool.query('INSERT IGNORE INTO likes (usuario_id, publicacion_id) VALUES (?, ?)', [
      req.usuario.id,
      id
    ])

    res.json({ likes: await contarLikes(id), yo_di_like: true })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// DELETE /api/publicaciones/:id/like   (necesita token)
// Quita el like. Si no lo había dado, no pasa nada.
// ---------------------------------------------------------------
async function quitarLike(req, res, next) {
  try {
    const id = aEntero(req.params.id, null)
    if (!id) return res.status(400).json({ mensaje: 'Id no válido' })
    if (!(await existePublicacion(id))) {
      return res.status(404).json({ mensaje: 'Publicación no encontrada' })
    }

    // Solo borra el like de ESTA persona (el id sale del token)
    await pool.query('DELETE FROM likes WHERE usuario_id = ? AND publicacion_id = ?', [
      req.usuario.id,
      id
    ])

    res.json({ likes: await contarLikes(id), yo_di_like: false })
  } catch (err) {
    next(err)
  }
}

module.exports = { darLike, quitarLike }