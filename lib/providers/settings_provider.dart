import 'package:flutter/foundation.dart';

/// Holds app-level toggle state that isn't tied to one specific
/// aquarium document. Currently just the proactive-alerts switch, but
/// this is the natural home for future local-only preferences.
///
/// NOTE: in-memory only for now — it resets to the default (on) each
/// app launch. Wiring in `shared_preferences` to persist it wasn't
/// part of what was asked for and adds a new dependency, so it's left
/// as a follow-up rather than added silently.
class SettingsProvider extends ChangeNotifier {
  bool _proactiveAlertsEnabled = true;
  bool get proactiveAlertsEnabled => _proactiveAlertsEnabled;

  void setProactiveAlertsEnabled(bool value) {
    if (_proactiveAlertsEnabled == value) return;
    _proactiveAlertsEnabled = value;
    notifyListeners();
  }
}
