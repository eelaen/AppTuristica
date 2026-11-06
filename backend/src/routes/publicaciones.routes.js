// Rutas de publicaciones. La lógica está en controllers/publicaciones.controller.js
const router = require('express').Router()
const rateLimit = require('express-rate-limit')
const publicaciones = require('../controllers/publicaciones.controller')
const likes = require('../controllers/likes.controller')
const comentarios = require('../controllers/comentarios.controller')
const { verificarToken, tokenOpcional, permitirRoles } = require('../middlewares/auth')
const { subirImagen } = require('../middlewares/subida')

// Límite propio para subir fotos: 30 por hora por IP (es lo que más pesa al servidor)
const limiteSubidas = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { mensaje: 'Has subido muchas fotos, intenta de nuevo más tarde' }
})

router.get('/', tokenOpcional, publicaciones.listar) // pública: el feed (marca tus likes si hay sesión)

// El orden importa: primero se revisa el token y el rol, y SOLO DESPUÉS se recibe
// el archivo. Así, quien no ha iniciado sesión no logra subir nada al servidor.
router.post(
  '/',
  limiteSubidas,
  verificarToken,
  permitirRoles('usuario', 'empresa'),
  subirImagen,
  publicaciones.crear
)

router.delete('/:id', verificarToken, publicaciones.eliminar) // borrar una propia

// Likes (necesitan sesión)
router.post('/:id/like', verificarToken, likes.darLike)
router.delete('/:id/like', verificarToken, likes.quitarLike)

// Comentarios (leer es público; escribir y borrar necesitan sesión)
router.get('/:id/comentarios', comentarios.listar)
router.post('/:id/comentarios', verificarToken, comentarios.crear)
router.delete('/:id/comentarios/:comentarioId', verificarToken, comentarios.eliminar)

module.exports = router