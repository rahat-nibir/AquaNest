import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/aquarium_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_icon_button.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  String _initials(String? email) {
    if (email == null || email.isEmpty) return '?';
    return email.substring(0, 1).toUpperCase();
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final controller =
        TextEditingController(text: authProvider.user?.displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0B182B),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Display name',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.neonCyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppColors.neonCyan)),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || !context.mounted) return;
    final ok = await authProvider.updateDisplayName(result);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Name updated.' : 'Could not update name.'),
      ),
    );
  }

  Future<void> _showPairDeviceDialog(BuildContext context) async {
    // This build uses a single fixed aquarium ID per the architecture
    // in main.dart (AquariumProvider.aquariumId) — there's no per-user
    // multi-tank pairing flow yet. Rather than fake a "Pair" action
    // that doesn't do anything real, this shows the ID the ESP32 hub
    // needs to be flashed/configured with, which is the actual
    // pairing step for this build.
    final aquariumId = context.read<AquariumProvider>().aquariumId;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0B182B),
        title: const Text('Pair New Device',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Multi-tank pairing isn\'t built yet — this app talks to a '
              'single fixed aquarium ID. To connect your ESP32 hub, flash '
              'it with this ID as its Firestore document path:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                aquariumId,
                style: const TextStyle(
                    color: AppColors.neonCyan,
                    fontFamily: 'monospace',
                    fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it', style: TextStyle(color: AppColors.neonCyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final aquarium = context.watch<AquariumProvider>().aquarium;
    final user = authProvider.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(_initials(user?.email),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'AquaNest User',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? 'Not signed in',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                GlassIconButton(
                  icon: Icons.edit_outlined,
                  onTap: () => _showEditProfileDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('DEVICE MANAGEMENT',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showPairDeviceDialog(context),
            child: GlassCard(
              borderColor: AppColors.neonCyan.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                        color: Color(0xFF0B182B), shape: BoxShape.circle),
                    child: const Icon(Icons.bluetooth,
                        color: AppColors.neonCyan, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pair New Device',
                            style: TextStyle(
                                color: AppColors.neonCyan,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 2),
                        Text('Connect Hub or ESP32',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: AppColors.neonCyan, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.memory,
                      color: Colors.white70, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(aquarium.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          CircleAvatar(
                              radius: 3,
                              backgroundColor: !aquarium.exists
                                  ? Colors.white24
                                  : aquarium.hubOnline
                                      ? AppColors.statusGreen
                                      : AppColors.statusRed),
                          const SizedBox(width: 6),
                          Text(
                              !aquarium.exists
                                  ? 'NOT SET UP'
                                  : aquarium.hubOnline
                                      ? 'ONLINE'
                                      : 'OFFLINE',
                              style: TextStyle(
                                  color: !aquarium.exists
                                      ? Colors.white38
                                      : aquarium.hubOnline
                                          ? AppColors.statusGreen
                                          : AppColors.statusRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.tune_rounded, color: Colors.white54, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.statusRed, size: 18),
                  SizedBox(width: 8),
                  Text('Sign Out',
                      style: TextStyle(
                          color: AppColors.statusRed,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
