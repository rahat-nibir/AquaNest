import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/sensor_data.dart';

class AquariumProvider with ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  SensorData _sensorData = SensorData(
    temperature: 0.0,
    waterLevel: 0.0,
    foodLevel: 0.0,
    isPumpOn: false,
    isFeederActive: false,
  );

  SensorData get sensorData => _sensorData;

  AquariumProvider() {
    _listenToSensorData();
  }

  void _listenToSensorData() {
    _dbRef.child('aquarium_status').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        _sensorData = SensorData.fromMap(data);
        notifyListeners();
      }
    });
  }

  Future<void> togglePump(bool value) async {
    await _dbRef.child('aquarium_status/pump_status').set(value);
  }

  Future<void> triggerFeeder() async {
    await _dbRef.child('aquarium_status/feeder_status').set(true);
    // Servo trigger reset
    Future.delayed(const Duration(seconds: 3), () async {
      await _dbRef.child('aquarium_status/feeder_status').set(false);
    });
  }
}
