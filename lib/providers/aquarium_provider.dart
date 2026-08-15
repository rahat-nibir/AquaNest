import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/aquarium_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

/// Water level at/below this is treated as a critical anomaly worth a
/// push notification, per the "water < 20%" requirement.
const _kLowWaterThreshold = 20.0;

/// Holds the live status of the currently selected aquarium hub.
/// Replaces the hardcoded "Living Room Reef · Stable (26.5°C)" text
/// with a real Firestore subscription. Also owns the proactive-alert
/// detection for missed feedings and critical water level — the two
/// sensor-driven triggers from the spec (the third, AI-camera-detected
/// critical health, lives in CameraProvider next to the frame analysis
/// that produces it).
class AquariumProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final NotificationService? _notificationService;
  final SettingsProvider? _settingsProvider;
  final String aquariumId;

  AquariumProvider({
    required FirebaseService firebaseService,
    required this.aquariumId,
    NotificationService? notificationService,
    SettingsProvider? settingsProvider,
  })  : _firebaseService = firebaseService,
        _notificationService = notificationService,
        _settingsProvider = settingsProvider {
    _subscribe();
  }

  AquariumModel _aquarium = AquariumModel.empty();
  AquariumModel get aquarium => _aquarium;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription<AquariumModel>? _sub;

  // --- Proactive alert tracking (edge-triggered, not level-triggered,
  // so we notify once per new event instead of spamming every snapshot
  // while a condition remains true) ---
  bool _missedFeedingTrackingInitialized = false;
  int _lastNotifiedMissedCount = 0;
  bool _lowWaterAlertActive = false;

  void _subscribe() {
    _sub = _firebaseService.watchAquarium(aquariumId).listen(
      (data) {
        _checkForAlerts(data);
        _aquarium = data;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _checkForAlerts(AquariumModel next) {
    if (!next.exists) return;

    // Missed feedings: alert only on a fresh miss after app launch —
    // don't re-announce history that was already missed before this
    // session started, and reset the tracker if the count drops (the
    // user acknowledged it) so a later new miss alerts again.
    if (!_missedFeedingTrackingInitialized) {
      _lastNotifiedMissedCount = next.missedFeedingsCount;
      _missedFeedingTrackingInitialized = true;
    } else if (next.missedFeedingsCount > _lastNotifiedMissedCount) {
      _lastNotifiedMissedCount = next.missedFeedingsCount;
      _maybeNotify(
        title: '🍽️ Feeding missed',
        body: '${next.name} missed a scheduled feeding — check the hub or feed manually.',
        channelId: 'feeding_alerts',
        channelName: 'Feeding Alerts',
      );
    } else if (next.missedFeedingsCount < _lastNotifiedMissedCount) {
      _lastNotifiedMissedCount = next.missedFeedingsCount;
    }

    // Critical water level: alert on crossing below the threshold, not
    // on every snapshot while it stays low — recovering above it
    // re-arms the alert for next time.
    final water = next.waterLevel;
    if (water != null && water < _kLowWaterThreshold) {
      if (!_lowWaterAlertActive) {
        _lowWaterAlertActive = true;
        _maybeNotify(
          title: '⚠️ Critical: Low water level',
          body: '${next.name} water level is ${water.toStringAsFixed(0)}% — top up soon.',
          channelId: 'critical_alerts',
          channelName: 'Critical Alerts',
        );
      }
    } else {
      _lowWaterAlertActive = false;
    }
  }

  void _maybeNotify({
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) {
    if (_settingsProvider?.proactiveAlertsEnabled ?? true) {
      _notificationService?.show(
        title: title,
        body: body,
        channelId: channelId,
        channelName: channelName,
      );
    }
  }

  /// Requests an immediate feed via the command pattern in
  /// FirebaseService. Does not optimistically update local state — the
  /// Firestore listener above (and the feedingHistory stream in
  /// ScheduleProvider) are the sources of truth once the hub confirms.
  Future<void> sendManualFeed() {
    return _firebaseService.sendFeedCommand(aquariumId);
  }

  Future<void> recordWaterChange() {
    return _firebaseService.recordWaterChange(aquariumId);
  }

  Future<void> acknowledgeMissedFeedings() {
    return _firebaseService.acknowledgeMissedFeedings(aquariumId);
  }

  Future<void> toggleLight(bool on) {
    return _firebaseService.setLight(aquariumId, on);
  }

  Future<void> togglePump(bool on) {
    return _firebaseService.setPump(aquariumId, on);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
