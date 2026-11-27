// Lógica de los lugares guardados ("Mi viaje"): listar, ver si uno está guardado,
// guardar y quitar. Todas las rutas necesitan sesión.
const pool = require('../config/db')
const { adjuntarCategorias } = require('../utils/categorias')

// Convierte un valor a entero positivo; si no sirve, devuelve el valor por defecto
const aEntero = (valor, defecto) => {
  const n = Number.parseInt(valor, 10)
  return Number.isInteger(n) && n > 0 ? n : defecto
}

// MySQL devuelve los decimales como texto; aquí se pasan a número
const aNumero = (valor) => (valor === null || valor === undefined ? null : Number(valor))

// Revisa que el lugar exista
async function existeLugar(id) {
  const [filas] = await pool.query('SELECT id FROM lugares WHERE id = ?', [id])
  return filas.length > 0
}

// ---------------------------------------------------------------
// GET /api/guardados?pagina=1&limite=20
// Los lugares que esta persona guardó, el más reciente primero. Es la pantalla "Mi viaje".
// La imagen es la portada del lugar o, si no tiene, la última foto que alguien publicó ahí.
// ---------------------------------------------------------------
async function listar(req, res, next) {
  try {
    const pagina = aEntero(req.query.pagina, 1)
    const limite = Math.min(aEntero(req.query.limite, 20), 50)

    const [filas] = await pool.query(
      `SELECT l.id, l.nombre, l.tipo, l.verificado, l.direccion, l.latitud, l.longitud,
              COALESCE(l.foto_portada,
                (SELECT p.imagen FROM publicaciones p
                  WHERE p.lugar_id = l.id
                  ORDER BY p.creado_en DESC, p.id DESC LIMIT 1)) AS imagen,
              ROUND(AVG(r.estrellas), 1) AS promedio,
              COUNT(r.id) AS total_resenas,
              g.creado_en AS guardado_en
       FROM guardados g
       JOIN lugares l ON l.id = g.lugar_id
       LEFT JOIN resenas r ON r.lugar_id = l.id
       WHERE g.usuario_id = ?
       GROUP BY l.id, g.creado_en
       ORDER BY g.creado_en DESC, l.id DESC
       LIMIT ? OFFSET ?`,
      [req.usuario.id, limite, (pagina - 1) * limite]
    )

    const lugares = await adjuntarCategorias(
      pool,
      filas.map((l) => ({
        ...l,
        verificado: Boolean(l.verificado),
        promedio: aNumero(l.promedio),
        latitud: aNumero(l.latitud),
        longitud: aNumero(l.longitud)
      }))
    )
    res.json({ pagina, limite, lugares })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// GET /api/guardados/:lugarId
// Dice si este lugar está guardado por quien consulta: { guardado: true | false }
// ---------------------------------------------------------------
async function estado(req, res, next) {
  try {
    const lugarId = aEntero(req.params.lugarId, null)
    if (!lugarId) return res.status(400).json({ mensaje: 'Id no válido' })

    const [filas] = await pool.query(
      'SELECT 1 FROM guardados WHERE usuario_id = ? AND lugar_id = ?',
      [req.usuario.id, lugarId]
    )
    res.json({ guardado: filas.length > 0 })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// POST /api/guardados/:lugarId
// Guarda el lugar. Si ya estaba guardado, no pasa nada (no se duplica).
// ---------------------------------------------------------------
async function guardar(req, res, next) {
  try {
    const lugarId = aEntero(req.params.lugarId, null)
    if (!lugarId) return res.status(400).json({ mensaje: 'Id no válido' })
    if (!(await existeLugar(lugarId))) {
      return res.status(404).json({ mensaje: 'Lugar no encontrado' })
    }

    // INSERT IGNORE: si ya existe (llave primaria repetida), lo ignora sin error
    await pool.query('INSERT IGNORE INTO guardados (usuario_id, lugar_id) VALUES (?, ?)', [
      req.usuario.id,
      lugarId
    ])
    res.json({ guardado: true })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// DELETE /api/guardados/:lugarId
// Quita el lugar de Mi viaje. Si no estaba guardado, no pasa nada.
// ---------------------------------------------------------------
async function quitar(req, res, next) {
  try {
    const lugarId = aEntero(req.params.lugarId, null)
    if (!lugarId) return res.status(400).json({ mensaje: 'Id no válido' })

    // Solo borra el guardado de ESTA persona (el id sale del token)
    await pool.query('DELETE FROM guardados WHERE usuario_id = ? AND lugar_id = ?', [
      req.usuario.id,
      lugarId
    ])
    res.json({ guardado: false })
  } catch (err) {
    next(err)
  }
}

module.exports = { listar, estado, guardar, quitar }