
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/preferencias_storage.dart';

class PreferenciasScreen extends StatefulWidget {
  const PreferenciasScreen({super.key});

  @override
  State<PreferenciasScreen> createState() =>
      _PreferenciasScreenState();
}

class _PreferenciasScreenState extends State<PreferenciasScreen> {

  final PreferenciasStorage _storage = PreferenciasStorage();

  final TextEditingController _intervaloController =
      TextEditingController(text: '5');

  bool _temaOscuro = false;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  // Cargar las preferencias desde JSON
  Future<void> _cargarPreferencias() async {
    try {
      final datos = await _storage.leerPreferencias();

      if (!mounted) return;

      if (datos != null) {
        setState(() {
          _temaOscuro = datos['tema_oscuro'] == true;

          _intervaloController.text =
              (datos['intervalo_muestreo'] ?? 5).toString();
        });
      }

    } on FileSystemException catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al leer el archivo: ${e.message}',
        Colors.red,
      );

    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al cargar preferencias: $e',
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

  // Guardar preferencias en JSON local
  Future<void> _guardarPreferencias() async {

    final intervalo = int.tryParse(
      _intervaloController.text.trim(),
    );

    if (intervalo == null || intervalo <= 0) {
      _mostrarMensaje(
        'Ingresa un intervalo válido mayor a 0',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      await _storage.guardarPreferencias(
        temaOscuro: _temaOscuro,
        intervaloMuestreo: intervalo,
      );

      if (!mounted) return;

      _mostrarMensaje(
        'Preferencias guardadas correctamente',
        Colors.green,
      );

    } on FileSystemException catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al guardar el archivo: ${e.message}',
        Colors.red,
      );

    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error inesperado: $e',
        Colors.red,
      );

    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // Mostrar notificaciones SnackBar
  void _mostrarMensaje(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _intervaloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _temaOscuro
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData.light(useMaterial3: true),

      child: Scaffold(
        appBar: AppBar(
          title: const Text('Preferencias IoT'),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),

        body: _cargando
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    const SizedBox(height: 20),

                    const Icon(
                      Icons.settings,
                      size: 80,
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Configuración de Sensores IoT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Almacenamiento local mediante JSON',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // Configuración del tema
                    Card(
                      elevation: 3,
                      child: SwitchListTile(
                        title: const Text('Tema oscuro'),
                        subtitle: const Text(
                          'Activar o desactivar el modo oscuro',
                        ),
                        secondary: const Icon(Icons.dark_mode),
                        value: _temaOscuro,

                        onChanged: (valor) {
                          setState(() {
                            _temaOscuro = valor;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Intervalo de muestreo
                    TextField(
                      controller: _intervaloController,
                      keyboardType: TextInputType.number,

                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],

                      decoration: const InputDecoration(
                        labelText: 'Intervalo de muestreo',
                        hintText: 'Ejemplo: 5',
                        suffixText: 'segundos',
                        prefixIcon: Icon(Icons.timer),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Botón guardar
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _guardando
                            ? null
                            : _guardarPreferencias,

                        icon: const Icon(Icons.save),

                        label: Text(
                          _guardando
                              ? 'Guardando...'
                              : 'Guardar preferencias',
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.storage,
                              color: Colors.blue,
                              size: 35,
                            ),

                            SizedBox(height: 10),

                            Text(
                              'Almacenamiento local JSON',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 8),

                            Text(
                              'Las preferencias se guardan '
                              'en el dispositivo y pueden '
                              'recuperarse al abrir la aplicación.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
