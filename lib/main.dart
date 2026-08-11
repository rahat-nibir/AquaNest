import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';

import 'services/firebase_service.dart';
import 'services/gemini_service.dart';
import 'services/esp32cam_service.dart';

import 'providers/auth_provider.dart';
import 'providers/aquarium_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/camera_provider.dart';
import 'providers/chat_provider.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

/// Change this if you support multiple tanks per user — for a single
/// university-project demo tank, a fixed ID keeps the plumbing simple.
const String kDefaultAquariumId = 'living-room-reef';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads GEMINI_API_KEY (and anything else you add) from .env at the
  // project root. .env must NOT be committed — see .gitignore note in
  // the README this project ships with.
  await dotenv.load(fileName: '.env');

  // Firebase Duplicate Init Crash Fix — only swallow the specific
  // "already initialized" case. Anything else (bad API key, malformed
  // firebase_options.dart, network issues) should surface as a real
  // crash, not get hidden behind a misleading debugPrint that makes
  // you think startup succeeded when it didn't.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    debugPrint('[Firebase] App already initialized, skipping re-init.');
  }

  runApp(const AquaNestApp());
}

class AquaNestApp extends StatelessWidget {
  const AquaNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final geminiService = GeminiService(
      apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
    );

    return MultiProvider(
      providers: [
        Provider<FirebaseService>.value(value: firebaseService),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(firebaseService: firebaseService),
        ),
        ChangeNotifierProvider(
          create: (_) => AquariumProvider(
            firebaseService: firebaseService,
            aquariumId: kDefaultAquariumId,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ScheduleProvider(
            firebaseService: firebaseService,
            aquariumId: kDefaultAquariumId,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CameraProvider(
            camService: Esp32CamService(),
            firebaseService: firebaseService,
            aquariumId: kDefaultAquariumId,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(geminiService: geminiService),
        ),
      ],
      child: MaterialApp(
        title: 'AquaNest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: '/login',
        routes: {
          '/login': (_) => const AuthGate(),
          '/dashboard': (_) => const DashboardScreen(),
        },
      ),
    );
  }
}

/// Skips the login screen automatically if Firebase already has a
/// signed-in user (e.g. app relaunch), otherwise shows LoginScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isSignedIn) {
      return const DashboardScreen();
    }
    return const LoginScreen();
  }
}
