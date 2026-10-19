
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/sensor_reading.dart';
import '../services/mysql_sync_service.dart';

class CrudScreen extends StatefulWidget {
  const CrudScreen({super.key});

  @override
  State<CrudScreen> createState() => _CrudScreenState();
}

class _CrudScreenState extends State<CrudScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final MySqlSyncService _mysqlService = MySqlSyncService();

  List<Map<String, dynamic>> _nodos = [];
  List<SensorReading> _lecturas = [];

  bool _cargando = true;
  bool _sincronizando = false;

  String _resultadoSync = 'Sin sincronizaciones recientes';

  bool get _ocupado => _cargando || _sincronizando;

  @override
  void initState() {
    super.initState();
    _refrescar();
  }

  // LEER INFORMACION DE SQLITE
  Future<void> _leerDatos() async {
    final nodos = await _db.obtenerNodos();
    final lecturas = await _db.obtenerTodasLasLecturas();

    if (!mounted) return;

    setState(() {
      _nodos = nodos;
      _lecturas = lecturas;
    });
  }

  Future<void> _refrescar() async {
    setState(() => _cargando = true);

    try {
      await _leerDatos();
    } catch (e) {
      if (mounted) {
        _mostrarMensaje('Error al consultar SQLite: $e', true);
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  // MOSTRAR MENSAJES
  void _mostrarMensaje(String texto, bool error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  // EJECUTAR OPERACIONES CRUD
  Future<void> _ejecutar(
    Future<void> Function() accion,
    String mensaje,
  ) async {
    setState(() => _cargando = true);

    try {
      await accion();
      await _leerDatos();

      if (mounted) {
        _mostrarMensaje(mensaje, false);
      }
    } catch (e) {
      if (mounted) {
        _mostrarMensaje('Error de SQLite: $e', true);
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  // FORMULARIO DE NODOS
  Future<Map<String, String>?> _formularioNodo({
    Map<String, dynamic>? nodo,
  }) async {
    final formKey = GlobalKey<FormState>();

    String nombre = nodo?['nombre']?.toString() ?? '';
    String ubicacion = nodo?['ubicacion']?.toString() ?? '';

    return showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            nodo == null ? 'Registrar nodo' : 'Editar nodo',
          ),
          content: SizedBox(
            width: 350,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: nombre,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del nodo',
                      hintText: 'ESP32_01',
                      prefixIcon: Icon(Icons.memory),
                    ),
                    onChanged: (valor) => nombre = valor,
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa un nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    initialValue: ubicacion,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación',
                      hintText: 'Rack A',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    onChanged: (valor) => ubicacion = valor,
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa una ubicación';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, {
                    'nombre': nombre.trim(),
                    'ubicacion': ubicacion.trim(),
                  });
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // CREATE - REGISTRAR NODO
  Future<void> _agregarNodo() async {
    final datos = await _formularioNodo();

    if (datos == null || !mounted) return;

    await _ejecutar(() async {
      await _db.insertarNodo(
        datos['nombre']!,
        datos['ubicacion']!,
      );
    }, 'Nodo registrado correctamente');
  }

  // UPDATE - MODIFICAR NODO
  Future<void> _editarNodo(Map<String, dynamic> nodo) async {
    final datos = await _formularioNodo(nodo: nodo);

    if (datos == null || !mounted) return;

    await _ejecutar(() async {
      await _db.actualizarNodo(
        nodo['id'] as int,
        datos['nombre']!,
        datos['ubicacion']!,
      );
    }, 'Nodo actualizado correctamente');
  }

  // DELETE - ELIMINAR NODO
  Future<void> _eliminarNodo(Map<String, dynamic> nodo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar nodo'),
          content: Text(
            '¿Eliminar ${nodo['nombre']}?\n'
            'También se eliminarán sus lecturas asociadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    await _ejecutar(() async {
      await _db.eliminarNodo(nodo['id'] as int);
    }, 'Nodo eliminado correctamente');
  }

  // INSERCION MASIVA - TRANSACCION ACID
  Future<void> _insertarLote() async {
    if (_nodos.isEmpty) {
      _mostrarMensaje(
        'Primero registra un nodo ESP32',
        true,
      );
      return;
    }

    final nodeId = _nodos.first['id'] as int;
    final ahora = DateTime.now();

    final lecturas = List.generate(100, (indice) {
      final temperatura = 20.0 + (indice % 30) * 0.5;

      return SensorReading(
        nodeId: nodeId,
        sensorType: 'temperature',
        value: temperatura,
        timestamp: ahora
            .subtract(Duration(seconds: 100 - indice))
            .toIso8601String(),
      );
    });

    await _ejecutar(() async {
      await _db.insertarLecturasEnLote(lecturas);
    }, '100 lecturas guardadas mediante transacción ACID');
  }

  // ======================================
  // NUEVO - SINCRONIZAR SQLITE CON MYSQL
  // ======================================

  Future<void> _sincronizarMySQL() async {
    if (_ocupado) return;

    if (_lecturas.isEmpty) {
      _mostrarMensaje(
        'No hay lecturas para enviar',
        true,
      );
      return;
    }

    setState(() {
      _sincronizando = true;
      _resultadoSync = 'Enviando lecturas a MySQL...';
    });

    try {
      final total =
          await _mysqlService.sincronizarLecturas();

      if (!mounted) return;

      setState(() {
        _resultadoSync =
            '$total lecturas procesadas por la API MySQL';
      });

      _mostrarMensaje(
        'Sincronización completada: $total lecturas enviadas',
        false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _resultadoSync = 'Error de sincronización: $e';
      });

      _mostrarMensaje(
        'No se pudo sincronizar: $e',
        true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sincronizando = false;
        });
      }
    }
  }

  // ======================================
  // INTERFAZ
  // ======================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRUD SQLite - IoT'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualizar registros',
            onPressed: _ocupado ? null : _refrescar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),

                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Icon(
                      Icons.storage,
                      size: 70,
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      'Administración de Nodos IoT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // CONTADORES SQLITE
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              'Nodos registrados: ${_nodos.length}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lecturas almacenadas: ${_lecturas.length}',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // BOTON REGISTRAR
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _agregarNodo,
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar nodo ESP32'),
                    ),

                    const SizedBox(height: 15),

                    // BOTON TRANSACCION ACID
                    OutlinedButton.icon(
                      onPressed: _ocupado ? null : _insertarLote,
                      icon: const Icon(Icons.library_add),
                      label: const Text(
                        'Insertar 100 lecturas (Transacción ACID)',
                      ),
                    ),

                    const SizedBox(height: 20),

                    // NUEVO BOTON MYSQL
                    FilledButton.icon(
                      onPressed: _ocupado
                          ? null
                          : _sincronizarMySQL,
                      icon: const Icon(Icons.cloud_upload),
                      label: Text(
                        _sincronizando
                            ? 'Sincronizando...'
                            : 'Enviar lecturas a MySQL',
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_sincronizando)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),

                    const SizedBox(height: 12),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.cloud_done,
                              size: 35,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Sincronización SQLite → MySQL',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _resultadoSync,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'Nodos registrados',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_nodos.isEmpty)
                      const Card(
                        child: ListTile(
                          title: Text('No hay nodos registrados'),
                          subtitle: Text(
                            'Presiona Registrar nodo ESP32.',
                          ),
                        ),
                      ),

                    // LISTA DE NODOS
                    ..._nodos.map((nodo) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.memory,
                            color: Colors.blue,
                          ),
                          title: Text(nodo['nombre'].toString()),
                          subtitle: Text(
                            'ID: ${nodo['id']}\n'
                            'Ubicación: ${nodo['ubicacion']}',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: _ocupado
                                    ? null
                                    : () => _editarNodo(nodo),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: _ocupado
                                    ? null
                                    : () => _eliminarNodo(nodo),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 30),

                    const Text(
                      'Últimas lecturas registradas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_lecturas.isEmpty)
                      const Text(
                        'Aún no hay lecturas almacenadas.',
                      ),

                    // MOSTRAR LAS ULTIMAS 8 LECTURAS
                    ..._lecturas.take(8).map((lectura) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.thermostat,
                            color: Colors.deepOrange,
                          ),
                          title: Text(
                            '${lectura.value.toStringAsFixed(2)} °C',
                          ),
                          subtitle: Text(
                            'Nodo: ${lectura.nodeId}\n'
                            '${lectura.timestamp}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}
