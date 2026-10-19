
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/sensor_reading.dart';

// ==========================================
// ACTIVIDAD 2 - UNIDAD 2
// BASE DE DATOS SQLITE
// CRUD + TRANSACCIONES ACID + MIGRACION
// VERSION 1 A VERSION 2
// ==========================================

class DatabaseHelper {

  // ========================================
  // PATRON SINGLETON
  // ========================================

  static final DatabaseHelper instance =
      DatabaseHelper._init();

  static Database? _database;

  // Constructor privado
  DatabaseHelper._init();

  // Obtener la unica instancia de la BD
  Future<Database> get database async {

    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('iot_local.db');

    return _database!;
  }

  // ========================================
  // INICIALIZAR BASE DE DATOS SQLITE
  // ========================================

  Future<Database> _initDB(String nombre) async {

    final dbPath = await getDatabasesPath();
    final ruta = join(dbPath, nombre);

    print('====================================');
    print('BASE DE DATOS SQLITE');
    print('Nombre: $nombre');
    print('Ubicacion: $ruta');
    print('====================================');

    final db = await openDatabase(
      ruta,

      // VERSION ACTUALIZADA
      version: 2,

      // Crear tablas si la BD no existe
      onCreate: _createDB,

      // Migrar BD existente de V1 a V2
      onUpgrade: _upgradeDB,

      // Activar integridad referencial
      onConfigure: (db) async {
        await db.execute(
          'PRAGMA foreign_keys = ON',
        );

        print('Claves foraneas activadas');
      },
    );

    // Comprobar la version real
    final versionActual = await db.getVersion();

    // Contar lecturas almacenadas
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM readings',
    );

    // Consultar columnas de la tabla
    final columnas = await db.rawQuery(
      'PRAGMA table_info(readings)',
    );

    // Verificar que exista ubicacion_nodo
    final tieneUbicacion = columnas.any(
      (columna) =>
          columna['name'] == 'ubicacion_nodo',
    );

    print('====================================');
    print('RESULTADO DE SQLITE');
    print('Version SQLite: $versionActual');
    print(
      'Lecturas conservadas: ${resultado.first['total']}',
    );
    print(
      'Columna ubicacion_nodo: $tieneUbicacion',
    );
    print('====================================');

    return db;
  }

  // ========================================
  // CREACION DE TABLAS PARA VERSION 2
  // ========================================

  Future<void> _createDB(
    Database db,
    int version,
  ) async {

    // TABLA DE NODOS IoT
    await db.execute('''
      CREATE TABLE nodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        ubicacion TEXT NOT NULL
      )
    ''');

    // TABLA DE LECTURAS DE SENSORES
    await db.execute('''
      CREATE TABLE readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        node_id INTEGER NOT NULL,
        sensorType TEXT NOT NULL,
        value REAL NOT NULL,
        timestamp TEXT NOT NULL,
        ubicacion_nodo TEXT,

        FOREIGN KEY (node_id)
        REFERENCES nodes(id)
        ON DELETE CASCADE
      )
    ''');

    print('Tablas de SQLite V2 creadas correctamente');
  }

  // ========================================
  // MIGRACION VERSION 1 A VERSION 2
  // ========================================

  Future<void> _upgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {

    print('====================================');
    print('INICIANDO MIGRACION SQLITE');
    print('Version anterior: $oldVersion');
    print('Version nueva: $newVersion');
    print('====================================');

    // Si la base de datos es anterior a V2
    if (oldVersion < 2) {

      // Agregar la nueva columna
      // SIN BORRAR LOS REGISTROS
      await db.execute('''
        ALTER TABLE readings
        ADD COLUMN ubicacion_nodo TEXT
      ''');

      print('Columna ubicacion_nodo agregada');

      // Obtener la ubicacion de cada nodo
      // y asignarla a sus lecturas anteriores
      await db.execute('''
        UPDATE readings
        SET ubicacion_nodo = (
          SELECT nodes.ubicacion
          FROM nodes
          WHERE nodes.id = readings.node_id
        )
        WHERE ubicacion_nodo IS NULL
      ''');

      print('Ubicaciones anteriores recuperadas');
      print('Migracion V1 a V2 completada');
    }
  }

  // ========================================
  // CRUD DE NODOS IoT
  // ========================================

  // CREATE - INSERTAR NODO
  Future<int> insertarNodo(
    String nombre,
    String ubicacion,
  ) async {

    final db = await database;

    return await db.insert(
      'nodes',
      {
        'nombre': nombre,
        'ubicacion': ubicacion,
      },
    );
  }

  // READ - CONSULTAR NODOS
  Future<List<Map<String, dynamic>>>
      obtenerNodos() async {

    final db = await database;

    return await db.query(
      'nodes',
      orderBy: 'id DESC',
    );
  }

  // UPDATE - MODIFICAR NODO
  Future<int> actualizarNodo(
    int id,
    String nombre,
    String ubicacion,
  ) async {

    final db = await database;

    return await db.update(
      'nodes',
      {
        'nombre': nombre,
        'ubicacion': ubicacion,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE - ELIMINAR NODO
  Future<int> eliminarNodo(int id) async {

    final db = await database;

    return await db.delete(
      'nodes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========================================
  // CRUD DE LECTURAS DE SENSORES
  // ========================================

  // CREATE - INSERTAR LECTURA
  Future<int> insertarLectura(
    SensorReading lectura,
  ) async {

    final db = await database;

    // Obtener la ubicacion del nodo
    final nodos = await db.query(
      'nodes',
      columns: ['ubicacion'],
      where: 'id = ?',
      whereArgs: [lectura.nodeId],
      limit: 1,
    );

    final datos = lectura.toMap();

    if (nodos.isNotEmpty) {
      datos['ubicacion_nodo'] =
          nodos.first['ubicacion'];
    }

    return await db.insert(
      'readings',
      datos,
    );
  }

  // READ - CONSULTAR TODAS LAS LECTURAS
  Future<List<SensorReading>>
      obtenerTodasLasLecturas() async {

    final db = await database;

    final resultados = await db.query(
      'readings',
      orderBy: 'id DESC',
    );

    return resultados.map((dato) {
      return SensorReading.fromMap(dato);
    }).toList();
  }

  // READ - CONSULTAR LECTURAS POR TIPO
  Future<List<SensorReading>> obtenerLecturas(
    String tipo,
  ) async {

    final db = await database;

    final resultados = await db.query(
      'readings',
      where: 'sensorType = ?',
      whereArgs: [tipo],
      orderBy: 'id DESC',
    );

    return resultados.map((dato) {
      return SensorReading.fromMap(dato);
    }).toList();
  }

  // UPDATE - MODIFICAR LECTURA
  Future<int> actualizarLectura(
    int id,
    SensorReading lectura,
  ) async {

    final db = await database;

    final nodos = await db.query(
      'nodes',
      columns: ['ubicacion'],
      where: 'id = ?',
      whereArgs: [lectura.nodeId],
      limit: 1,
    );

    final datos = {
      'node_id': lectura.nodeId,
      'sensorType': lectura.sensorType,
      'value': lectura.value,
      'timestamp': lectura.timestamp,
      'ubicacion_nodo':
          nodos.isNotEmpty
              ? nodos.first['ubicacion']
              : null,
    };

    return await db.update(
      'readings',
      datos,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE - ELIMINAR LECTURA
  Future<int> eliminarLectura(int id) async {

    final db = await database;

    return await db.delete(
      'readings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========================================
  // TRANSACCIONES ACID
  // INSERCION MASIVA DE LECTURAS
  // ========================================

  Future<void> insertarLecturasEnLote(
    List<SensorReading> lecturas,
  ) async {

    final db = await database;

    await db.transaction((txn) async {

      final batch = txn.batch();

      // Consultar las ubicaciones de los nodos
      final nodos = await txn.query(
        'nodes',
        columns: ['id', 'ubicacion'],
      );

      final ubicaciones = <int, String>{};

      for (final nodo in nodos) {
        ubicaciones[nodo['id'] as int] =
            nodo['ubicacion'] as String;
      }

      // Insertar todas las lecturas
      for (final lectura in lecturas) {

        final datos = lectura.toMap();

        datos['ubicacion_nodo'] =
            ubicaciones[lectura.nodeId];

        batch.insert(
          'readings',
          datos,
        );
      }

      // Ejecutar inserciones en lote
      await batch.commit(noResult: true);
    });

    print('====================================');
    print('TRANSACCION ACID COMPLETADA');
    print(
      'Lecturas insertadas: ${lecturas.length}',
    );
    print('====================================');
  }

  // ========================================
  // CONSULTAR INFORMACION DE MIGRACION
  // ========================================

  Future<Map<String, dynamic>>
      verificarMigracion() async {

    final db = await database;

    final version = await db.getVersion();

    final resultado = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM readings',
    );

    final columnas = await db.rawQuery(
      'PRAGMA table_info(readings)',
    );

    final existeColumna = columnas.any(
      (columna) =>
          columna['name'] == 'ubicacion_nodo',
    );

    return {
      'version': version,
      'total_lecturas': resultado.first['total'],
      'ubicacion_nodo': existeColumna,
    };
  }

  // ========================================
  // CERRAR BASE DE DATOS
  // ========================================

  Future<void> cerrarBaseDatos() async {

    if (_database != null) {

      await _database!.close();

      _database = null;

      print('Base de datos SQLite cerrada');
    }
  }
}
