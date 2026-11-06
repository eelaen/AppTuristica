// Rutas de lugares turísticos. La lógica está en controllers/lugares.controller.js
const router = require('express').Router()
const lugares = require('../controllers/lugares.controller')
const resenas = require('../controllers/resenas.controller')
const { verificarToken, permitirRoles } = require('../middlewares/auth')

router.get('/', lugares.listar)                                                   // pública: lista y búsqueda
router.get('/mio', verificarToken, permitirRoles('empresa'), lugares.verMio)      // mi lugar
router.put('/mio', verificarToken, permitirRoles('empresa'), lugares.editarMio)   // editar mi lugar
router.get('/:id', lugares.ver)                                                   // pública: detalle

// Reseñas (leer es público; dejar una necesita sesión de turista)
router.get('/:id/resenas', resenas.listar)
router.post('/:id/resenas', verificarToken, permitirRoles('usuario'), resenas.guardar)

// Importante: "/mio" va antes de "/:id" para que no se confunda con un id

module.exports = router