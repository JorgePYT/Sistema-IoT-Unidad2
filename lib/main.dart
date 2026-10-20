
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// PANTALLAS DEL PROYECTO
import 'screens/preferencias_screen.dart';
import 'screens/csv_log_screen.dart';
import 'screens/csv_nodes_screen.dart';
import 'screens/crud_screen.dart';
import 'screens/historical_alerts_screen.dart';

// BASE DE DATOS SQLITE
import 'database/database_helper.dart';

// ======================================
// INICIO DE LA APLICACIÓN
// ======================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar SQLite para Windows, Linux y macOS
  if (Platform.isWindows ||
      Platform.isLinux ||
      Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    debugPrint('SQLite configurado para escritorio');
  }

  // Inicializar la base de datos
  try {
    final db = await DatabaseHelper.instance.database;

    debugPrint('Base de datos SQLite inicializada');

    // Consultar tablas existentes
    final tablas = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' "
      "ORDER BY name",
    );

    debugPrint('TABLAS SQLITE: $tablas');

    // Verificar migración SQLite V2
    final migracion =
        await DatabaseHelper.instance.verificarMigracion();

    debugPrint('MIGRACIÓN SQLITE: $migracion');
  } catch (e) {
    debugPrint('Error al inicializar SQLite: $e');
  }

  runApp(const MyApp());
}

// ======================================
// APLICACIÓN PRINCIPAL
// ======================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema IoT - Unidad 2',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),

      home: const InicioScreen(),
    );
  }
}

// ======================================
// MENÚ PRINCIPAL
// ======================================

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  // Crear tarjetas para los módulos
  Widget crearTarjeta({
    required BuildContext context,
    required String titulo,
    required String descripcion,
    required IconData icono,
    required Color color,
    required Widget pantalla,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),

      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            Icon(
              icono,
              size: 50,
              color: color,
            ),

            const SizedBox(height: 12),

            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              descripcion,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Abrir módulo'),

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => pantalla,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema IoT - Unidad 2'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 650,
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                const SizedBox(height: 20),

                const Icon(
                  Icons.sensors,
                  size: 90,
                  color: Colors.blue,
                ),

                const SizedBox(height: 15),

                const Text(
                  'Sistema de Monitoreo IoT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Unidad 2 - Almacenamiento, '
                  'Persistencia y Bases de Datos Móviles',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 35),

                // ==================================
                // MÓDULO 1 - JSON
                // ==================================

                crearTarjeta(
                  context: context,
                  titulo: 'Preferencias JSON',
                  descripcion:
                      'Guardar tema oscuro y configurar '
                      'el intervalo de muestreo IoT.',
                  icono: Icons.settings,
                  color: Colors.blue,
                  pantalla: const PreferenciasScreen(),
                ),

                // ==================================
                // MÓDULO 2 - CSV SENSORES
                // ==================================

                crearTarjeta(
                  context: context,
                  titulo: 'Registro CSV de Sensores',
                  descripcion:
                      'Generar 100 lecturas de temperatura '
                      'y verificar integridad SHA-256.',
                  icono: Icons.thermostat,
                  color: Colors.orange,
                  pantalla: const CsvLogScreen(),
                ),

                // ==================================
                // MÓDULO 3 - CSV NODOS
                // ==================================

                crearTarjeta(
                  context: context,
                  titulo: 'Nodos IoT - CSV',
                  descripcion:
                      'Exportar, importar y validar '
                      'la información de nodos ESP32.',
                  icono: Icons.memory,
                  color: Colors.green,
                  pantalla: const CsvNodesScreen(),
                ),

                // ==================================
                // MÓDULO 4 - CRUD SQLITE
                // ==================================

                crearTarjeta(
                  context: context,
                  titulo: 'CRUD SQLite - IoT',
                  descripcion:
                      'Registrar, consultar, modificar '
                      'y eliminar nodos ESP32. '
                      'Realizar transacciones ACID '
                      'y sincronizar lecturas con MySQL.',
                  icono: Icons.storage,
                  color: Colors.deepPurple,
                  pantalla: const CrudScreen(),
                ),

                // ==================================
                // MÓDULO 5 - HISTORIAL Y ALERTAS
                // ACTIVIDAD 3
                // ==================================

                crearTarjeta(
                  context: context,
                  titulo: 'Histórico y Alertas IoT',
                  descripcion:
                      'Consultar el historial de lecturas '
                      'almacenadas en SQLite mediante '
                      'FutureBuilder y ListView.builder. '
                      'Identificar temperaturas '
                      'superiores a 35 °C.',
                  icono: Icons.warning_amber_rounded,
                  color: Colors.red,
                  pantalla: const HistoricalAlertsScreen(),
                ),

                const SizedBox(height: 20),

                // ==================================
                // INFORMACIÓN SQLITE
                // ==================================

                const Card(
                  elevation: 2,

                  child: Padding(
                    padding: EdgeInsets.all(20),

                    child: Column(
                      children: [
                        Icon(
                          Icons.storage,
                          size: 45,
                          color: Colors.deepPurple,
                        ),

                        SizedBox(height: 10),

                        Text(
                          'Base de Datos Local SQLite',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 10),

                        Text(
                          'Archivo: iot_local.db',
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 5),

                        Text(
                          'Versión: 2',
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 5),

                        Text(
                          'Tablas: nodes y readings',
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 10),

                        Text(
                          'Historial de sensores '
                          'y persistencia local IoT.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Proyecto Integrador '
                  'Smart-Environment IoT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
