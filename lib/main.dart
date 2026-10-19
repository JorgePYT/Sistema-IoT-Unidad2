
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// PANTALLAS DEL PROYECTO
import 'screens/preferencias_screen.dart';
import 'screens/csv_log_screen.dart';
import 'screens/csv_nodes_screen.dart';
import 'screens/crud_screen.dart';

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

  // Inicializar base de datos SQLite
  try {
    final db = await DatabaseHelper.instance.database;

    debugPrint('Base de datos SQLite inicializada');

    // Consultar las tablas existentes
    final tablas = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' "
      "ORDER BY name",
    );

    debugPrint('TABLAS SQLITE: $tablas');

  } catch (e) {
    debugPrint('Error al inicializar SQLite: $e');
  }

  // Ejecutar aplicación
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
// PANTALLA PRINCIPAL
// ======================================

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  // Crear tarjetas para acceder a los módulos
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
              icon: const Icon(
                Icons.arrow_forward,
              ),

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

  // ======================================
  // DISEÑO DEL MENÚ PRINCIPAL
  // ======================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'Sistema IoT - Unidad 2',
        ),

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
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [

                const SizedBox(height: 20),

                // ICONO PRINCIPAL
                const Icon(
                  Icons.sensors,
                  size: 90,
                  color: Colors.blue,
                ),

                const SizedBox(height: 15),

                // TÍTULO PRINCIPAL
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

                // ======================================
                // MÓDULO 1 - PREFERENCIAS JSON
                // ======================================

                crearTarjeta(
                  context: context,

                  titulo: 'Preferencias JSON',

                  descripcion:
                      'Guardar tema oscuro e intervalo '
                      'de muestreo de sensores IoT.',

                  icono: Icons.settings,

                  color: Colors.blue,

                  pantalla: const PreferenciasScreen(),
                ),

                // ======================================
                // MÓDULO 2 - CSV DE TEMPERATURAS
                // ======================================

                crearTarjeta(
                  context: context,

                  titulo: 'Registro CSV de Sensores',

                  descripcion:
                      'Generar 100 lecturas simuladas '
                      'de temperatura y validar '
                      'su integridad SHA-256.',

                  icono: Icons.thermostat,

                  color: Colors.orange,

                  pantalla: const CsvLogScreen(),
                ),

                // ======================================
                // MÓDULO 3 - NODOS IoT CSV
                // ======================================

                crearTarjeta(
                  context: context,

                  titulo: 'Nodos IoT - CSV',

                  descripcion:
                      'Exportar e importar nodos ESP32 '
                      'y comprobar la integridad '
                      'de los archivos mediante SHA-256.',

                  icono: Icons.memory,

                  color: Colors.green,

                  pantalla: const CsvNodesScreen(),
                ),

                // ======================================
                // MÓDULO 4 - CRUD SQLITE
                // ======================================

                crearTarjeta(
                  context: context,

                  titulo: 'CRUD SQLite - IoT',

                  descripcion:
                      'Registrar, consultar, actualizar '
                      'y eliminar nodos ESP32. '
                      'Guardar lecturas masivas '
                      'mediante transacciones ACID.',

                  icono: Icons.storage,

                  color: Colors.deepPurple,

                  pantalla: const CrudScreen(),
                ),

                const SizedBox(height: 20),

                // ======================================
                // INFORMACIÓN DE SQLITE
                // ======================================

                const Card(
                  elevation: 2,

                  child: Padding(
                    padding: EdgeInsets.all(20),

                    child: Column(
                      children: [

                        // ICONO CORREGIDO
                        Icon(
                          Icons.storage,
                          size: 45,
                          color: Colors.deepPurple,
                        ),

                        SizedBox(height: 10),

                        Text(
                          'Base de Datos Local',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 10),

                        Text(
                          'SQLite - iot_local.db',
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 5),

                        Text(
                          'Tablas: nodes y readings',
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 10),

                        Text(
                          'Almacenamiento local de '
                          'nodos y lecturas de sensores IoT.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // PIE DE PÁGINA
                const Text(
                  'Proyecto Flutter - Actividad 2',
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
