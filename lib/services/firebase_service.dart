import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/aquarium_model.dart';
import '../models/schedule_model.dart';

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
