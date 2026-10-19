
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

import '../services/csv_node_manager.dart';

class CsvNodesScreen extends StatefulWidget {
  const CsvNodesScreen({super.key});

  @override
  State<CsvNodesScreen> createState() =>
      _CsvNodesScreenState();
}

class _CsvNodesScreenState extends State<CsvNodesScreen> {
  final CsvNodeManager _manager = CsvNodeManager();

  bool _cargando = false;
  bool? _archivoValido;

  String _mensaje = 'Esperando operación...';
  String _rutaArchivo = '';

  List<Map<String, dynamic>> _nodosImportados = [];

  // Nodos de ejemplo para la práctica
  final List<Map<String, dynamic>> _nodos = [
    {
      'id': 1,
      'nombre': 'ESP32_01',
      'ubicacion': 'Rack A',
    },
    {
      'id': 2,
      'nombre': 'ESP32_02',
      'ubicacion': 'Rack B',
    },
    {
      'id': 3,
      'nombre': 'ESP32_03',
      'ubicacion': 'Rack C',
    },
  ];

  // EXPORTAR NODOS
  Future<void> _exportar() async {
    setState(() {
      _cargando = true;
    });

    try {
      final ruta = await _manager.exportarNodos(_nodos);

      if (!mounted) return;

      setState(() {
        _rutaArchivo = ruta;
        _archivoValido = null;
        _mensaje = 'Nodos exportados correctamente.';
      });

      _mostrarMensaje(
        'Archivo CSV generado',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _mensaje = 'Error al exportar: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  // IMPORTAR NODOS
  Future<void> _importar() async {
    setState(() {
      _cargando = true;
    });

    try {
      final nodos = await _manager.importarNodos();

      if (!mounted) return;

      setState(() {
        _nodosImportados = nodos;
        _archivoValido = true;
        _mensaje = 'Archivo válido. '
            '${nodos.length} nodos importados.';
      });

      _mostrarMensaje(
        'Integridad SHA-256 correcta',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _archivoValido = false;
        _mensaje = 'Importación rechazada: $e';
      });

      _mostrarMensaje(
        'Archivo inválido',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  // PROBAR DETECCIÓN DE ARCHIVO ALTERADO
  Future<void> _probarCorrupcion() async {
    setState(() {
      _cargando = true;
    });

    try {
      final original = await _manager.obtenerArchivo();

      if (!await original.exists()) {
        throw Exception(
          'Primero debes exportar el archivo CSV',
        );
      }

      // Crear una copia alterada sin modificar
      // el archivo CSV original.
      final copia = File(
        '${original.path}.alterado.csv',
      );

      final contenido = await original.readAsString();

      // Alterar el contenido sin actualizar el SHA-256
      await copia.writeAsString(
        '$contenido\nDATOS_MODIFICADOS',
        flush: true,
      );

      final textoAlterado = await copia.readAsString();

      final salto = textoAlterado.indexOf('\n');

      if (salto < 0) {
        throw const FormatException(
          'Archivo inválido',
        );
      }

      final checksumOriginal = textoAlterado
          .substring(0, salto)
          .replaceFirst('# CHECKSUM:', '')
          .trim();

      final cuerpo = textoAlterado.substring(salto + 1);

      final checksumActual = sha256
          .convert(utf8.encode(cuerpo))
          .toString();

      final esValido =
          checksumOriginal == checksumActual;

      if (!mounted) return;

      setState(() {
        _archivoValido = esValido;
        _mensaje = esValido
            ? 'Archivo válido'
            : 'Archivo alterado detectado: '
                'SHA-256 no coincide.';
      });

      _mostrarMensaje(
        esValido
            ? 'Archivo válido'
            : 'Se detectó un archivo corrupto',
        esValido ? Colors.green : Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _mensaje = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  void _mostrarMensaje(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nodos IoT - CSV'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.sensors,
              size: 75,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'Exportación e Importación de Nodos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: _cargando ? null : _exportar,
              icon: const Icon(Icons.upload_file),
              label: const Text('Exportar Nodos CSV'),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: _cargando ? null : _importar,
              icon: const Icon(Icons.download),
              label: const Text('Importar Nodos CSV'),
            ),

            const SizedBox(height: 15),

            OutlinedButton.icon(
              onPressed: _cargando
                  ? null
                  : _probarCorrupcion,
              icon: const Icon(Icons.warning),
              label: const Text(
                'Probar Archivo Corrupto',
              ),
            ),

            const SizedBox(height: 30),

            if (_cargando)
              const Center(
                child: CircularProgressIndicator(),
              ),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _archivoValido == null
                          ? Icons.help_outline
                          : _archivoValido!
                              ? Icons.check_circle
                              : Icons.cancel,
                      size: 65,
                      color: _archivoValido == null
                          ? Colors.grey
                          : _archivoValido!
                              ? Colors.green
                              : Colors.red,
                    ),

                    const SizedBox(height: 15),

                    Text(
                      _mensaje,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_rutaArchivo.isNotEmpty)
              SelectableText(
                'Archivo guardado en:\n$_rutaArchivo',
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 25),

            const Text(
              'Nodos importados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ..._nodosImportados.map(
              (nodo) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.memory,
                    color: Colors.blue,
                  ),
                  title: Text(
                    nodo['nombre'].toString(),
                  ),
                  subtitle: Text(
                    'Ubicación: ${nodo['ubicacion']}',
                  ),
                  trailing: Text(
                    'ID: ${nodo['id']}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
