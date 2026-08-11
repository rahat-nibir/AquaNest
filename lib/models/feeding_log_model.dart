import 'package:cloud_firestore/cloud_firestore.dart';

/// A single record of a feeding event actually happening (or failing to).
/// Firestore path: aquariums/{aquariumId}/feedingHistory/{entryId}
///
/// Distinct from the `commands` subcollection: a command is a *request*
/// ("feed now, please") that the hub picks up and executes; a
/// FeedingLogEntry is the *result* the hub reports back after acting on
/// either a command or its own schedule. UI should read from here to show
/// what actually happened, not from `commands`.
class FeedingLogEntry {
  final String id;
  final DateTime feedAt;
  final String status; // 'completed' | 'missed'
  final String source; // 'manual' | 'scheduled'

  FeedingLogEntry({
    required this.id,
    required this.feedAt,
    required this.status,
    required this.source,
  });

  bool get isMissed => status == 'missed';

  factory FeedingLogEntry.fromFirestore(String id, Map<String, dynamic> data) {
    return FeedingLogEntry(
      id: id,
      feedAt: (data['feedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'completed',
      source: data['source'] ?? 'scheduled',
    );
  }
}
