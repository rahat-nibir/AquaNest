import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;

  AuthProvider({required FirebaseService firebaseService})
      : _firebaseService = firebaseService {
    _sub = _firebaseService.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? _user;
  User? get user => _user;
  bool get isSignedIn => _user != null;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _authError;
  String? get authError => _authError;

  StreamSubscription<User?>? _sub;

  Future<bool> signIn(String email, String password) async {
    _isSubmitting = true;
    _authError = null;
    notifyListeners();

    try {
      await _firebaseService.signIn(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      _authError = e.message ?? 'Sign in failed.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _firebaseService.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
