import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the live state of one physical aquarium hub, as synced
/// from Firestore document: aquariums/{aquariumId}
class AquariumModel {
  final String id;
  final String name;
  final double temperatureC;
  final String status; // e.g. "Stable", "Warning", "Critical"
  final bool hubOnline;
  final DateTime? lastFedAt;
  final String esp32StreamUrl; // e.g. http://192.168.1.42:81/stream

  /// 0–100. Null means the device has never reported this field —
  /// different from 0, which is a real "tank is empty" reading. No
  /// current ESP32 firmware writes these yet (only DS18B20 temperature
  /// is wired up), so expect null/— in the UI until that hardware
  /// exists.
  final double? waterLevel;
  final double? foodLevel;

  /// False only when the Firestore document itself doesn't exist yet
  /// (no device has ever been paired/provisioned). Different from
  /// hubOnline=false, which means the doc exists but the device hasn't
  /// sent a heartbeat recently — in that case the other fields still
  /// hold the last real reading, not zeros.
  final bool exists;

  AquariumModel({
    required this.id,
    required this.name,
    required this.temperatureC,
    required this.status,
    required this.hubOnline,
    required this.lastFedAt,
    required this.esp32StreamUrl,
    this.waterLevel,
    this.foodLevel,
    this.exists = true,
  });

  factory AquariumModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AquariumModel(
      id: id,
      name: data['name'] ?? 'Unnamed Aquarium',
      temperatureC: (data['temperatureC'] ?? 0).toDouble(),
      status: data['status'] ?? 'Unknown',
      hubOnline: data['hubOnline'] ?? false,
      lastFedAt: (data['lastFedAt'] as Timestamp?)?.toDate(),
      esp32StreamUrl: data['esp32StreamUrl'] ?? '',
      waterLevel: (data['waterLevel'] as num?)?.toDouble(),
      foodLevel: (data['foodLevel'] as num?)?.toDouble(),
      exists: true,
    );
  }

  /// Used both before the first Firestore snapshot arrives AND when the
  /// document genuinely doesn't exist. Check AquariumProvider.isLoading
  /// vs. aquarium.exists in the UI to tell those two cases apart.
  factory AquariumModel.empty() {
    return AquariumModel(
      id: '',
      name: 'No Device Paired',
      temperatureC: 0,
      status: 'Not set up',
      hubOnline: false,
      lastFedAt: null,
      esp32StreamUrl: '',
      waterLevel: null,
      foodLevel: null,
      exists: false,
    );
  }
}
