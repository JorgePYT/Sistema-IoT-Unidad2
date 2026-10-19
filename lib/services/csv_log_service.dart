
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class CsvLogService {

  // Obtener la ubicación del archivo CSV
  Future<File> obtenerArchivo() async {
    final directorio =
        await getApplicationDocumentsDirectory();

    return File('${directorio.path}/log_sensores.csv');
  }

  // Generar 100 lecturas simuladas de temperatura
  Future<String> generarLogSensores() async {

    final archivo = await obtenerArchivo();

    final random = Random();
    final ahora = DateTime.now();

    // Lista para almacenar las lecturas
    List<List<dynamic>> datos = [
      ['ID', 'Temperatura', 'Timestamp'],
    ];

    // Generar 100 registros de temperatura
    for (int i = 1; i <= 100; i++) {

      // Temperatura aleatoria entre 20 y 40 grados
      double temperatura =
          20 + random.nextDouble() * 20;

      // Crear fecha y hora de cada lectura
      DateTime fecha = ahora.subtract(
        Duration(seconds: (100 - i) * 5),
      );

      // Agregar registro a la lista
      datos.add([
        i,
        temperatura.toStringAsFixed(2),
        fecha.toIso8601String(),
      ]);
    }

    // Convertir los datos a formato CSV
    String contenidoCsv = csv.encode(datos);

    // Calcular checksum SHA-256
    String checksum = sha256
        .convert(utf8.encode(contenidoCsv))
        .toString();

    // Agregar la firma al inicio del archivo
    String contenidoFinal =
        '# CHECKSUM:$checksum\n$contenidoCsv';

    // Guardar el archivo de forma asíncrona
    await archivo.writeAsBytes(
      utf8.encode(contenidoFinal),
      flush: true,
    );

    print('Archivo CSV generado correctamente');
    print('Ubicación: ${archivo.path}');
    print('Registros generados: 100');
    print('Checksum SHA-256: $checksum');

    return archivo.path;
  }

  // Validar integridad del archivo CSV
  Future<bool> validarIntegridad() async {

    final archivo = await obtenerArchivo();

    // Comprobar que el archivo exista
    if (!await archivo.exists()) {
      print('Error: No existe el archivo CSV');
      return false;
    }

    // Leer el contenido del archivo
    final contenido = utf8.decode(
      await archivo.readAsBytes(),
    );

    // Localizar el salto de línea
    final posicionSalto = contenido.indexOf('\n');

    if (posicionSalto == -1) {
      print('Error: Archivo CSV inválido');
      return false;
    }

    // Obtener la cabecera con el checksum
    final cabecera = contenido
        .substring(0, posicionSalto)
        .trim();

    // Verificar que exista el checksum
    if (!cabecera.startsWith('# CHECKSUM:')) {
      print('Error: El archivo no contiene checksum');
      return false;
    }

    // Extraer el checksum original
    final checksumOriginal = cabecera
        .replaceFirst('# CHECKSUM:', '')
        .trim();

    // Obtener únicamente los datos CSV
    final contenidoCsv =
        contenido.substring(posicionSalto + 1);

    // Calcular nuevamente el SHA-256
    final checksumActual = sha256
        .convert(utf8.encode(contenidoCsv))
        .toString();

    // Comparar los dos valores
    if (checksumOriginal == checksumActual) {

      print('Archivo CSV válido');
      print('La integridad de los datos es correcta');

      return true;

    } else {

      print('ALERTA: Archivo CSV corrupto o modificado');
      print('La firma SHA-256 no coincide');

      return false;
    }
  }
}
