import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/aurora_background.dart';
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

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // A short crossfade on tab switch, driven manually (not AnimatedSwitcher)
  // so the IndexedStack below keeps every tab mounted — losing a tab's
  // widget state (an in-progress chat draft, a scroll position) every time
  // you tap the nav bar would be a worse regression than the transition
  // is an improvement.
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..value = 1;

  static const _tabs = [
    HomeTab(),
    ScheduleTab(),
    CameraTab(),
    AquaAiTab(),
    SettingsTab(),
  ];

  void _onTabTap(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);
    _fadeController.forward(from: 0);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // One shared animated background for every tab — cheaper and
          // more consistent than each tab painting its own, and it's
          // why HomeTab no longer fills itself with a flat color.
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _fadeController,
                curve: Curves.easeOut,
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AquaBottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }
}
