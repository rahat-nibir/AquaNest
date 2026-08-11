import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/schedule_model.dart';
import '../services/firebase_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final String aquariumId;

  ScheduleProvider({
    required FirebaseService firebaseService,
    required this.aquariumId,
  }) : _firebaseService = firebaseService {
    _subscribe();
  }

  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> get schedules => _schedules;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  StreamSubscription<List<ScheduleModel>>? _sub;

  void _subscribe() {
    _sub = _firebaseService.watchSchedules(aquariumId).listen((data) {
      _schedules = data;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Adds a new feeding time. Optimistically does nothing locally —
  /// the Firestore snapshot listener above is the single source of
  /// truth, so the UI updates the moment the write is confirmed.
  Future<void> addSchedule(String formattedTime, String subtitle) {
    return _firebaseService.addSchedule(
      aquariumId,
      ScheduleModel(
        id: '',
        time: formattedTime,
        subtitle: subtitle,
        isActive: true,
      ),
    );
  }

  Future<void> toggleActive(ScheduleModel schedule, bool value) {
    return _firebaseService.setScheduleActive(
      aquariumId,
      schedule.id,
      value,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
