// Reseñas de los lugares: listar y dejar (o actualizar) la propia.
const pool = require('../config/db')
const { opcional } = require('../utils/validar')

const aEntero = (valor, defecto) => {
  const n = Number.parseInt(valor, 10)
  return Number.isInteger(n) && n > 0 ? n : defecto
}

// GET /api/lugares/:id/resenas  (pública)
async function listar(req, res, next) {
  try {
    const lugarId = aEntero(req.params.id, null)
    if (!lugarId) return res.status(400).json({ mensaje: 'Id no válido' })
    const pagina = aEntero(req.query.pagina, 1)
    const limite = Math.min(aEntero(req.query.limite, 20), 50)

    const [resenas] = await pool.query(
      `SELECT r.id, r.estrellas, r.texto, r.creado_en,
              u.id AS usuario_id, u.nombre AS usuario_nombre
       FROM resenas r
       JOIN usuarios u ON u.id = r.usuario_id
       WHERE r.lugar_id = ?
       ORDER BY r.creado_en DESC, r.id DESC
       LIMIT ? OFFSET ?`,
      [lugarId, limite, (pagina - 1) * limite]
    )
    res.json({ pagina, limite, resenas })
  } catch (err) {
    next(err)
  }
}

// POST /api/lugares/:id/resenas  (token y rol "usuario")
// Body: { estrellas: 1-5, texto? }. Si ya había dejado una, se reemplaza.
async function guardar(req, res, next) {
  try {
    const lugarId = aEntero(req.params.id, null)
    if (!lugarId) return res.status(400).json({ mensaje: 'Id no válido' })

    const body = req.body || {}
    const estrellas = Number(body.estrellas)
    if (!Number.isInteger(estrellas) || estrellas < 1 || estrellas > 5) {
      return res.status(400).json({ mensaje: 'Las estrellas deben ser de 1 a 5' })
    }
    const texto = opcional(body.texto)
    if (texto && texto.length > 500) {
      return res.status(400).json({ mensaje: 'La reseña es demasiado larga (máximo 500)' })
    }

    const [filas] = await pool.query('SELECT id, usuario_id FROM lugares WHERE id = ?', [lugarId])
    if (!filas[0]) return res.status(404).json({ mensaje: 'Lugar no encontrado' })
    if (filas[0].usuario_id === req.usuario.id) {
      return res.status(403).json({ mensaje: 'No puedes reseñar tu propio lugar' })
    }

    await pool.query(
      `INSERT INTO resenas (lugar_id, usuario_id, estrellas, texto)
       VALUES (?, ?, ?, ?) AS nueva
       ON DUPLICATE KEY UPDATE
         estrellas = nueva.estrellas, texto = nueva.texto, creado_en = CURRENT_TIMESTAMP`,
      [lugarId, req.usuario.id, estrellas, texto]
    )
    res.status(201).json({ mensaje: 'Reseña guardada' })
  } catch (err) {
    next(err)
  }
}

module.exports = { listar, guardar }