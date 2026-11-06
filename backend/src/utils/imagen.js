// Funciones de apoyo para las imágenes subidas.
const fs = require('fs/promises')
const path = require('path')

// Carpeta donde se guardan las fotos de las publicaciones (backend/uploads/publicaciones)
const DIR_PUBLICACIONES = path.join(__dirname, '..', '..', 'uploads', 'publicaciones')

// Comprueba que el archivo REALMENTE sea una imagen JPG, PNG o WEBP.
// El tipo que dice el cliente se puede falsificar, así que se leen los
// primeros bytes del archivo, que es donde cada formato se identifica.
async function esImagenReal(ruta) {
  const archivo = await fs.open(ruta, 'r')
  try {
    const bytes = Buffer.alloc(12)
    await archivo.read(bytes, 0, 12, 0)

    const esJpg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff
    const esPng = bytes
      .subarray(0, 8)
      .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
    const esWebp =
      bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP'

    return esJpg || esPng || esWebp
  } finally {
    await archivo.close()
  }
}

// Borra un archivo; si ya no existe, no pasa nada
async function borrarArchivo(ruta) {
  try {
    await fs.unlink(ruta)
  } catch {
    /* ya no existía */
  }
}

module.exports = { DIR_PUBLICACIONES, esImagenReal, borrarArchivo }