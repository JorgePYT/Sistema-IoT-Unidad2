
import 'package:sqflite/sqflite.dart';

// ACTIVIDAD 1 - UNIDAD 2
// Ejercicio: Corrección de vulnerabilidad SQL Injection

class CorreccionSQL {

  // CÓDIGO ORIGINAL VULNERABLE
  //
  // void saveUserData(String userInput) {
  //   db.rawQuery(
  //     "INSERT INTO users VALUES ('" + userInput + "')"
  //   );
  // }
  //
  // PROBLEMA:
  // El código concatena directamente los datos
  // del usuario dentro de una sentencia SQL.
  //
  // Un atacante podría introducir código SQL
  // malicioso y modificar la consulta original.


  // CÓDIGO CORREGIDO
  // Utiliza consultas parametrizadas mediante db.insert()

  Future<int> saveUserData(
    Database db,
    String userInput,
  ) async {

    try {

      // Inserción segura de datos
      final resultado = await db.insert(
        'users',
        {
          'nombre': userInput,
        },
      );

      return resultado;

    } catch (e) {

      print('Error al guardar usuario: $e');

      rethrow;
    }
  }
}
