class SensorData {
  final double temperature;
  final double waterLevel;
  final double foodLevel;
  final bool isPumpOn;
  final bool isFeederActive;

  SensorData({
    required this.temperature,
    required this.waterLevel,
    required this.foodLevel,
    required this.isPumpOn,
    required this.isFeederActive,
  });

  factory SensorData.fromMap(Map<dynamic, dynamic> map) {
    return SensorData(
      temperature: (map['temperature'] ?? 0.0).toDouble(),
      waterLevel: (map['water_level'] ?? 0.0).toDouble(),
      foodLevel: (map['food_level'] ?? 0.0).toDouble(),
      isPumpOn: map['pump_status'] ?? false,
      isFeederActive: map['feeder_status'] ?? false,
    );
  }
}