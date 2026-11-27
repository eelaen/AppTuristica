// Rutas de lugares guardados ("Mi viaje"). La lógica está en controllers/guardados.controller.js
const router = require('express').Router()
const guardados = require('../controllers/guardados.controller')
const { verificarToken } = require('../middlewares/auth')

// Todas necesitan sesión
router.use(verificarToken)

router.get('/', guardados.listar)             // Mi viaje: la lista de guardados
router.get('/:lugarId', guardados.estado)     // ¿este lugar está guardado?
router.post('/:lugarId', guardados.guardar)   // guardar
router.delete('/:lugarId', guardados.quitar)  // quitar

module.exports = router