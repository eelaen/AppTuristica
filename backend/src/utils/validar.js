// Funciones de apoyo para validar y limpiar los datos que llegan del cliente.
// Nunca se confía en lo que manda la app o la web: se revisa todo aquí.

// Quita espacios al inicio y al final. Si no es texto, devuelve ''
const limpiar = (valor) => (typeof valor === 'string' ? valor.trim() : '')

// Devuelve el texto limpio, o null si viene vacío (para campos opcionales)
const opcional = (valor) => limpiar(valor) || null

// Revisa que el correo tenga forma de correo (algo@dominio.com)
const esEmail = (email) =>
  email.length <= 150 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)

// Revisa que un texto sirva como nombre técnico (por ejemplo "playas")
const esSlug = (texto) => /^[a-z0-9_-]{1,40}$/.test(texto)

// Valida los datos de la cuenta (iguales para usuario y empresa).
// Devuelve un mensaje de error, o null si todo está bien.
function validarCuenta({ nombre, email, password }) {
  if (nombre.length < 2 || nombre.length > 100) {
    return 'El nombre debe tener entre 2 y 100 caracteres'
  }
  if (!esEmail(email)) {
    return 'Correo electrónico no válido'
  }
  // 72 es el máximo que bcrypt puede encriptar
  if (typeof password !== 'string' || password.length < 8 || password.length > 72) {
    return 'La contraseña debe tener entre 8 y 72 caracteres'
  }
  if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return 'La contraseña debe incluir letras y números'
  }
  return null
}

// Valida los datos de texto de un lugar turístico (las categorías se validan aparte,
// contra la base de datos, en utils/categorias.js)
function validarLugar({ descripcion, direccion, telefono, horario }) {
  if (descripcion.length < 10 || descripcion.length > 1000) {
    return 'Describe lo que ofreces (entre 10 y 1000 caracteres)'
  }
  if (direccion && direccion.length > 255) {
    return 'La dirección es demasiado larga'
  }
  if (telefono && !/^[0-9+\-\s()]{7,20}$/.test(telefono)) {
    return 'Teléfono no válido'
  }
  if (horario && horario.length > 100) {
    return 'El horario es demasiado largo'
  }
  return null
}

// Convierte un valor en coordenada. Devuelve:
//   - un número, si es válido (entre -maximo y +maximo)
//   - null, si se quiere borrar la coordenada
//   - undefined, si no es válida
function coordenada(valor, maximo) {
  if (valor === null) return null
  let numero = NaN
  if (typeof valor === 'number') numero = valor
  else if (typeof valor === 'string' && valor.trim() !== '') numero = Number(valor)
  return Number.isFinite(numero) && Math.abs(numero) <= maximo ? numero : undefined
}

module.exports = { limpiar, opcional, esSlug, validarCuenta, validarLugar, coordenada }