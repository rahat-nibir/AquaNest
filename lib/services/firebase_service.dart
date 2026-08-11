import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/aquarium_model.dart';
import '../models/schedule_model.dart';
import '../models/feeding_log_model.dart';

/// Thin wrapper around Firebase so providers never talk to
/// FirebaseFirestore/FirebaseAuth directly. Makes it trivial to
/// mock in tests and keeps Firestore document paths in one place.
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------- Auth ----------

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    await _auth.currentUser?.reload();
  }

  // ---------- Aquarium status ----------

  /// Live listener on aquariums/{aquariumId}. UI rebuilds automatically
  /// whenever the ESP32 hub pushes a new reading to Firestore.
  Stream<AquariumModel> watchAquarium(String aquariumId) {
    return _db.collection('aquariums').doc(aquariumId).snapshots().map(
          (doc) => doc.exists
              ? AquariumModel.fromFirestore(doc.id, doc.data()!)
              : AquariumModel.empty(),
        );
  }

  Future<void> setHubOnline(String aquariumId, bool online) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .set({'hubOnline': online}, SetOptions(merge: true));
  }

  // ---------- Feeding ----------

  /// Requests an immediate feed. Uses the existing command pattern
  /// (aquariums/{id}/commands, type: feed_now, status: pending) rather
  /// than a boolean flag on the aquarium doc, so there's exactly one
  /// mechanism for triggering a feed and no ambiguity about which write
  /// the hub should treat as the source of truth.
  Future<void> sendFeedCommand(String aquariumId) {
    return _db.collection('aquariums').doc(aquariumId).collection('commands').add({
      'type': 'feed_now',
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  /// What actually happened, as reported back by the hub — separate from
  /// the request in `commands`. Ordered newest-first.
  Stream<List<FeedingLogEntry>> watchFeedingHistory(String aquariumId,
      {int limit = 20}) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .collection('feedingHistory')
        .orderBy('feedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FeedingLogEntry.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Clears the missed-feedings badge once the human has seen it. Only
  /// resets the counter — the individual 'missed' entries stay in
  /// feedingHistory as a permanent record.
  Future<void> acknowledgeMissedFeedings(String aquariumId) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .set({'missedFeedingsCount': 0}, SetOptions(merge: true));
  }

  // ---------- Maintenance ----------

  /// Logs a water change as done right now. This is a human-reported
  /// event (no sensor for it), so it's a simple timestamp write rather
  /// than anything the hub confirms.
  Future<void> recordWaterChange(String aquariumId) {
    return _db.collection('aquariums').doc(aquariumId).set(
      {'lastWaterChangeAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ---------- Hardware controls (light / pump relays) ----------

  /// Writes the app's requested light state. The hub is expected to be
  /// listening on this same aquarium doc and to actually flip its relay
  /// to match — this write is the request, not proof the light changed.
  /// isLightOn in the UI reflects whatever the hub last confirmed back,
  /// once it echoes the field, so a relay fault won't silently show as
  /// "on" forever.
  Future<void> setLight(String aquariumId, bool on) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .set({'isLightOn': on}, SetOptions(merge: true));
  }

  Future<void> setPump(String aquariumId, bool on) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .set({'isPumpOn': on}, SetOptions(merge: true));
  }

  // ---------- Schedules ----------

  Stream<List<ScheduleModel>> watchSchedules(String aquariumId) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .collection('schedules')
        .orderBy('time')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ScheduleModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  Future<void> addSchedule(String aquariumId, ScheduleModel schedule) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .collection('schedules')
        .add(schedule.toMap());
  }

  Future<void> setScheduleActive(
      String aquariumId, String scheduleId, bool isActive) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .collection('schedules')
        .doc(scheduleId)
        .update({'isActive': isActive});
  }

  // ---------- Snapshots (camera) ----------

  /// Records a snapshot event; the actual JPEG is expected to already be
  /// pushed to the ESP32-CAM's SD card or a storage bucket by the device,
  /// this just logs metadata so the gallery/log can reflect it live.
  Future<void> logSnapshot(String aquariumId, String storageUrl) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .collection('snapshots')
        .add({
      'url': storageUrl,
      'takenAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchSnapshots(String aquariumId) {
    return _db
        .collection('aquariums')
        .doc(aquariumId)
        .collection('snapshots')
        .orderBy('takenAt', descending: true)
        .limit(9)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}
