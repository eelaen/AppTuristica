// Rutas de autenticación. Aquí solo se define qué URL existe;
// la lógica está en controllers/auth.controller.js y sesion.contoller.js
const router = require('express').Router()
const auth = require('../controllers/auth.controller')
const sesion = require('../controllers/sesion.controller') // (el nombre del archivo tiene el typo "contoller")
const { verificarToken } = require('../middlewares/auth')

router.post('/registro/usuario', auth.registrarUsuario) // turista
router.post('/registro/empresa', auth.registrarEmpresa) // lugar turístico

router.post('/login', auth.login)                      // iniciar sesión
router.get('/perfil', verificarToken, auth.perfil)     // ver mi perfil (necesita token)

router.post('/renovar', sesion.renovar)                // cambia el refreshToken por un par nuevo
router.post('/cerrar-sesion', sesion.cerrarSesion)     // cierra este dispositivo
router.post('/cerrar-todas', verificarToken, sesion.cerrarTodas) // cierra todos

module.exports = router