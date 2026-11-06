// Middlewares de autenticación: revisan el token (JWT) y el rol de quien hace la petición.
const jwt = require('jsonwebtoken')

// Obtiene el token de la cabecera "Authorization: Bearer <token>"
const leerToken = (req) => req.headers.authorization?.split(' ')[1]

// Exige un token válido. Si es válido, deja los datos en req.usuario ({ id, rol }).
function verificarToken(req, res, next) {
  const token = leerToken(req)
  if (!token) {
    return res.status(401).json({ mensaje: 'No autenticado' })
  }
  try {
    req.usuario = jwt.verify(token, process.env.JWT_SECRET)
    next()
  } catch {
    res.status(401).json({ mensaje: 'Token inválido o vencido' })
  }
}

// El token es opcional: si viene y es válido, se llena req.usuario;
// si no viene (o es malo), la persona se trata como visitante y la petición sigue.
// Sirve para rutas públicas que cambian un poco si hay sesión (por ejemplo, el feed).
function tokenOpcional(req, res, next) {
  const token = leerToken(req)
  if (token) {
    try {
      req.usuario = jwt.verify(token, process.env.JWT_SECRET)
    } catch {
      /* token malo: se ignora y se trata como visitante */
    }
  }
  next()
}

// Permite pasar solo a ciertos roles.
// Uso: permitirRoles('empresa')  o  permitirRoles('usuario', 'empresa')
function permitirRoles(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.usuario.rol)) {
      return res.status(403).json({ mensaje: 'Acceso denegado' })
    }
    next()
  }
}

module.exports = { verificarToken, tokenOpcional, permitirRoles }