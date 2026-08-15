import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/aquarium_ai_analysis.dart';
import '../services/esp32cam_service.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

/// How often a live frame is silently sent to Gemini for a health read.
/// 15–20s is frequent enough to catch a developing issue during a demo
/// without burning through API quota or reanalyzing a near-identical
/// frame every few seconds.
const _kAnalysisInterval = Duration(seconds: 18);

class CameraProvider extends ChangeNotifier {
  final Esp32CamService _camService;
  final FirebaseService _firebaseService;
  final GeminiService? _geminiService;
  final NotificationService? _notificationService;
  final SettingsProvider? _settingsProvider;
  final String aquariumId;

  CameraProvider({
    required Esp32CamService camService,
    required FirebaseService firebaseService,
    required this.aquariumId,
    GeminiService? geminiService,
    NotificationService? notificationService,
    SettingsProvider? settingsProvider,
  })  : _camService = camService,
        _firebaseService = firebaseService,
        _geminiService = geminiService,
        _notificationService = notificationService,
        _settingsProvider = settingsProvider {
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

  // --- Real-time AI health monitor ("traffic signal") ---
  AquariumAiAnalysis? _aiAnalysis;
  AquariumAiAnalysis? get aiAnalysis => _aiAnalysis;
  AiHealthStatus get aiStatus => _aiAnalysis?.status ?? AiHealthStatus.unknown;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;
  bool _criticalAlertSent = false;

  Timer? _analysisTimer;
  StreamSubscription? _sub;
  StreamSubscription? _snapshotSub;

  Future<void> connect(String streamUrl) async {
    try {
      await _camService.connect(streamUrl);
      _isLive = true;
      _streamError = null;
      notifyListeners();
      _startMonitoring();
    } catch (e) {
      _isLive = false;
      _streamError = e.toString();
      notifyListeners();
    }
  }

  /// Starts the background frame-analysis timer. A no-op if no
  /// GeminiService was wired in (e.g. missing API key) — the traffic
  /// badge just stays on "unknown" rather than erroring.
  void _startMonitoring() {
    _analysisTimer?.cancel();
    if (_geminiService == null) return;
    _analysisTimer = Timer.periodic(_kAnalysisInterval, (_) => _analyzeFrame());
  }

  Future<void> _analyzeFrame() async {
    final frame = _latestFrame;
    final gemini = _geminiService;
    if (frame == null || gemini == null || _isAnalyzing || !_isLive) return;

    _isAnalyzing = true;
    try {
      final result = await gemini.analyzeAquariumFrame(frame);
      _aiAnalysis = result;
      notifyListeners();

      final alertsOn = _settingsProvider?.proactiveAlertsEnabled ?? true;
      if (result.status == AiHealthStatus.critical) {
        // Only fire once per critical episode, not every 18s while it
        // stays critical — the alert already told the user; nagging
        // them every cycle isn't "proactive", it's noise.
        if (!_criticalAlertSent && alertsOn) {
          _criticalAlertSent = true;
          await _notificationService?.show(
            title: '🔴 Critical: Fish health alert',
            body: result.summary ??
                'The camera AI flagged a possible health issue — check the live feed.',
            channelId: 'critical_alerts',
            channelName: 'Critical Alerts',
          );
        }
      } else {
        _criticalAlertSent = false;
      }
    } catch (e) {
      // Analysis happens silently by design — a transient failure here
      // shouldn't surface as a user-facing error; the live feed itself
      // is completely unaffected either way.
      debugPrint('[CameraProvider] frame analysis failed: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  Future<void> disconnect() async {
    _analysisTimer?.cancel();
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
    _analysisTimer?.cancel();
    _sub?.cancel();
    _snapshotSub?.cancel();
    _camService.dispose();
    super.dispose();
  }
}
