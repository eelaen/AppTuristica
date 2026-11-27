const router = require('express').Router()
const usuarios = require('../controllers/usuarios.controller')
const { verificarToken, permitirRoles } = require('../middlewares/auth')
const { subirAvatar } = require('../middlewares/subida')

router.put('/me', verificarToken, permitirRoles('usuario'), subirAvatar, usuarios.editar) // solo turistas
router.get('/:id', usuarios.ver) // pública

module.exports = router