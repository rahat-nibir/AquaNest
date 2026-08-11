import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/aquarium_model.dart';
import '../services/firebase_service.dart';

/// Holds the live status of the currently selected aquarium hub.
/// Replaces the hardcoded "Living Room Reef · Stable (26.5°C)" text
/// with a real Firestore subscription.
class AquariumProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final String aquariumId;

  AquariumProvider({
    required FirebaseService firebaseService,
    required this.aquariumId,
  }) : _firebaseService = firebaseService {
    _subscribe();
  }

  AquariumModel _aquarium = AquariumModel.empty();
  AquariumModel get aquarium => _aquarium;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  StreamSubscription<AquariumModel>? _sub;

  void _subscribe() {
    _sub = _firebaseService.watchAquarium(aquariumId).listen(
      (data) {
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
