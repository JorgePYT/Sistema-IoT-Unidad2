

import 'dart:io';

import 'package:flutter/material.dart';
import '../services/csv_log_service.dart';

class CsvLogScreen extends StatefulWidget {
  const CsvLogScreen({super.key});

  @override
  State<CsvLogScreen> createState() => _CsvLogScreenState();
}

class _CsvLogScreenState extends State<CsvLogScreen> {

  final CsvLogService _csvService = CsvLogService();

  bool _cargando = false;
  bool? _archivoValido;

  String _mensaje = 'No se ha validado ningún archivo.';
  String _rutaArchivo = '';

  // Generar 100 lecturas de sensores
  Future<void> _generarLog() async {

    setState(() {
      _cargando = true;
      _archivoValido = null;
      _mensaje = 'Generando lecturas...';
    });

    try {

      final ruta = await _csvService.generarLogSensores();

      if (!mounted) return;

      setState(() {
        _rutaArchivo = ruta;
        _mensaje = 'Se generaron 100 lecturas correctamente.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Archivo CSV generado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

    } on FileSystemException catch (e) {

      if (!mounted) return;

      setState(() {
        _mensaje = 'Error al generar archivo: ${e.message}';
      });

    } catch (e) {

      if (!mounted) return;

      setState(() {
        _mensaje = 'Error inesperado: $e';
      });

    } finally {

      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  // Validar la integridad mediante SHA-256
  Future<void> _validarLog() async {

    setState(() {
      _cargando = true;
      _mensaje = 'Validando integridad...';
    });

    try {

      final valido = await _csvService.validarIntegridad();

      if (!mounted) return;

      setState(() {
        _archivoValido = valido;

        if (valido) {
          _mensaje = 'Archivo válido: SHA-256 correcto.';
        } else {
          _mensaje = 'Archivo corrupto, modificado o inexistente.';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensaje),
          backgroundColor:
              valido ? Colors.green : Colors.red,
        ),
      );

    } catch (e) {

      if (!mounted) return;

      setState(() {
        _archivoValido = false;
        _mensaje = 'Error de validación: $e';
      });

    } finally {

      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('Registro CSV de Sensores'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            const SizedBox(height: 20),

            const Icon(
              Icons.thermostat,
              size: 85,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'Monitoreo de Temperatura IoT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Generación de 100 lecturas simuladas '
              'y validación SHA-256',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 35),

            // Primer botón: generar CSV
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _cargando ? null : _generarLog,
                icon: const Icon(Icons.file_copy),
                label: const Text(
                  'Generar Log de Sensores (CSV)',
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Segundo botón: validar CSV
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _cargando ? null : _validarLog,
                icon: const Icon(Icons.verified_user),
                label: const Text(
                  'Validar Integridad Log',
                ),
              ),
            ),

            const SizedBox(height: 35),

            if (_cargando)
              const Center(
                child: CircularProgressIndicator(),
              ),

            const SizedBox(height: 20),

            // Mostrar el resultado de la validación
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(25),

                child: Column(
                  children: [

                    Icon(
                      _archivoValido == null
                          ? Icons.help_outline
                          : _archivoValido!
                              ? Icons.check_circle
                              : Icons.cancel,

                      size: 80,

                      color: _archivoValido == null
                          ? Colors.grey
                          : _archivoValido!
                              ? Colors.green
                              : Colors.red,
                    ),

                    const SizedBox(height: 15),

                    Text(
                      _archivoValido == null
                          ? 'Sin validar'
                          : _archivoValido!
                              ? 'VÁLIDO'
                              : 'CORRUPTO',

                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _mensaje,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Mostrar la ubicación del CSV
            if (_rutaArchivo.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    children: [

                      const Icon(
                        Icons.folder,
                        color: Colors.blue,
                        size: 35,
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Ubicación del archivo CSV',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      SelectableText(
                        _rutaArchivo,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
