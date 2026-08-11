import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import 'tabs/home_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/camera_tab.dart';
import 'tabs/aqua_ai_tab.dart';
import 'tabs/settings_tab.dart';

/// Pure UI shell. All the state that used to live in this file's
/// StatefulWidget (schedules, snapshotCount, chatMessages) now lives in
/// AquariumProvider / ScheduleProvider / CameraProvider / ChatProvider,
/// scoped in main.dart and consumed independently by each tab.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    HomeTab(),
    ScheduleTab(),
    CameraTab(),
    AquaAiTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AquaBottomNavBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
          ),
        ],
      ),
    );
  }
}
