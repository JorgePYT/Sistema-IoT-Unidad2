
class SensorReading {
  // Identificador único de la lectura
  final int? id;

  // Identificador del nodo IoT
  final int nodeId;

  // Tipo de sensor: temperatura, humedad, etc.
  final String sensorType;

  // Valor registrado por el sensor
  final double value;

  // Fecha y hora de la lectura
  final String timestamp;

  // Constructor
  SensorReading({
    this.id,
    required this.nodeId,
    required this.sensorType,
    required this.value,
    required this.timestamp,
  });

  // Convertir un objeto en un mapa para SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'node_id': nodeId,
      'sensorType': sensorType,
      'value': value,
      'timestamp': timestamp,
    };
  }

  // Convertir los datos de SQLite en un objeto
  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      id: map['id'] as int?,
      nodeId: map['node_id'] as int,
      sensorType: map['sensorType'] as String,
      value: (map['value'] as num).toDouble(),
      timestamp: map['timestamp'] as String,
    );
  }
}
