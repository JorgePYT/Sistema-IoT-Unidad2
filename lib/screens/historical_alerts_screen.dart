
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/sensor_reading.dart';
import '../services/esp32_sync_service.dart';

// ==========================================
// ACTIVIDAD 3 - UNIDAD 2
// HISTORICO Y ALERTAS IoT
// SINCRONIZACION ESP32 - MYSQL - SQLITE
// INTERFAZ RESPONSIVA SIN OVERFLOW
// ==========================================

// MODELO PARA EL HISTORIAL
class DatosHistorico {
  final List<SensorReading> lecturas;
  final List<Map<String, dynamic>> alertas;

  DatosHistorico({
    required this.lecturas,
    required this.alertas,
  });
}

// PANTALLA PRINCIPAL
class HistoricalAlertsScreen extends StatefulWidget {
  const HistoricalAlertsScreen({super.key});

  @override
  State<HistoricalAlertsScreen> createState() =>
      _HistoricalAlertsScreenState();
}

class _HistoricalAlertsScreenState
    extends State<HistoricalAlertsScreen> {

  // SERVICIOS
  final DatabaseHelper _db = DatabaseHelper.instance;

  final Esp32SyncService _esp32Service =
      Esp32SyncService();

  late Future<DatosHistorico> _historialFuture;

  // ESTADOS
  bool _guardando = false;
  bool _sincronizando = false;
  bool _soloAlertas = false;

  String _estadoSync =
      'Esperando sincronización del ESP32';

  bool get _ocupado => _guardando || _sincronizando;

  // =====================================
  // INICIALIZAR PANTALLA
  // =====================================

  @override
  void initState() {
    super.initState();

    _historialFuture = _cargarHistorial();
  }

  // =====================================
  // CONSULTAR SQLITE
  // =====================================

  Future<DatosHistorico> _cargarHistorial() async {
    final lecturas =
        await _db.obtenerTodasLasLecturas();

    final alertas =
        await _db.obtenerAlertas();

    return DatosHistorico(
      lecturas: lecturas,
      alertas: alertas,
    );
  }

  // ACTUALIZAR HISTORIAL
  void _actualizar() {
    setState(() {
      _historialFuture = _cargarHistorial();
    });
  }

  // =====================================
  // NOTIFICACIONES
  // =====================================

  void _mostrarMensaje(
    String mensaje,
    bool error,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor:
              error ? Colors.red : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // =====================================
  // SIMULAR TEMPERATURA DE 38 °C
  // =====================================

  Future<void> _registrarAlertaPrueba() async {
    if (_ocupado) return;

    setState(() {
      _guardando = true;
    });

    try {
      final nodos = await _db.obtenerNodos();

      if (!mounted) return;

      if (nodos.isEmpty) {
        _mostrarMensaje(
          'Primero registra un nodo en CRUD SQLite',
          true,
        );
        return;
      }

      // OBTENER NODO
      final nodeId = nodos.first['id'] as int;

      // GENERAR LECTURA DE PRUEBA
      final lectura = SensorReading(
        nodeId: nodeId,
        sensorType: 'temperature',
        value: 38.0,
        timestamp:
            DateTime.now().toIso8601String(),
      );

      // GUARDAR EN SQLITE
      // REGISTRA AUTOMATICAMENTE LA ALERTA
      await _db.insertarLectura(lectura);

      if (!mounted) return;

      _actualizar();

      _mostrarMensaje(
        'Temperatura de 38 °C registrada correctamente',
        false,
      );

    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al registrar alerta: $e',
        true,
      );

    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // =====================================
  // SINCRONIZAR ESP32 CON MYSQL
  // =====================================

  Future<void> _sincronizarEsp32() async {
    if (_ocupado) return;

    setState(() {
      _sincronizando = true;
      _estadoSync =
          'Consultando las lecturas del ESP32...';
    });

    try {
      // CONSULTAR API PHP
      final resultado =
          await _esp32Service.sincronizarLecturas();

      if (!mounted) return;

      setState(() {
        _estadoSync =
            'Lecturas recibidas: ${resultado.recibidas}\n'
            'Lecturas nuevas: ${resultado.importadas}\n'
            'Duplicadas: ${resultado.duplicadas}\n'
            'Alertas nuevas: ${resultado.alertasNuevas}';

        // VOLVER A CONSULTAR SQLITE
        _historialFuture = _cargarHistorial();
      });

      _mostrarMensaje(
        'Sincronización completada correctamente',
        false,
      );

    } catch (e) {
      if (!mounted) return;

      setState(() {
        _estadoSync =
            'Error de sincronización: $e';
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

  // =====================================
  // ENCABEZADO DE LA PANTALLA
  // =====================================

  Widget _construirEncabezado({
    required int totalLecturas,
    required int totalAlertas,
    required bool sinResultados,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // BOTON SIMULACION
          FilledButton.icon(
            onPressed:
                _ocupado ? null : _registrarAlertaPrueba,

            icon: const Icon(
              Icons.warning_amber_rounded,
            ),

            label: Text(
              _guardando
                  ? 'Guardando alerta...'
                  : 'Simular temperatura de 38 °C',
            ),

            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // BOTON SINCRONIZAR
          FilledButton.icon(
            onPressed:
                _ocupado ? null : _sincronizarEsp32,

            icon: const Icon(
              Icons.cloud_download,
            ),

            label: Text(
              _sincronizando
                  ? 'Sincronizando ESP32...'
                  : 'Sincronizar ESP32',
            ),

            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
            ),
          ),

          if (_sincronizando) ...[
            const SizedBox(height: 10),

            const Center(
              child: CircularProgressIndicator(),
            ),
          ],

          const SizedBox(height: 10),

          // ESTADO DE SINCRONIZACION
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),

              child: Column(
                children: [

                  const Icon(
                    Icons.sync,
                    color: Colors.blue,
                    size: 28,
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Estado de sincronización ESP32',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _estadoSync,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // RESUMEN DEL HISTORIAL
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
              ),

              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    children: [

                      const Icon(
                        Icons.sensors,
                        size: 42,
                        color: Colors.blue,
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Histórico de Sensores IoT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Lecturas registradas: $totalLecturas',
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Alertas registradas: $totalAlertas',

                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: totalAlertas > 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Umbral de temperatura: 35 °C',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // FILTRO DE ALERTAS
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),

            title: const Text(
              'Mostrar solamente alertas',
            ),

            secondary: const Icon(
              Icons.filter_list,
            ),

            value: _soloAlertas,

            onChanged: (valor) {
              setState(() {
                _soloAlertas = valor;
              });
            },
          ),

          const SizedBox(height: 8),

          const Text(
            'Historial de lecturas',
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          if (sinResultados)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay registros para mostrar.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // =====================================
  // TARJETAS DE LECTURAS
  // =====================================

  Widget _construirLectura({
    required SensorReading lectura,
    required bool esAlerta,
  }) {
    final tipo = lectura.sensorType.toLowerCase();

    final esTemperatura =
        tipo == 'temperature' ||
        tipo == 'temperatura';

    final color =
        esAlerta ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),

      child: ListTile(
        leading: Icon(
          esAlerta
              ? Icons.warning
              : Icons.check_circle,

          color: color,
          size: 34,
        ),

        title: Text(
          '${lectura.sensorType}: '
          '${lectura.value.toStringAsFixed(2)}'
          '${esTemperatura ? ' °C' : ''}',

          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: esAlerta ? Colors.red : null,
          ),
        ),

        subtitle: Text(
          'Nodo: ${lectura.nodeId}\n'
          'Fecha: ${lectura.timestamp}',
        ),

        isThreeLine: true,

        trailing: Text(
          esAlerta ? 'ALERTA' : 'NORMAL',

          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  // =====================================
  // INTERFAZ PRINCIPAL
  // =====================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Histórico y Alertas IoT',
        ),

        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,

        actions: [
          IconButton(
            tooltip: 'Actualizar historial',

            onPressed:
                _ocupado ? null : _actualizar,

            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      // FUTUREBUILDER ASINCRONO
      body: FutureBuilder<DatosHistorico>(
        future: _historialFuture,

        builder: (context, snapshot) {

          // ESTADO DE CARGA
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ESTADO DE ERROR
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Error al consultar SQLite:\n'
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton(
                      onPressed: _actualizar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          // SIN DATOS
          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'No se encontraron datos.',
              ),
            );
          }

          // DATOS OBTENIDOS
          final datos = snapshot.data!;

          final lecturas = datos.lecturas;
          final alertas = datos.alertas;

          // IDENTIFICAR LECTURAS CON ALERTA
          final idsAlertados = alertas
              .map((alerta) =>
                  alerta['reading_id'] as int)
              .toSet();

          // FILTRAR ALERTAS
          final lecturasMostradas = _soloAlertas
              ? lecturas.where((lectura) {
                  return idsAlertados.contains(
                    lectura.id,
                  );
                }).toList()
              : lecturas;

          // ==================================
          // LISTVIEW RESPONSIVO
          // TODO SE DESPLAZA VERTICALMENTE
          // EVITA EL ERROR BOTTOM OVERFLOWED
          // ==================================

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),

              child: ListView.builder(
                padding: const EdgeInsets.only(
                  bottom: 24,
                ),

                itemCount:
                    lecturasMostradas.length + 1,

                itemBuilder: (context, index) {

                  // PRIMER ELEMENTO: ENCABEZADO
                  if (index == 0) {
                    return _construirEncabezado(
                      totalLecturas: lecturas.length,
                      totalAlertas: alertas.length,
                      sinResultados:
                          lecturasMostradas.isEmpty,
                    );
                  }

                  // RESTO: HISTORIAL DE LECTURAS
                  final lectura =
                      lecturasMostradas[index - 1];

                  final esAlerta =
                      idsAlertados.contains(
                        lectura.id,
                      );

                  return _construirLectura(
                    lectura: lectura,
                    esAlerta: esAlerta,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
