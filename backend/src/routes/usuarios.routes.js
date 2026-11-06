const router = require('express').Router()
const usuarios = require('../controllers/usuarios.controller')

router.get('/:id', usuarios.ver) // pública

module.exports = router