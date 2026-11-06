// Configuración de multer: recibe UNA imagen en el campo "imagen" y la guarda en disco.
const multer = require('multer')
const crypto = require('crypto')
const fs = require('fs')
const { DIR_PUBLICACIONES } = require('../utils/imagen')

// Formatos permitidos y su extensión. La extensión sale de ESTA lista,
// nunca del nombre que mande el cliente (así no se cuelan nombres raros).
const EXTENSIONES = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp'
}

const almacenamiento = multer.diskStorage({
  // Carpeta de destino (se crea si no existe)
  destination: (req, archivo, cb) => {
    fs.mkdirSync(DIR_PUBLICACIONES, { recursive: true })
    cb(null, DIR_PUBLICACIONES)
  },
  // Nombre aleatorio: evita que se pisen archivos y que adivinen nombres
  filename: (req, archivo, cb) => {
    cb(null, crypto.randomUUID() + EXTENSIONES[archivo.mimetype])
  }
})

const upload = multer({
  storage: almacenamiento,
  limits: { fileSize: 5 * 1024 * 1024, files: 1 }, // máximo 5 MB y un solo archivo
  fileFilter: (req, archivo, cb) => {
    if (!EXTENSIONES[archivo.mimetype]) {
      const error = new Error('Solo se permiten imágenes JPG, PNG o WEBP')
      error.publico = true // este mensaje sí se le puede mostrar al cliente
      return cb(error)
    }
    cb(null, true)
  }
})

module.exports = { subirImagen: upload.single('imagen') }