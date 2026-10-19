
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import '../database/database_helper.dart';
import '../models/sensor_reading.dart';

// ACTIVIDAD 2 - UNIDAD 2
// Sincronizar SQLite con MySQL mediante API PHP

class MySqlSyncService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Dirección de la API instalada en XAMPP
  // Funciona cuando Flutter se ejecuta en Windows
  static const String apiUrl =
      'http://127.0.0.1/iot_api/subir_lecturas.php';

  // Identificador para evitar duplicaciones
  String generarClave(SensorReading lectura) {
    final datos =
        '${lectura.nodeId}|${lectura.id}|'
        '${lectura.sensorType}|${lectura.timestamp}';

    return sha256.convert(utf8.encode(datos)).toString();
  }

  // Enviar lecturas locales hacia MySQL
  Future<int> sincronizarLecturas() async {
    // Consultar nodos almacenados en SQLite
    final nodos = await _db.obtenerNodos();

    // Consultar todas las lecturas
    final lecturas =
        await _db.obtenerTodasLasLecturas();

    if (lecturas.isEmpty) {
      throw Exception(
        'No existen lecturas para sincronizar',
      );
    }

    int totalEnviado = 0;

    final cliente = http.Client();

    try {
      // Agrupar lecturas según su nodo ESP32
      for (final nodo in nodos) {
        final nodeId = nodo['id'] as int;

        final lecturasNodo = lecturas
            .where((lectura) => lectura.nodeId == nodeId)
            .toList();

        if (lecturasNodo.isEmpty) continue;

        // Enviar como máximo 100 lecturas por petición
        for (int i = 0; i < lecturasNodo.length; i += 100) {
          final fin = (i + 100 < lecturasNodo.length)
              ? i + 100
              : lecturasNodo.length;

          final bloque = lecturasNodo.sublist(i, fin);

          // Preparar datos JSON
          final datos = {
            'nodo': {
              'nombre': nodo['nombre'],
              'ubicacion': nodo['ubicacion'],
            },
            'lecturas': bloque.map((lectura) {
              return {
                'sync_key': generarClave(lectura),
                'sensorType': lectura.sensorType,
                'value': lectura.value,
                'timestamp': lectura.timestamp,
              };
            }).toList(),
          };

          // Enviar petición HTTP POST
          final respuesta = await cliente
              .post(
                Uri.parse(apiUrl),
                headers: {
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(datos),
              )
              .timeout(
                const Duration(seconds: 20),
              );

          if (respuesta.statusCode != 200) {
            throw Exception(
              'Error HTTP: ${respuesta.statusCode} '
              '${respuesta.body}',
            );
          }

          final resultado =
              jsonDecode(respuesta.body);

          if (resultado is! Map ||
              resultado['success'] != true) {
            throw Exception(
              'El servidor rechazó las lecturas',
            );
          }

          totalEnviado += bloque.length;

          debugPrint(
            'Bloque de ${bloque.length} '
            'lecturas enviado correctamente',
          );
        }
      }

      if (totalEnviado != lecturas.length) {
        throw Exception(
          'Existen lecturas sin un nodo asociado',
        );
      }

      debugPrint(
        'Sincronización finalizada. '
        'Lecturas enviadas: $totalEnviado',
      );

      return totalEnviado;
    } finally {
      cliente.close();
    }
  }
}
