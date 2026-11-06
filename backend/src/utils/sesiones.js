// Funciones de apoyo para las sesiones: token de acceso (JWT corto) y
// token de renovación (texto aleatorio guardado en la base como huella).
const crypto = require('crypto')
const jwt = require('jsonwebtoken')
const pool = require('../config/db')

// Cuánto dura el token de acceso (se puede cambiar en el .env: JWT_EXPIRES=1m para pruebas)
const ACCESO_EXPIRA = process.env.JWT_EXPIRES || '15m'
// Cuántos días dura el token de renovación (REFRESH_DIAS en el .env)
const RENOVACION_DIAS = Number(process.env.REFRESH_DIAS) || 7

// Huella (hash) de un token. En la base solo se guarda esto, nunca el token.
const hashear = (token) => crypto.createHash('sha256').update(token).digest('hex')

// Token de renovación nuevo: 48 bytes aleatorios, imposible de adivinar
const generarRenovacion = () => crypto.randomBytes(48).toString('base64url')

// Fecha en que vencerá un token de renovación creado ahora
const fechaVencimiento = () => new Date(Date.now() + RENOVACION_DIAS * 24 * 60 * 60 * 1000)

// Token de acceso (JWT): lleva el id y el rol, y vence pronto
const crearAccessToken = (usuario) =>
  jwt.sign({ id: usuario.id, rol: usuario.rol }, process.env.JWT_SECRET, {
    expiresIn: ACCESO_EXPIRA
  })

// Guarda una sesión nueva en la base y devuelve el token de renovación (el real,
// que solo se entrega una vez). [ejecutor] puede ser el pool o una conexión con transacción.
// Si no se indica [familia], empieza una cadena nueva (un inicio de sesión nuevo).
async function crearSesion(ejecutor, usuarioId, familia = crypto.randomUUID()) {
  const token = generarRenovacion()
  await ejecutor.query(
    'INSERT INTO sesiones (usuario_id, familia, token_hash, expira_en) VALUES (?, ?, ?, ?)',
    [usuarioId, familia, hashear(token), fechaVencimiento()]
  )
  return token
}

// Cancela todos los tokens de un dispositivo (una cadena de renovaciones)
async function cerrarFamilia(familia) {
  await pool.query('DELETE FROM sesiones WHERE familia = ?', [familia])
}

// Cancela todas las sesiones de una persona (todos sus dispositivos).
// Se usa, por ejemplo, al cambiar la contraseña.
async function cerrarTodas(usuarioId) {
  await pool.query('DELETE FROM sesiones WHERE usuario_id = ?', [usuarioId])
}

// Borra las sesiones vencidas para que la tabla no crezca sin control
async function limpiarVencidas() {
  await pool.query('DELETE FROM sesiones WHERE expira_en < ?', [new Date()])
}

module.exports = {
  hashear,
  crearAccessToken,
  crearSesion,
  cerrarFamilia,
  cerrarTodas,
  limpiarVencidas
}