import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/aquarium_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/tappable.dart';

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
        backgroundColor: AppColors.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Edit Profile', style: AppText.cardTitle(size: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppText.body(),
          decoration: const InputDecoration(
            labelText: 'Display name',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.cyan400)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppColors.cyan400)),
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
        backgroundColor: AppColors.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Pair New Device', style: AppText.cardTitle(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multi-tank pairing isn\'t built yet — this app talks to a '
              'single fixed aquarium ID. To connect your ESP32 hub, flash '
              'it with this ID as its Firestore document path:',
              style: AppText.body(color: Colors.white70, size: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cyan400.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                aquariumId,
                style: const TextStyle(
                    color: AppColors.cyan400,
                    fontFamily: 'monospace',
                    fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it', style: TextStyle(color: AppColors.cyan400)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Sign Out?', style: AppText.cardTitle(size: 18)),
        content: Text(
          'You\'ll need to sign back in to control your aquarium from this device.',
          style: AppText.body(color: Colors.white70, size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.statusRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final aquarium = context.watch<AquariumProvider>().aquarium;
    final user = authProvider.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: AppText.pageTitle()),
          const SizedBox(height: AppSpacing.xl),
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
                        style: AppText.cardTitle(size: 18)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'AquaNest User',
                          style: AppText.cardTitle(size: 16)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? 'Not signed in',
                          style: AppText.cardSubtitle(size: 13)),
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
          const SizedBox(height: AppSpacing.xxl),
          Text('DEVICE MANAGEMENT', style: AppText.sectionLabel()),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            onTap: () => _showPairDeviceDialog(context),
            borderColor: AppColors.cyan400.withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                      color: AppColors.sheet, shape: BoxShape.circle),
                  child: const Icon(Icons.bluetooth,
                      color: AppColors.cyan400, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pair New Device',
                          style: AppText.cardTitle(color: AppColors.cyan400)),
                      const SizedBox(height: 2),
                      Text('Connect Hub or ESP32', style: AppText.cardSubtitle()),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.cyan400, size: 14),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
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
                      Text(aquarium.name, style: AppText.cardTitle()),
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
          const SizedBox(height: AppSpacing.xxl),
          Text('PROACTIVE AI ALERTS', style: AppText.sectionLabel()),
          const SizedBox(height: AppSpacing.md),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return GlassCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (settings.proactiveAlertsEnabled
                                ? AppColors.cyan400
                                : Colors.white24)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: settings.proactiveAlertsEnabled
                            ? AppColors.cyan400
                            : Colors.white38,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Proactive Alerts', style: AppText.cardTitle()),
                          const SizedBox(height: 2),
                          Text(
                            'Push notifications for missed feedings, low water,\nand AI-detected fish health issues.',
                            style: AppText.cardSubtitle(size: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.proactiveAlertsEnabled,
                      onChanged: settings.setProactiveAlertsEnabled,
                      activeThumbColor: AppColors.cyan400,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          Tappable(
            onTap: () => _confirmSignOut(context),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: AppColors.statusRed, size: 18),
                  const SizedBox(width: 8),
                  Text('Sign Out',
                      style: AppText.cardTitle(color: AppColors.statusRed)),
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
