// Lógica de los comentarios de las publicaciones: listar, crear y eliminar.
const pool = require('../config/db')
const { limpiar } = require('../utils/validar')

const TEXTO_MAX = 500

// Convierte un valor a entero positivo; si no sirve, devuelve el valor por defecto
const aEntero = (valor, defecto) => {
  const n = Number.parseInt(valor, 10)
  return Number.isInteger(n) && n > 0 ? n : defecto
}

// Revisa que la publicación exista
async function existePublicacion(id) {
  const [filas] = await pool.query('SELECT id FROM publicaciones WHERE id = ?', [id])
  return filas.length > 0
}

// ---------------------------------------------------------------
// GET /api/publicaciones/:id/comentarios?pagina=1&limite=20
// Lista los comentarios de una publicación, del más antiguo al más nuevo.
// Ruta pública.
// ---------------------------------------------------------------
async function listar(req, res, next) {
  try {
    const id = aEntero(req.params.id, null)
    if (!id) return res.status(400).json({ mensaje: 'Id no válido' })
    if (!(await existePublicacion(id))) {
      return res.status(404).json({ mensaje: 'Publicación no encontrada' })
    }

    const pagina = aEntero(req.query.pagina, 1)
    const limite = Math.min(aEntero(req.query.limite, 20), 50) // máximo 50 por página

    const [comentarios] = await pool.query(
      `SELECT c.id, c.texto, c.creado_en,
              u.id AS usuario_id, u.nombre AS usuario_nombre, u.rol AS usuario_rol
       FROM comentarios c
       JOIN usuarios u ON u.id = c.usuario_id
       WHERE c.publicacion_id = ?
       ORDER BY c.creado_en ASC, c.id ASC
       LIMIT ? OFFSET ?`,
      [id, limite, (pagina - 1) * limite]
    )

    res.json({ pagina, limite, comentarios })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// POST /api/publicaciones/:id/comentarios   (necesita token)
// Escribe un comentario. Body: { texto }
// ---------------------------------------------------------------
async function crear(req, res, next) {
  try {
    const id = aEntero(req.params.id, null)
    if (!id) return res.status(400).json({ mensaje: 'Id no válido' })

    const texto = limpiar((req.body || {}).texto)
    if (texto.length < 1 || texto.length > TEXTO_MAX) {
      return res
        .status(400)
        .json({ mensaje: `El comentario debe tener entre 1 y ${TEXTO_MAX} caracteres` })
    }

    if (!(await existePublicacion(id))) {
      return res.status(404).json({ mensaje: 'Publicación no encontrada' })
    }

    const [resultado] = await pool.query(
      'INSERT INTO comentarios (publicacion_id, usuario_id, texto) VALUES (?, ?, ?)',
      [id, req.usuario.id, texto]
    )

    // Se devuelve el comentario completo, con el nombre de quien lo escribió
    const [filas] = await pool.query(
      `SELECT c.id, c.texto, c.creado_en,
              u.id AS usuario_id, u.nombre AS usuario_nombre, u.rol AS usuario_rol
       FROM comentarios c
       JOIN usuarios u ON u.id = c.usuario_id
       WHERE c.id = ?`,
      [resultado.insertId]
    )

    res.status(201).json({ mensaje: 'Comentario publicado', comentario: filas[0] })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// DELETE /api/publicaciones/:id/comentarios/:comentarioId   (necesita token)
// Pueden borrarlo: quien lo escribió, o el dueño de la publicación.
// ---------------------------------------------------------------
async function eliminar(req, res, next) {
  try {
    const publicacionId = aEntero(req.params.id, null)
    const comentarioId = aEntero(req.params.comentarioId, null)
    if (!publicacionId || !comentarioId) {
      return res.status(400).json({ mensaje: 'Id no válido' })
    }

    const [filas] = await pool.query(
      `SELECT c.id, c.usuario_id, p.usuario_id AS dueno_publicacion
       FROM comentarios c
       JOIN publicaciones p ON p.id = c.publicacion_id
       WHERE c.id = ? AND c.publicacion_id = ?`,
      [comentarioId, publicacionId]
    )
    const comentario = filas[0]

    // Si no existe o no tiene permiso, la respuesta es la misma (no se revela cuál)
    const tienePermiso =
      comentario &&
      (comentario.usuario_id === req.usuario.id || comentario.dueno_publicacion === req.usuario.id)
    if (!tienePermiso) {
      return res.status(404).json({ mensaje: 'Comentario no encontrado' })
    }

    await pool.query('DELETE FROM comentarios WHERE id = ?', [comentarioId])
    res.json({ mensaje: 'Comentario eliminado' })
  } catch (err) {
    next(err)
  }
}

module.exports = { listar, crear, eliminar }