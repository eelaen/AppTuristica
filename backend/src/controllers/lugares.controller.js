// Lógica de los lugares turísticos (destinos y empresas): listar y buscar,
// ver el detalle y que cada empresa edite su propio lugar.
const pool = require('../config/db')
const { limpiar, opcional, esSlug, validarLugar, coordenada } = require('../utils/validar')
const {
  resolverCategorias,
  guardarCategorias,
  adjuntarCategorias
} = require('../utils/categorias')

const TIPOS = ['destino', 'empresa']

// Convierte un valor a entero positivo; si no sirve, devuelve el valor por defecto
const aEntero = (valor, defecto) => {
  const n = Number.parseInt(valor, 10)
  return Number.isInteger(n) && n > 0 ? n : defecto
}

// MySQL devuelve los decimales como texto ("4.5"); aquí se pasan a número
const aNumero = (valor) => (valor === null || valor === undefined ? null : Number(valor))

const formatear = (lugar) => ({
  ...lugar,
  promedio: aNumero(lugar.promedio),
  latitud: aNumero(lugar.latitud),
  longitud: aNumero(lugar.longitud),
  verificado: Boolean(lugar.verificado)
})

// ---------------------------------------------------------------
// GET /api/lugares?q=río&categoria=naturaleza&tipo=destino&pagina=1&limite=20
// Lista los lugares. Todos los filtros son opcionales. Ruta pública.
// - categoria: el slug (playas, naturaleza, aventura...)
// - tipo: destino o empresa
// ---------------------------------------------------------------
async function listar(req, res, next) {
  try {
    const q = limpiar(req.query.q)
    const categoria = limpiar(req.query.categoria)
    const tipo = limpiar(req.query.tipo)
    const pagina = aEntero(req.query.pagina, 1)
    const limite = Math.min(aEntero(req.query.limite, 20), 50) // máximo 50 por página

    if (q.length > 100) {
      return res.status(400).json({ mensaje: 'La búsqueda es demasiado larga' })
    }
    if (categoria && !esSlug(categoria)) {
      return res.status(400).json({ mensaje: 'Categoría no válida' })
    }
    if (tipo && !TIPOS.includes(tipo)) {
      return res.status(400).json({ mensaje: 'Tipo no válido' })
    }

    // Se arma el WHERE solo con los filtros que llegaron
    const condiciones = []
    const valores = []
    if (q) {
      // Se escapan % y _ para que se busquen como texto normal
      const patron = `%${q.replace(/[\\%_]/g, '\\$&')}%`
      condiciones.push(
        `(l.nombre LIKE ? OR EXISTS (
           SELECT 1 FROM lugar_categorias lc
           JOIN categorias c ON c.id = lc.categoria_id
           WHERE lc.lugar_id = l.id AND c.nombre LIKE ?))`
      )
      valores.push(patron, patron)
    }
    if (categoria) {
      condiciones.push(
        `EXISTS (
           SELECT 1 FROM lugar_categorias lc
           JOIN categorias c ON c.id = lc.categoria_id
           WHERE lc.lugar_id = l.id AND c.slug = ?)`
      )
      valores.push(categoria)
    }
    if (tipo) {
      condiciones.push('l.tipo = ?')
      valores.push(tipo)
    }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    // Une cada lugar con sus reseñas para calcular el promedio y el total
    const [filas] = await pool.query(
      `SELECT l.id, l.nombre, l.tipo, l.verificado, l.direccion, l.foto_portada,
              l.latitud, l.longitud,
              ROUND(AVG(r.estrellas), 1) AS promedio,
              COUNT(r.id) AS total_resenas
       FROM lugares l
       LEFT JOIN resenas r ON r.lugar_id = l.id
       ${where}
       GROUP BY l.id
       ORDER BY l.nombre ASC
       LIMIT ? OFFSET ?`,
      [...valores, limite, (pagina - 1) * limite]
    )

    const lugares = await adjuntarCategorias(pool, filas.map(formatear))
    res.json({ pagina, limite, lugares })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// Busca un lugar con sus categorías, su promedio y los números de su perfil.
// "condicion" es siempre un texto fijo nuestro (nunca viene del usuario).
async function buscarLugar(condicion, valor) {
  const [filas] = await pool.query(
    `SELECT l.id, l.usuario_id, l.nombre, l.tipo, l.verificado, l.descripcion, l.direccion,
            l.telefono, l.horario, l.foto_portada, l.latitud, l.longitud, l.creado_en,
            ROUND(AVG(r.estrellas), 1) AS promedio,
            COUNT(r.id) AS total_resenas,
            (SELECT COUNT(*) FROM publicaciones p
               WHERE p.usuario_id = l.usuario_id) AS total_publicaciones,
            (SELECT COUNT(*) FROM likes k
               JOIN publicaciones p2 ON p2.id = k.publicacion_id
               WHERE p2.usuario_id = l.usuario_id) AS total_likes
     FROM lugares l
     LEFT JOIN resenas r ON r.lugar_id = l.id
     WHERE ${condicion}
     GROUP BY l.id`,
    [valor]
  )
  if (!filas[0]) return null
  const [lugar] = await adjuntarCategorias(pool, [formatear(filas[0])])
  return lugar
}

// GET /api/lugares/:id  (pública)
async function ver(req, res, next) {
  try {
    const id = aEntero(req.params.id, null)
    if (!id) return res.status(400).json({ mensaje: 'Id no válido' })
    const lugar = await buscarLugar('l.id = ?', id)
    if (!lugar) return res.status(404).json({ mensaje: 'Lugar no encontrado' })
    res.json({ lugar })
  } catch (err) {
    next(err)
  }
}

// GET /api/lugares/mio  (token y rol "empresa"): el lugar de quien está conectado
async function verMio(req, res, next) {
  try {
    const lugar = await buscarLugar('l.usuario_id = ?', req.usuario.id)
    if (!lugar) return res.status(404).json({ mensaje: 'No tienes un lugar registrado' })
    res.json({ lugar })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// PUT /api/lugares/mio   (necesita token y rol "empresa")
// La empresa edita SU lugar. Solo cambia los campos que mande.
// Body (todos opcionales): { descripcion, direccion, telefono, horario,
//                            categorias: ["playas", ...], latitud, longitud }
// ---------------------------------------------------------------
async function editarMio(req, res, next) {
  const conexion = await pool.getConnection()
  try {
    // El lugar se busca por el id del token: nadie puede editar el de otra empresa
    const [filas] = await conexion.query(
      `SELECT id, descripcion, direccion, telefono, horario, latitud, longitud
       FROM lugares WHERE usuario_id = ?`,
      [req.usuario.id]
    )
    const actual = filas[0]
    if (!actual) return res.status(404).json({ mensaje: 'No tienes un lugar registrado' })

    // Se mezclan los datos nuevos con los actuales
    const b = req.body || {}
    const nuevo = {
      descripcion: b.descripcion !== undefined ? limpiar(b.descripcion) : actual.descripcion,
      direccion: b.direccion !== undefined ? opcional(b.direccion) : actual.direccion,
      telefono: b.telefono !== undefined ? opcional(b.telefono) : actual.telefono,
      horario: b.horario !== undefined ? opcional(b.horario) : actual.horario
    }
    const error = validarLugar(nuevo)
    if (error) return res.status(400).json({ mensaje: error })

    // Coordenadas: se envían las dos juntas (o null para borrarlas)
    let latitud = aNumero(actual.latitud)
    let longitud = aNumero(actual.longitud)
    if (b.latitud !== undefined || b.longitud !== undefined) {
      const lat = coordenada(b.latitud, 90)
      const lng = coordenada(b.longitud, 180)
      if (lat === undefined || lng === undefined) {
        return res.status(400).json({ mensaje: 'Envía latitud y longitud válidas, juntas' })
      }
      latitud = lat
      longitud = lng
    }

    // Categorías (solo si las mandó)
    let categoriasIds = null
    if (b.categorias !== undefined) {
      const resultado = await resolverCategorias(conexion, b.categorias)
      if (resultado.error) return res.status(400).json({ mensaje: resultado.error })
      categoriasIds = resultado.ids
    }

    // Guardar todo junto
    await conexion.beginTransaction()
    await conexion.query(
      `UPDATE lugares
       SET descripcion = ?, direccion = ?, telefono = ?, horario = ?, latitud = ?, longitud = ?
       WHERE id = ?`,
      [nuevo.descripcion, nuevo.direccion, nuevo.telefono, nuevo.horario, latitud, longitud, actual.id]
    )
    if (categoriasIds) await guardarCategorias(conexion, actual.id, categoriasIds)
    await conexion.commit()

    res.json({ mensaje: 'Lugar actualizado', lugar: { id: actual.id, ...nuevo, latitud, longitud } })
  } catch (err) {
    await conexion.rollback()
    next(err)
  } finally {
    conexion.release()
  }
}

module.exports = { listar, ver, verMio, editarMio }