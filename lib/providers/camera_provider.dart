import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/esp32cam_service.dart';
import '../services/firebase_service.dart';

class CameraProvider extends ChangeNotifier {
  final Esp32CamService _camService;
  final FirebaseService _firebaseService;
  final String aquariumId;

  CameraProvider({
    required Esp32CamService camService,
    required FirebaseService firebaseService,
    required this.aquariumId,
  })  : _camService = camService,
        _firebaseService = firebaseService {
    _sub = _camService.frames.listen((frame) {
      _latestFrame = frame;
      notifyListeners();
    }, onError: (e) {
      _streamError = e.toString();
      _isLive = false;
      notifyListeners();
    });

    _snapshotSub =
        _firebaseService.watchSnapshots(aquariumId).listen((snapshots) {
      _recentSnapshots = snapshots;
      notifyListeners();
    });
  }

  Uint8List? _latestFrame;
  Uint8List? get latestFrame => _latestFrame;

  bool _isLive = false;
  bool get isLive => _isLive;

  String? _streamError;
  String? get streamError => _streamError;

  List<Map<String, dynamic>> _recentSnapshots = [];
  List<Map<String, dynamic>> get recentSnapshots => _recentSnapshots;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  StreamSubscription? _sub;
  StreamSubscription? _snapshotSub;

  Future<void> connect(String streamUrl) async {
    try {
      await _camService.connect(streamUrl);
      _isLive = true;
      _streamError = null;
      notifyListeners();
    } catch (e) {
      _isLive = false;
      _streamError = e.toString();
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _camService.disconnect();
    _isLive = false;
    notifyListeners();
  }

  /// Uploads the most recently received MJPEG frame to Firebase Storage
  /// and logs it in Firestore so it appears in the gallery in real time
  /// on every device signed into this aquarium — not just a local counter.
  Future<void> saveSnapshot() async {
    if (_latestFrame == null) {
      throw Exception('No live frame available yet — wait for the stream to connect.');
    }

    _isSaving = true;
    notifyListeners();

    try {
      final fileName =
          'snapshots/$aquariumId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref(fileName);
      await ref.putData(
        _latestFrame!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await _firebaseService.logSnapshot(aquariumId, url);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _snapshotSub?.cancel();
    _camService.dispose();
    super.dispose();
  }
}
