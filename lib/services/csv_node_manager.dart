
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

// ACTIVIDAD 2 - UNIDAD 2
// Exportación e importación CSV con SHA-256

class CsvNodeManager {

  // Obtener la ubicación del archivo CSV
  Future<File> obtenerArchivo() async {
    final directorio =
        await getApplicationDocumentsDirectory();

    return File(
      '${directorio.path}/iot_nodes_config.csv',
    );
  }

  // EXPORTAR NODOS IoT A CSV
  Future<String> exportarNodos(
    List<Map<String, dynamic>> nodos,
  ) async {

    final archivo = await obtenerArchivo();

    // Crear cabecera y registros
    final filas = <List<dynamic>>[
      ['id', 'nombre', 'ubicacion'],
      ...nodos.map((nodo) => [
        nodo['id'],
        nodo['nombre'],
        nodo['ubicacion'],
      ]),
    ];

    // Convertir los registros a CSV
    final contenidoCsv = csv.encode(filas);

    // Calcular checksum SHA-256
    final checksum = sha256
        .convert(utf8.encode(contenidoCsv))
        .toString();

    // Agregar la firma al archivo
    final contenidoFinal =
        '# CHECKSUM:$checksum\n$contenidoCsv';

    // Guardar los bytes del archivo
    await archivo.writeAsBytes(
      utf8.encode(contenidoFinal),
      flush: true,
    );

    print('CSV exportado correctamente');
    print('Ruta: ${archivo.path}');
    print('Checksum: $checksum');

    return archivo.path;
  }

  // IMPORTAR Y VALIDAR NODOS IoT
  Future<List<Map<String, dynamic>>> importarNodos()
      async {

    final archivo = await obtenerArchivo();

    // Comprobar existencia
    if (!await archivo.exists()) {
      throw FileSystemException(
        'El archivo CSV no existe',
        archivo.path,
      );
    }

    // Leer archivo
    final contenido = utf8.decode(
      await archivo.readAsBytes(),
    );

    // Separar checksum y contenido
    final salto = contenido.indexOf('\n');

    if (salto == -1) {
      throw const FormatException(
        'Archivo CSV inválido',
      );
    }

    final cabecera =
        contenido.substring(0, salto).trim();

    if (!cabecera.startsWith('# CHECKSUM:')) {
      throw const FormatException(
        'No se encontró el checksum',
      );
    }

    final checksumOriginal = cabecera
        .replaceFirst('# CHECKSUM:', '')
        .trim();

    final contenidoCsv =
        contenido.substring(salto + 1);

    // Recalcular SHA-256
    final checksumActual = sha256
        .convert(utf8.encode(contenidoCsv))
        .toString();

    // Rechazar archivos modificados
    if (checksumOriginal != checksumActual) {
      throw const FormatException(
        'Archivo corrupto: SHA-256 no coincide',
      );
    }

    // Convertir CSV a registros
    final filas = csv.decode(contenidoCsv);

    if (filas.isEmpty ||
        filas.first.join(',') !=
            'id,nombre,ubicacion') {
      throw const FormatException(
        'Cabecera CSV incorrecta',
      );
    }

    final nodos = <Map<String, dynamic>>[];

    for (final fila in filas.skip(1)) {

      if (fila.length != 3) {
        throw const FormatException(
          'Registro CSV inválido',
        );
      }

      final id = int.tryParse(
        fila[0].toString(),
      );

      final nombre = fila[1].toString();
      final ubicacion = fila[2].toString();

      if (id == null ||
          id <= 0 ||
          nombre.trim().isEmpty ||
          ubicacion.trim().isEmpty) {
        throw const FormatException(
          'Datos del nodo inválidos',
        );
      }

      nodos.add({
        'id': id,
        'nombre': nombre,
        'ubicacion': ubicacion,
      });
    }

    print('Integridad SHA-256 correcta');
    print('Nodos importados: ${nodos.length}');

    return nodos;
  }
}
