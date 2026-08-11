import 'package:flutter_test/flutter_test.dart';
import 'package:aquanest/theme/app_theme.dart';

// NOTE: This project's default `flutter create` counter test referenced a
// nonexistent `MyApp` class and tapped a '+' button that doesn't exist in
// AquaNest — that template is unrelated to this app and was deleted.
//
// Testing AquaNestApp's full widget tree isn't a simple pumpWidget() call:
// AuthProvider/AquariumProvider/etc. construct FirebaseService, which
// touches FirebaseFirestore.instance and FirebaseAuth.instance immediately
// on creation. Those throw in a plain widget test unless Firebase is
// mocked first via `setupFirebaseCoreMocks()` (package: firebase_core
// dev dependency `firebase_core_platform_interface`, plus fake_cloud_firestore
// / firebase_auth_mocks for the Firestore/Auth calls themselves).
//
// This smoke test keeps `flutter test` passing with something real rather
// than a token test — it exercises the app's design tokens, which don't
// depend on Firebase. If you want proper widget tests that actually pump
// screens (e.g. verifying LoginScreen shows an error on bad credentials),
// tell me and I'll wire up the Firebase mocks — it's a real chunk of setup,
// not a one-line addition.
void main() {
  test('AppTheme exposes the expected dark-theme background color', () {
    expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.background);
  });

  test('AppColors.neonCyan matches the design system spec (#00E5FF)', () {
    expect(AppColors.neonCyan.value, 0xFF00E5FF);
  });
}
