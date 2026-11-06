// Funciones de apoyo para las categorías de los lugares.
// Un lugar puede tener varias categorías (tabla lugar_categorias).
// [ejecutor] puede ser el pool o una conexión con transacción.

// Valida la lista de categorías que manda el cliente, por ejemplo ["naturaleza", "aventura"].
// Devuelve { ids } si todo está bien, o { error } con el mensaje.
async function resolverCategorias(ejecutor, valor, maximo = 3) {
  if (!Array.isArray(valor)) return { error: 'Elige al menos una categoría' }

  // Solo textos, sin repetir
  const slugs = [
    ...new Set(valor.filter((s) => typeof s === 'string').map((s) => s.trim().toLowerCase()))
  ]
  if (slugs.length < 1) return { error: 'Elige al menos una categoría' }
  if (slugs.length > maximo) return { error: `Puedes elegir hasta ${maximo} categorías` }

  // Todas deben existir en la tabla categorias
  const [filas] = await ejecutor.query('SELECT id FROM categorias WHERE slug IN (?)', [slugs])
  if (filas.length !== slugs.length) return { error: 'Categoría no válida' }

  return { ids: filas.map((f) => f.id) }
}

// Reemplaza las categorías de un lugar por las nuevas
async function guardarCategorias(ejecutor, lugarId, ids) {
  await ejecutor.query('DELETE FROM lugar_categorias WHERE lugar_id = ?', [lugarId])
  await ejecutor.query('INSERT INTO lugar_categorias (lugar_id, categoria_id) VALUES ?', [
    ids.map((id) => [lugarId, id])
  ])
}

// Agrega a cada lugar de la lista su arreglo "categorias" ({ slug, nombre, icono })
async function adjuntarCategorias(ejecutor, lugares) {
  if (lugares.length === 0) return lugares

  const [filas] = await ejecutor.query(
    `SELECT lc.lugar_id, c.slug, c.nombre, c.icono
     FROM lugar_categorias lc
     JOIN categorias c ON c.id = lc.categoria_id
     WHERE lc.lugar_id IN (?)
     ORDER BY c.orden`,
    [lugares.map((l) => l.id)]
  )

  const porLugar = new Map()
  for (const fila of filas) {
    if (!porLugar.has(fila.lugar_id)) porLugar.set(fila.lugar_id, [])
    porLugar.get(fila.lugar_id).push({ slug: fila.slug, nombre: fila.nombre, icono: fila.icono })
  }

  return lugares.map((l) => ({ ...l, categorias: porLugar.get(l.id) || [] }))
}

module.exports = { resolverCategorias, guardarCategorias, adjuntarCategorias }