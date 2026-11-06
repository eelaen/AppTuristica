// Punto de arranque del servidor: configura la seguridad, conecta las rutas
// y comprueba la conexión con MySQL antes de empezar a escuchar.
require('dotenv').config()
const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const rateLimit = require('express-rate-limit')
const path = require('path')
const pool = require('./config/db')
const { limpiarVencidas } = require('./utils/sesiones')

const app = express()

// --- Seguridad y configuración general ---
// helmet agrega cabeceras de seguridad. La política "cross-origin" permite
// que la web (otro puerto) pueda cargar las fotos de /uploads.
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }))
app.use(cors())                            // permite que la app móvil y la web consuman la API
app.use(express.json({ limit: '10kb' }))   // lee JSON y limita el tamaño del cuerpo
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads'))) // fotos subidas

// Limita los intentos en las rutas de autenticación (frena ataques de fuerza bruta)
const limiteAuth = rateLimit({
  windowMs: 15 * 60 * 1000, // ventana de 15 minutos
  limit: 300,                // intentos por IP (alto para poder probar; luego se baja)
  standardHeaders: true,
  legacyHeaders: false,
  message: { mensaje: 'Demasiados intentos, intenta de nuevo más tarde' }
})

// Límite general para el resto de la API (evita abusos y exceso de peticiones)
const limiteGeneral = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { mensaje: 'Demasiadas peticiones, intenta de nuevo más tarde' }
})

// --- Rutas ---
app.get('/api/salud', (req, res) => {
  res.json({ mensaje: 'API funcionando' })
})

app.use('/api/auth', limiteAuth, require('./routes/auth.routes'))
app.use('/api/lugares', limiteGeneral, require('./routes/lugares.routes'))
app.use('/api/categorias', limiteGeneral, require('./routes/categorias.routes'))
app.use('/api/publicaciones', limiteGeneral, require('./routes/publicaciones.routes'))
app.use('/api/usuarios', limiteGeneral, require('./routes/usuarios.routes'))
// Próximas rutas: likes, comentarios y reseñas

// --- Errores (siempre después de las rutas) ---
// Ruta que no existe
app.use((req, res) => {
  res.status(404).json({ mensaje: 'Ruta no encontrada' })
})

// Cualquier error inesperado: se guarda en consola y al cliente solo
// se le da un mensaje genérico (no se filtran detalles internos)
app.use((err, req, res, next) => {
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ mensaje: 'JSON no válido' })
  }
  // Errores de multer (imagen muy pesada, campo equivocado, etc.)
  if (err.name === 'MulterError') {
    const mensaje =
      err.code === 'LIMIT_FILE_SIZE' ? 'La imagen supera los 5 MB' : 'Archivo no válido'
    return res.status(400).json({ mensaje })
  }
  // Errores nuestros marcados como "públicos" (por ejemplo, formato no permitido)
  if (err.publico) {
    return res.status(400).json({ mensaje: err.message })
  }
  console.error(err)
  res.status(500).json({ mensaje: 'Error interno del servidor' })
})

// --- Arranque ---
async function iniciar() {
  try {
    await pool.query('SELECT 1')
    console.log('MySQL conectado')

    // Limpieza de sesiones vencidas: al arrancar y luego cada hora
    const limpiar = () =>
      limpiarVencidas().catch((e) => console.warn('No se pudo limpiar las sesiones:', e.message))
    await limpiar()
    setInterval(limpiar, 60 * 60 * 1000).unref()

    app.listen(process.env.PORT, () => {
      console.log(`Servidor en http://localhost:${process.env.PORT}`)
    })
  } catch (error) {
    console.error('Error al conectar con MySQL:', error.message)
  }
}

iniciar()