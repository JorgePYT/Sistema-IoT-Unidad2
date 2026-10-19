
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PreferenciasStorage {

  // Obtener la ubicación del archivo JSON
  Future<File> obtenerArchivo() async {
    final directorio = await getApplicationDocumentsDirectory();

    return File('${directorio.path}/preferencias_iot.json');
  }

  // Guardar preferencias del usuario
  Future<void> guardarPreferencias({
    required bool temaOscuro,
    required int intervaloMuestreo,
  }) async {

    final archivo = await obtenerArchivo();

    final datos = {
      'tema_oscuro': temaOscuro,
      'intervalo_muestreo': intervaloMuestreo,
    };

    final contenidoJson = jsonEncode(datos);

    // Escritura asíncrona para no bloquear la interfaz
    await archivo.writeAsString(
      contenidoJson,
      flush: true,
    );
  }

  // Leer las preferencias almacenadas
  Future<Map<String, dynamic>?> leerPreferencias() async {

    final archivo = await obtenerArchivo();

    if (!await archivo.exists()) {
      return null;
    }

    final contenido = await archivo.readAsString();

    return jsonDecode(contenido) as Map<String, dynamic>;
  }
}
