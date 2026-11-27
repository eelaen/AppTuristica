// Lógica de los lugares turísticos (destinos y empresas): listar y buscar,
// ver el detalle y que cada empresa edite su propio lugar.
const pool = require('../config/db')
const path = require('path')
const { DIR_PERFILES, esImagenReal, borrarArchivo } = require('../utils/imagen')
const { limpiar, opcional, esSlug, validarLugar, coordenada } = require('../utils/validar')
const {
  resolverCategorias,
  guardarCategorias,
  adjuntarCategorias
} = require('../utils/categorias')

const TIPOS = ['destino', 'empresa']

// Cuántas reseñas "pesa" el promedio general al ordenar los recomendados.
// Con 5, un lugar necesita varias reseñas para superar al promedio de la app.
const PESO_MINIMO = 5

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
// GET /api/lugares?q=río&categoria=naturaleza&tipo=destino&orden=recomendados&pagina=1&limite=20
// Lista los lugares. Todos los filtros son opcionales. Ruta pública.
// - categoria: el slug (playas, naturaleza, aventura...)
// - tipo: destino o empresa
// - orden: vacío (por nombre) o "recomendados" (los mejor puntuados primero)
// ---------------------------------------------------------------
async function listar(req, res, next) {
  try {
    const q = limpiar(req.query.q)
    const categoria = limpiar(req.query.categoria)
    const tipo = limpiar(req.query.tipo)
    const orden = limpiar(req.query.orden)
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
    if (orden && orden !== 'recomendados') {
      return res.status(400).json({ mensaje: 'Orden no válido' })
    }

    // Solo se elige entre dos textos fijos, nunca se usa lo que escribe el cliente.
    // Recomendados: mayor puntaje, luego más reseñas, luego más guardados.
    const ordenSql =
      orden === 'recomendados'
        ? `puntaje DESC, total_resenas DESC,
           (SELECT COUNT(*) FROM guardados g WHERE g.lugar_id = l.id) DESC, l.nombre ASC`
        : 'l.nombre ASC'

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

    // Une cada lugar con sus reseñas para calcular el promedio, el total y el puntaje.
    // Puntaje = promedio ponderado: con pocas reseñas se acerca al promedio general de la
    // app, y con muchas se acerca al promedio real del lugar.
    const [filas] = await pool.query(
      `SELECT l.id, l.nombre, l.tipo, l.verificado, l.direccion, l.foto_portada,
              l.latitud, l.longitud,
              ROUND(AVG(r.estrellas), 1) AS promedio,
              COUNT(r.id) AS total_resenas,
              (COUNT(r.id) / (COUNT(r.id) + ${PESO_MINIMO})) * COALESCE(AVG(r.estrellas), 0)
                + (${PESO_MINIMO} / (COUNT(r.id) + ${PESO_MINIMO}))
                  * (SELECT COALESCE(AVG(estrellas), 3.5) FROM resenas) AS puntaje
       FROM lugares l
       LEFT JOIN resenas r ON r.lugar_id = l.id
       ${where}
       GROUP BY l.id
       ORDER BY ${ordenSql}
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
// Borra la foto recién subida (si hay) y responde con el error
async function rechazar(res, archivo, codigo, mensaje) {
  if (archivo) await borrarArchivo(archivo.path)
  return res.status(codigo).json({ mensaje })
}

// ---------------------------------------------------------------
// PUT /api/lugares/mio   (necesita token y rol "empresa")
// La empresa edita SU lugar. Solo cambia los campos que mande.
// Acepta JSON o form-data. Campos (todos opcionales):
//   descripcion, direccion, telefono, horario, latitud, longitud,
//   categorias: ["playas", ...], imagen (foto de perfil, solo form-data)
// El nombre NO se puede cambiar.
// ---------------------------------------------------------------
async function editarMio(req, res, next) {
  const archivo = req.file
  const conexion = await pool.getConnection()
  try {
    const [filas] = await conexion.query(
      `SELECT id, descripcion, direccion, telefono, horario, latitud, longitud, foto_portada
       FROM lugares WHERE usuario_id = ?`,
      [req.usuario.id]
    )
    const actual = filas[0]
    if (!actual) return rechazar(res, archivo, 404, 'No tienes un lugar registrado')

    const b = req.body || {}
    const nuevo = {
      descripcion: b.descripcion !== undefined ? limpiar(b.descripcion) : actual.descripcion,
      direccion: b.direccion !== undefined ? opcional(b.direccion) : actual.direccion,
      telefono: b.telefono !== undefined ? opcional(b.telefono) : actual.telefono,
      horario: b.horario !== undefined ? opcional(b.horario) : actual.horario
    }
    const error = validarLugar(nuevo)
    if (error) return rechazar(res, archivo, 400, error)

    let latitud = aNumero(actual.latitud)
    let longitud = aNumero(actual.longitud)
    if (b.latitud !== undefined || b.longitud !== undefined) {
      const lat = coordenada(b.latitud, 90)
      const lng = coordenada(b.longitud, 180)
      if (lat === undefined || lng === undefined) {
        return rechazar(res, archivo, 400, 'Envía latitud y longitud válidas, juntas')
      }
      latitud = lat
      longitud = lng
    }

    let categoriasIds = null
    if (b.categorias !== undefined) {
      const resultado = await resolverCategorias(conexion, b.categorias)
      if (resultado.error) return rechazar(res, archivo, 400, resultado.error)
      categoriasIds = resultado.ids
    }

    // Foto de perfil (si subió una)
    let fotoPortada = actual.foto_portada
    if (archivo) {
      if (!(await esImagenReal(archivo.path))) {
        return rechazar(res, archivo, 400, 'El archivo no es una imagen válida')
      }
      fotoPortada = `/uploads/perfiles/${archivo.filename}`
    }

    await conexion.beginTransaction()
    await conexion.query(
      `UPDATE lugares
       SET descripcion = ?, direccion = ?, telefono = ?, horario = ?,
           latitud = ?, longitud = ?, foto_portada = ?
       WHERE id = ?`,
      [nuevo.descripcion, nuevo.direccion, nuevo.telefono, nuevo.horario,
       latitud, longitud, fotoPortada, actual.id]
    )
    if (categoriasIds) await guardarCategorias(conexion, actual.id, categoriasIds)
    await conexion.commit()

    // Se borra la foto anterior, pero solo si estaba en la carpeta de perfiles
    if (archivo && actual.foto_portada?.startsWith('/uploads/perfiles/')) {
      await borrarArchivo(path.join(DIR_PERFILES, path.basename(actual.foto_portada)))
    }

    res.json({
      mensaje: 'Lugar actualizado',
      lugar: { id: actual.id, ...nuevo, latitud, longitud, foto_portada: fotoPortada }
    })
  } catch (err) {
    await conexion.rollback()
    if (archivo) await borrarArchivo(archivo.path)
    next(err)
  } finally {
    conexion.release()
  }
}

module.exports = { listar, ver, verMio, editarMio }