import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aquanest/providers/aquarium_provider.dart';
import 'package:aquanest/screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Firebase.initializeApp() call will be added after flutterfire configure
  runApp(const AquaNestApp());
}

class AquaNestApp extends StatelessWidget {
  const AquaNestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AquariumProvider(),
      child: MaterialApp(
        title: 'AquaNest',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
        home: const DashboardScreen(),
      ),
    );
  }
}
