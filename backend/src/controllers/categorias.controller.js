// Lógica de las categorías de los lugares (Playas, Naturaleza, Aventura...).
const pool = require('../config/db')

// ---------------------------------------------------------------
// GET /api/categorias
// Lista todas las categorías, en el orden en que se muestran. Ruta pública.
// ---------------------------------------------------------------
async function listar(req, res, next) {
  try {
    const [categorias] = await pool.query(
      'SELECT id, slug, nombre, icono FROM categorias ORDER BY orden, nombre'
    )
    res.json({ categorias })
  } catch (err) {
    next(err)
  }
}

module.exports = { listar }