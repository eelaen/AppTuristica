// Rutas de categorías. La lógica está en controllers/categorias.controller.js
const router = require('express').Router()
const categorias = require('../controllers/categorias.controller')

router.get('/', categorias.listar) // pública

module.exports = router