import 'package:cloud_firestore/cloud_firestore.dart';

/// A single feeding cycle entry.
/// Firestore path: aquariums/{aquariumId}/schedules/{scheduleId}
class ScheduleModel {
  final String id;
  final String time; // formatted, e.g. "08:00 AM"
  final String subtitle; // e.g. "Every day · Standard portion"
  final bool isActive;

  ScheduleModel({
    required this.id,
    required this.time,
    required this.subtitle,
    required this.isActive,
  });

  factory ScheduleModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ScheduleModel(
      id: id,
      time: data['time'] ?? '',
      subtitle: data['subtitle'] ?? '',
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'time': time,
        'subtitle': subtitle,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
      };

  ScheduleModel copyWith({bool? isActive}) => ScheduleModel(
        id: id,
        time: time,
        subtitle: subtitle,
        isActive: isActive ?? this.isActive,
      );
}
