// Lógica de las publicaciones (las fotos del feed): crear, listar y eliminar.
const path = require('path')
const pool = require('../config/db')
const { limpiar, opcional, esSlug } = require('../utils/validar')
const { DIR_PUBLICACIONES, esImagenReal, borrarArchivo } = require('../utils/imagen')

// Si la foto no tiene lugar ni texto de ubicación, se usa este
const UBICACION_POR_DEFECTO = 'La Ceiba, Honduras'

// Convierte un valor a entero positivo; si no sirve, devuelve el valor por defecto
const aEntero = (valor, defecto) => {
  const n = Number.parseInt(valor, 10)
  return Number.isInteger(n) && n > 0 ? n : defecto
}

// Borra la foto que ya se subió y responde con el error.
// Se usa cuando algo falla DESPUÉS de que multer guardó el archivo.
async function rechazar(res, archivo, codigo, mensaje) {
  await borrarArchivo(archivo.path)
  return res.status(codigo).json({ mensaje })
}

// ---------------------------------------------------------------
// POST /api/publicaciones   (necesita token)
// Sube una foto. Se envía como form-data:
//   imagen (archivo), descripcion?, lugar_id?, ubicacion?, tipo?, vigente_hasta?
// - Turista: el lugar es OPCIONAL. Si no elige uno, se usa el texto de ubicación
//   (o "La Ceiba, Honduras").
// - Lugar turístico: siempre se publica en su propio lugar y puede crear ofertas
//   (tipo = oferta, con vigente_hasta opcional).
// ---------------------------------------------------------------
async function crear(req, res, next) {
  const archivo = req.file
  try {
    if (!archivo) {
      return res.status(400).json({ mensaje: 'Debes enviar una imagen (campo "imagen")' })
    }

    // 1. Comprobar que de verdad sea una imagen (no solo que lo diga el nombre)
    if (!(await esImagenReal(archivo.path))) {
      return rechazar(res, archivo, 400, 'El archivo no es una imagen válida')
    }

    const body = req.body || {}

    // 2. Textos
    const descripcion = opcional(body.descripcion)
    if (descripcion && descripcion.length > 500) {
      return rechazar(res, archivo, 400, 'La descripción es demasiado larga (máximo 500)')
    }
    const ubicacionTexto = opcional(body.ubicacion)
    if (ubicacionTexto && ubicacionTexto.length > 150) {
      return rechazar(res, archivo, 400, 'La ubicación es demasiado larga (máximo 150)')
    }

    // 3. Tipo: publicación normal u oferta (solo las empresas publican ofertas)
    const tipo = limpiar(body.tipo) || 'publicacion'
    if (!['publicacion', 'oferta'].includes(tipo)) {
      return rechazar(res, archivo, 400, 'Tipo de publicación no válido')
    }
    if (tipo === 'oferta' && req.usuario.rol !== 'empresa') {
      return rechazar(res, archivo, 403, 'Solo los lugares turísticos pueden publicar ofertas')
    }
    let vigenteHasta = null
    if (tipo === 'oferta' && body.vigente_hasta) {
      const fecha = new Date(body.vigente_hasta)
      if (Number.isNaN(fecha.getTime()) || fecha <= new Date()) {
        return rechazar(res, archivo, 400, 'La fecha de vigencia debe ser una fecha futura')
      }
      vigenteHasta = fecha
    }

    // 4. Averiguar el lugar
    let lugarId = null
    if (req.usuario.rol === 'empresa') {
      const [filas] = await pool.query('SELECT id FROM lugares WHERE usuario_id = ?', [
        req.usuario.id
      ])
      if (!filas[0]) return rechazar(res, archivo, 404, 'No tienes un lugar registrado')
      lugarId = filas[0].id
    } else if (body.lugar_id !== undefined && body.lugar_id !== '') {
      lugarId = aEntero(body.lugar_id, null)
      if (!lugarId) return rechazar(res, archivo, 400, 'Lugar no válido')
      const [filas] = await pool.query('SELECT id FROM lugares WHERE id = ?', [lugarId])
      if (!filas[0]) return rechazar(res, archivo, 404, 'El lugar no existe')
    }

    // 5. Guardar en la base (se guarda la ruta, no la imagen)
    const ruta = `/uploads/publicaciones/${archivo.filename}`
    const ubicacion = ubicacionTexto || UBICACION_POR_DEFECTO
    const [resultado] = await pool.query(
      `INSERT INTO publicaciones
         (usuario_id, lugar_id, imagen, descripcion, ubicacion, tipo, vigente_hasta)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [req.usuario.id, lugarId, ruta, descripcion, ubicacion, tipo, vigenteHasta]
    )

    res.status(201).json({
      mensaje: 'Publicación creada',
      publicacion: {
        id: resultado.insertId,
        lugar_id: lugarId,
        imagen: ruta,
        descripcion,
        ubicacion,
        tipo,
        vigente_hasta: vigenteHasta
      }
    })
  } catch (err) {
    if (archivo) await borrarArchivo(archivo.path) // no dejar fotos huérfanas
    next(err)
  }
}

// ---------------------------------------------------------------
// GET /api/publicaciones?autor=turistas&categoria=playas&lugar_id=3&usuario_id=5&pagina=1&limite=10
// El feed: las publicaciones más recientes primero. Ruta pública.
// Todos los filtros son opcionales:
//   autor: turistas o empresas
//   categoria: slug de la categoría del lugar etiquetado
//   lugar_id: solo las de ese lugar
//   usuario_id: solo las de esa persona (para su perfil)
// Las ofertas vencidas no se muestran.
// ---------------------------------------------------------------
async function listar(req, res, next) {
  try {
    const autor = limpiar(req.query.autor)
    const categoria = limpiar(req.query.categoria)
    const lugarId = aEntero(req.query.lugar_id, null)
    const usuarioId = aEntero(req.query.usuario_id, null)
    const pagina = aEntero(req.query.pagina, 1)
    const limite = Math.min(aEntero(req.query.limite, 10), 30) // máximo 30 por página

    if (autor && !['turistas', 'empresas'].includes(autor)) {
      return res.status(400).json({ mensaje: 'Filtro de autor no válido' })
    }
    if (categoria && !esSlug(categoria)) {
      return res.status(400).json({ mensaje: 'Categoría no válida' })
    }

    // Se arma el WHERE solo con los filtros que llegaron
    const condiciones = [
      // Las ofertas vencidas se ocultan
      "(p.tipo <> 'oferta' OR p.vigente_hasta IS NULL OR p.vigente_hasta > ?)"
    ]
    const valores = [new Date()]

    if (autor === 'turistas') condiciones.push("u.rol = 'usuario'")
    if (autor === 'empresas') condiciones.push("u.rol = 'empresa'")
    if (categoria) {
      condiciones.push(
        `EXISTS (
           SELECT 1 FROM lugar_categorias lc
           JOIN categorias c ON c.id = lc.categoria_id
           WHERE lc.lugar_id = p.lugar_id AND c.slug = ?)`
      )
      valores.push(categoria)
    }
    if (lugarId) {
      condiciones.push('p.lugar_id = ?')
      valores.push(lugarId)
    }
    if (usuarioId) {
      condiciones.push('p.usuario_id = ?')
      valores.push(usuarioId)
    }

    const [publicaciones] = await pool.query(
      `SELECT p.id, p.imagen, p.descripcion, p.ubicacion, p.tipo, p.vigente_hasta, p.creado_en,
              u.id AS usuario_id, u.nombre AS usuario_nombre, u.rol AS usuario_rol,
              COALESCE((SELECT la.verificado FROM lugares la WHERE la.usuario_id = u.id LIMIT 1), 0)
                AS autor_verificado,
              l.id AS lugar_id, l.nombre AS lugar_nombre,
              (SELECT COUNT(*) FROM likes k WHERE k.publicacion_id = p.id) AS likes,
              (SELECT COUNT(*) FROM comentarios c WHERE c.publicacion_id = p.id) AS comentarios,
              EXISTS(SELECT 1 FROM likes k2 WHERE k2.publicacion_id = p.id AND k2.usuario_id = ?)
                AS yo_di_like
       FROM publicaciones p
       JOIN usuarios u ON u.id = p.usuario_id
       LEFT JOIN lugares l ON l.id = p.lugar_id
       WHERE ${condiciones.join(' AND ')}
       ORDER BY p.creado_en DESC, p.id DESC
       LIMIT ? OFFSET ?`,
      // El primer "?" del SELECT es yo_di_like, por eso va antes que los del WHERE
      [req.usuario ? req.usuario.id : 0, ...valores, limite, (pagina - 1) * limite]
    )

    res.json({
      pagina,
      limite,
      publicaciones: publicaciones.map((p) => ({
        ...p,
        autor_verificado: Boolean(p.autor_verificado),
        yo_di_like: Boolean(p.yo_di_like)
      }))
    })
  } catch (err) {
    next(err)
  }
}

// ---------------------------------------------------------------
// DELETE /api/publicaciones/:id   (necesita token)
// Cada persona solo puede borrar SUS publicaciones.
// Los likes y comentarios se borran solos (ON DELETE CASCADE).
// ---------------------------------------------------------------
async function eliminar(req, res, next) {
  try {
    const id = aEntero(req.params.id, null)
    if (!id) return res.status(400).json({ mensaje: 'Id no válido' })

    // Se busca por id Y por dueño: si no es tuya, responde igual que si no existiera
    const [filas] = await pool.query(
      'SELECT id, imagen FROM publicaciones WHERE id = ? AND usuario_id = ?',
      [id, req.usuario.id]
    )
    if (!filas[0]) return res.status(404).json({ mensaje: 'Publicación no encontrada' })

    await pool.query('DELETE FROM publicaciones WHERE id = ?', [id])

    // Borrar también el archivo (path.basename evita rutas raras)
    await borrarArchivo(path.join(DIR_PUBLICACIONES, path.basename(filas[0].imagen)))

    res.json({ mensaje: 'Publicación eliminada' })
  } catch (err) {
    next(err)
  }
}

module.exports = { crear, listar, eliminar }