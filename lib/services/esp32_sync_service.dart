
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/database_helper.dart';

// ACTIVIDAD 3 - UNIDAD 2
// Sincronizar lecturas ESP32 desde MySQL a SQLite

class Esp32SyncResult {
  final int recibidas;
  final int importadas;
  final int duplicadas;
  final int alertasNuevas;

  const Esp32SyncResult({
    required this.recibidas,
    required this.importadas,
    required this.duplicadas,
    required this.alertasNuevas,
  });
}

class Esp32SyncService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // API PHP de XAMPP
  // Para Flutter ejecutado en Windows
  static const String apiUrl =
      'http://127.0.0.1/iot_api/listar_lecturas_esp32.php';

  static const double umbralTemperatura = 35.0;

  // CONSULTAR API Y SINCRONIZAR CON SQLITE
  Future<Esp32SyncResult> sincronizarLecturas() async {

    debugPrint('Consultando lecturas del ESP32...');

    // Consultar MySQL mediante la API
    final respuesta = await http.get(
      Uri.parse(apiUrl),
    ).timeout(
      const Duration(seconds: 20),
    );

    if (respuesta.statusCode != 200) {
      throw Exception(
        'Error HTTP ${respuesta.statusCode}',
      );
    }

    // Convertir respuesta JSON
    final respuestaJson = jsonDecode(
      utf8.decode(respuesta.bodyBytes),
    );

    if (respuestaJson is! Map ||
        respuestaJson['success'] != true ||
        respuestaJson['lecturas'] is! List) {
      throw const FormatException(
        'Respuesta incorrecta de la API',
      );
    }

    final registros = respuestaJson['lecturas'] as List;

    // Validar todos los datos antes de guardarlos
    final lecturasValidas = <Map<String, dynamic>>[];

    for (final registro in registros) {

      if (registro is! Map) {
        throw const FormatException(
          'Registro inválido recibido',
        );
      }

      final dato = Map<String, dynamic>.from(registro);

      final nombre =
          (dato['nombre_nodo'] ?? '').toString().trim();

      final ubicacion =
          (dato['ubicacion_nodo'] ?? '').toString().trim();

      final tipo =
          (dato['sensorType'] ?? '').toString().trim();

      final timestamp =
          (dato['timestamp'] ?? '').toString().trim();

      final syncKey =
          (dato['sync_key'] ?? '').toString().trim();

      final valor = double.tryParse(
        dato['value'].toString(),
      );

      if (nombre.isEmpty ||
          ubicacion.isEmpty ||
          tipo.isEmpty ||
          timestamp.isEmpty ||
          DateTime.tryParse(timestamp) == null ||
          valor == null ||
          !valor.isFinite ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(syncKey)) {
        throw const FormatException(
          'Una lectura contiene datos inválidos',
        );
      }

      lecturasValidas.add({
        'nombre': nombre,
        'ubicacion': ubicacion,
        'sensorType': tipo,
        'value': valor,
        'timestamp': timestamp,
        'sync_key': syncKey,
      });
    }

    // Abrir SQLite
    final db = await _db.database;

    // Tabla auxiliar para recordar cuáles lecturas
    // del ESP32 ya fueron importadas.
    // No se modifican los registros existentes.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS esp32_imports (
        sync_key TEXT PRIMARY KEY NOT NULL,
        reading_id INTEGER NOT NULL,

        FOREIGN KEY (reading_id)
          REFERENCES readings(id)
          ON DELETE CASCADE
      )
    ''');

    int importadas = 0;
    int duplicadas = 0;
    int alertasNuevas = 0;

    // Guardar lecturas en una transacción ACID
    await db.transaction((txn) async {

      for (final lectura in lecturasValidas) {

        final syncKey = lectura['sync_key'] as String;

        // COMPROBAR SI YA SE IMPORTÓ
        final existente = await txn.query(
          'esp32_imports',
          columns: ['sync_key'],
          where: 'sync_key = ?',
          whereArgs: [syncKey],
          limit: 1,
        );

        if (existente.isNotEmpty) {
          duplicadas++;
          continue;
        }

        final nombre = lectura['nombre'] as String;
        final ubicacion = lectura['ubicacion'] as String;

        // BUSCAR NODO EN SQLITE
        final nodos = await txn.query(
          'nodes',
          where: 'nombre = ? AND ubicacion = ?',
          whereArgs: [nombre, ubicacion],
          limit: 1,
        );

        late int nodeId;

        if (nodos.isNotEmpty) {
          nodeId = nodos.first['id'] as int;
        } else {

          // Registrar nodo ESP32 si no existe
          nodeId = await txn.insert(
            'nodes',
            {
              'nombre': nombre,
              'ubicacion': ubicacion,
            },
          );
        }

        final tipo = lectura['sensorType'] as String;
        final valor = lectura['value'] as double;
        final fecha = lectura['timestamp'] as String;

        // GUARDAR LECTURA EN SQLITE
        final readingId = await txn.insert(
          'readings',
          {
            'node_id': nodeId,
            'sensorType': tipo,
            'value': valor,
            'timestamp': fecha,
            'ubicacion_nodo': ubicacion,
          },
        );

        // DETECTAR ALERTA POR TEMPERATURA
        final esTemperatura =
            tipo.toLowerCase() == 'temperature' ||
            tipo.toLowerCase() == 'temperatura';

        final esAlerta =
            esTemperatura && valor > umbralTemperatura;

        if (esAlerta) {

          await txn.insert(
            'alerts',
            {
              'reading_id': readingId,
              'node_id': nodeId,
              'mensaje':
                  'Temperatura superior a 35 °C',
              'valor': valor,
              'timestamp': fecha,
            },
          );

          alertasNuevas++;

          debugPrint(
            'ALERTA ESP32: $valor °C',
          );
        }

        // Guardar la clave para evitar duplicados
        await txn.insert(
          'esp32_imports',
          {
            'sync_key': syncKey,
            'reading_id': readingId,
          },
        );

        importadas++;
      }
    });

    debugPrint('================================');
    debugPrint('SINCRONIZACION ESP32 COMPLETADA');
    debugPrint('Recibidas: ${registros.length}');
    debugPrint('Importadas: $importadas');
    debugPrint('Duplicadas: $duplicadas');
    debugPrint('Alertas nuevas: $alertasNuevas');
    debugPrint('================================');

    return Esp32SyncResult(
      recibidas: registros.length,
      importadas: importadas,
      duplicadas: duplicadas,
      alertasNuevas: alertasNuevas,
    );
  }
}
