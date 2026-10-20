
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/sensor_reading.dart';

// ACTIVIDAD 3 - UNIDAD 2
// SQLite V3: CRUD, transacciones, migraciones y alertas

class DatabaseHelper {
  // PATRON SINGLETON
  static final DatabaseHelper instance =
      DatabaseHelper._init();

  static Database? _database;

  static const double umbralTemperatura = 35.0;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB('iot_local.db');
    return _database!;
  }

  // INICIALIZAR SQLITE
  Future<Database> _initDB(String nombre) async {
    final dbPath = await getDatabasesPath();
    final ruta = join(dbPath, nombre);

    debugPrint('BASE DE DATOS SQLITE: $ruta');

    final db = await openDatabase(
      ruta,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        debugPrint('Claves foraneas activadas');
      },
    );

    final version = await db.getVersion();

    final lecturas = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM readings',
      ),
    ) ?? 0;

    final alertas = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM alerts',
      ),
    ) ?? 0;

    debugPrint('================================');
    debugPrint('VERSION SQLITE: $version');
    debugPrint('LECTURAS CONSERVADAS: $lecturas');
    debugPrint('ALERTAS REGISTRADAS: $alertas');
    debugPrint('================================');

    return db;
  }

  // CREAR BASE DE DATOS NUEVA EN V3
  Future<void> _createDB(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE nodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        ubicacion TEXT NOT NULL
      )
    ''');

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

    await _crearTablaAlertas(db);

    debugPrint('Base de datos V3 creada');
  }

  // CREAR TABLA DE ALERTAS
  Future<void> _crearTablaAlertas(
    Database db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reading_id INTEGER NOT NULL,
        node_id INTEGER NOT NULL,
        mensaje TEXT NOT NULL,
        valor REAL NOT NULL,
        timestamp TEXT NOT NULL,

        FOREIGN KEY (reading_id)
          REFERENCES readings(id)
          ON DELETE CASCADE,

        FOREIGN KEY (node_id)
          REFERENCES nodes(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_alerts_timestamp
      ON alerts(timestamp)
    ''');
  }

  // MIGRACIONES DE SQLITE
  Future<void> _upgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    debugPrint(
      'Migrando SQLite V$oldVersion a V$newVersion',
    );

    // MIGRACION V1 -> V2
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE readings
        ADD COLUMN ubicacion_nodo TEXT
      ''');

      await db.execute('''
        UPDATE readings
        SET ubicacion_nodo = (
          SELECT ubicacion
          FROM nodes
          WHERE nodes.id = readings.node_id
        )
        WHERE ubicacion_nodo IS NULL
      ''');

      debugPrint('Migracion V1 a V2 completada');
    }

    // MIGRACION V2 -> V3
    if (oldVersion < 3) {
      await _crearTablaAlertas(db);

      // Recuperar alertas de temperaturas antiguas
      // que ya superaban el umbral.
      await db.rawInsert('''
        INSERT INTO alerts (
          reading_id,
          node_id,
          mensaje,
          valor,
          timestamp
        )
        SELECT
          id,
          node_id,
          'Temperatura superior a 35 °C',
          value,
          timestamp
        FROM readings
        WHERE LOWER(sensorType) IN (
          'temperature',
          'temperatura'
        )
        AND value > 35
      ''');

      debugPrint('Tabla alerts creada');
      debugPrint('Migracion V2 a V3 completada');
    }
  }

  // COMPROBAR SI UNA LECTURA ES ALERTA
  bool _esAlerta(SensorReading lectura) {
    final tipo = lectura.sensorType.toLowerCase();

    return (tipo == 'temperature' ||
            tipo == 'temperatura') &&
        lectura.value > umbralTemperatura;
  }

  // ==================================
  // CRUD DE NODOS
  // ==================================

  Future<int> insertarNodo(
    String nombre,
    String ubicacion,
  ) async {
    final db = await database;

    return db.insert('nodes', {
      'nombre': nombre,
      'ubicacion': ubicacion,
    });
  }

  Future<List<Map<String, dynamic>>>
      obtenerNodos() async {
    final db = await database;

    return db.query(
      'nodes',
      orderBy: 'id DESC',
    );
  }

  Future<int> actualizarNodo(
    int id,
    String nombre,
    String ubicacion,
  ) async {
    final db = await database;

    return db.update(
      'nodes',
      {
        'nombre': nombre,
        'ubicacion': ubicacion,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarNodo(int id) async {
    final db = await database;

    return db.delete(
      'nodes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================================
  // REGISTRAR LECTURAS Y ALERTAS
  // ==================================

  Future<int> insertarLectura(
    SensorReading lectura,
  ) async {
    final db = await database;

    // La lectura y su alerta se guardan juntas.
    return db.transaction((txn) async {
      final nodos = await txn.query(
        'nodes',
        columns: ['ubicacion'],
        where: 'id = ?',
        whereArgs: [lectura.nodeId],
        limit: 1,
      );

      if (nodos.isEmpty) {
        throw StateError(
          'El nodo ${lectura.nodeId} no existe',
        );
      }

      final datos = lectura.toMap();
      datos['ubicacion_nodo'] =
          nodos.first['ubicacion'];

      final readingId = await txn.insert(
        'readings',
        datos,
      );

      if (_esAlerta(lectura)) {
        await txn.insert('alerts', {
          'reading_id': readingId,
          'node_id': lectura.nodeId,
          'mensaje':
              'Temperatura superior a 35 °C',
          'valor': lectura.value,
          'timestamp': lectura.timestamp,
        });

        debugPrint(
          'ALERTA IoT: ${lectura.value} °C',
        );
      }

      return readingId;
    });
  }

  // CONSULTAR TODAS LAS LECTURAS
  Future<List<SensorReading>>
      obtenerTodasLasLecturas() async {
    final db = await database;

    final resultados = await db.query(
      'readings',
      orderBy: 'id DESC',
    );

    return resultados
        .map((dato) => SensorReading.fromMap(dato))
        .toList();
  }

  // CONSULTAR LECTURAS POR TIPO
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

    return resultados
        .map((dato) => SensorReading.fromMap(dato))
        .toList();
  }

  // ACTUALIZAR LECTURA
  Future<int> actualizarLectura(
    int id,
    SensorReading lectura,
  ) async {
    final db = await database;

    return db.transaction((txn) async {
      final nodos = await txn.query(
        'nodes',
        columns: ['ubicacion'],
        where: 'id = ?',
        whereArgs: [lectura.nodeId],
        limit: 1,
      );

      if (nodos.isEmpty) {
        throw StateError(
          'Nodo inexistente',
        );
      }

      final actualizadas = await txn.update(
        'readings',
        {
          'node_id': lectura.nodeId,
          'sensorType': lectura.sensorType,
          'value': lectura.value,
          'timestamp': lectura.timestamp,
          'ubicacion_nodo':
              nodos.first['ubicacion'],
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (actualizadas > 0) {
        // Actualizar el estado de alerta.
        await txn.delete(
          'alerts',
          where: 'reading_id = ?',
          whereArgs: [id],
        );

        if (_esAlerta(lectura)) {
          await txn.insert('alerts', {
            'reading_id': id,
            'node_id': lectura.nodeId,
            'mensaje':
                'Temperatura superior a 35 °C',
            'valor': lectura.value,
            'timestamp': lectura.timestamp,
          });
        }
      }

      return actualizadas;
    });
  }

  // ELIMINAR LECTURA
  Future<int> eliminarLectura(int id) async {
    final db = await database;

    return db.delete(
      'readings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================================
  // INSERCIONES MASIVAS ACID
  // ==================================

  Future<void> insertarLecturasEnLote(
    List<SensorReading> lecturas,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      final nodos = await txn.query(
        'nodes',
        columns: ['id', 'ubicacion'],
      );

      final ubicaciones = <int, String>{};

      for (final nodo in nodos) {
        ubicaciones[nodo['id'] as int] =
            nodo['ubicacion'] as String;
      }

      final batch = txn.batch();

      for (final lectura in lecturas) {
        final ubicacion =
            ubicaciones[lectura.nodeId];

        if (ubicacion == null) {
          throw StateError(
            'Nodo ${lectura.nodeId} inexistente',
          );
        }

        final datos = lectura.toMap();
        datos['ubicacion_nodo'] = ubicacion;

        batch.insert('readings', datos);
      }

      final resultados = await batch.commit(
        noResult: false,
      );

      // Registrar alertas de lecturas del lote.
      for (int i = 0; i < lecturas.length; i++) {
        final lectura = lecturas[i];

        if (!_esAlerta(lectura)) continue;

        final readingId = resultados[i];

        if (readingId is! int) {
          throw StateError(
            'No se obtuvo el ID de la lectura',
          );
        }

        await txn.insert('alerts', {
          'reading_id': readingId,
          'node_id': lectura.nodeId,
          'mensaje':
              'Temperatura superior a 35 °C',
          'valor': lectura.value,
          'timestamp': lectura.timestamp,
        });
      }
    });

    debugPrint(
      '${lecturas.length} lecturas procesadas',
    );
  }

  // ==================================
  // CONSULTAR ALERTAS
  // ==================================

  Future<List<Map<String, dynamic>>>
      obtenerAlertas() async {
    final db = await database;

    return db.query(
      'alerts',
      orderBy: 'timestamp DESC',
    );
  }

  // VERIFICAR MIGRACION
  Future<Map<String, dynamic>>
      verificarMigracion() async {
    final db = await database;

    final version = await db.getVersion();

    final lecturas = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM readings',
      ),
    ) ?? 0;

    final alertas = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM alerts',
      ),
    ) ?? 0;

    final columnas = await db.rawQuery(
      'PRAGMA table_info(readings)',
    );

    return {
      'version': version,
      'total_lecturas': lecturas,
      'ubicacion_nodo': columnas.any(
        (c) => c['name'] == 'ubicacion_nodo',
      ),
      'total_alertas': alertas,
    };
  }

  // CERRAR BASE DE DATOS
  Future<void> cerrarBaseDatos() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
