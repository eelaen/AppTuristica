// Configuración de multer: recibe UNA imagen en el campo "imagen" y la guarda en disco.
const multer = require('multer')
const crypto = require('crypto')
const fs = require('fs')
const { DIR_PUBLICACIONES, DIR_PERFILES } = require('../utils/imagen')

const EXTENSIONES = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp'
}

// Crea un "subidor" que guarda en la carpeta indicada
function crearSubida(carpeta) {
  const almacenamiento = multer.diskStorage({
    destination: (req, archivo, cb) => {
      fs.mkdirSync(carpeta, { recursive: true })
      cb(null, carpeta)
    },
    filename: (req, archivo, cb) => {
      cb(null, crypto.randomUUID() + EXTENSIONES[archivo.mimetype])
    }
  })

  return multer({
    storage: almacenamiento,
    limits: { fileSize: 5 * 1024 * 1024, files: 1 },
    fileFilter: (req, archivo, cb) => {
      if (!EXTENSIONES[archivo.mimetype]) {
        const error = new Error('Solo se permiten imágenes JPG, PNG o WEBP')
        error.publico = true
        return cb(error)
      }
      cb(null, true)
    }
  }).single('imagen')
}

module.exports = {
  subirImagen: crearSubida(DIR_PUBLICACIONES),
  subirAvatar: crearSubida(DIR_PERFILES)
}