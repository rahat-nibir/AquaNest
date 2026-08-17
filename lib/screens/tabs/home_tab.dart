import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/aquarium_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feeding_history_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tappable.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _sendManualFeed(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AquariumProvider>().sendManualFeed();
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('Feed command sent — waiting for the hub to pick it up.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send feed command: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final aquariumProvider = context.watch<AquariumProvider>();
    final aquarium = aquariumProvider.aquarium;
    final feedingHistory = context.watch<ScheduleProvider>().feedingHistory;

    final bool notPaired = !aquarium.exists;
    final bool offline = aquarium.exists && !aquarium.hubOnline;
    final bool isLive = aquarium.exists && aquarium.hubOnline;

    final String tempDisplay =
        notPaired ? '—' : '${aquarium.temperatureC.toStringAsFixed(1)}°';
    final String waterDisplay = aquarium.waterLevel == null
        ? '—'
        : '${aquarium.waterLevel!.toStringAsFixed(0)}%';
    final String foodDisplay = aquarium.foodLevel == null
        ? '—'
        : '${aquarium.foodLevel!.toStringAsFixed(0)}%';
    final String phDisplay =
        aquarium.phLevel == null ? '—' : aquarium.phLevel!.toStringAsFixed(1);

    // Water-change reminder: nudge at 7+ days since the last logged
    // change, or if none has ever been logged for a paired, live tank.
    final int? daysSinceWaterChange = aquarium.lastWaterChangeAt == null
        ? null
        : DateTime.now().difference(aquarium.lastWaterChangeAt!).inDays;
    final bool waterChangeDue = !notPaired &&
        (daysSinceWaterChange == null || daysSinceWaterChange >= 7);

    // NOTE: this deliberately does NOT wrap in its own Scaffold — this
    // widget lives inside DashboardScreen's IndexedStack, which is
    // already inside one Scaffold. A second nested Scaffold here was a
    // structural bug (risk of layout/z-order issues with the floating
    // bottom nav bar), not a style choice.
    //
    // Also deliberately does NOT paint its own opaque background color
    // anymore — DashboardScreen now renders one shared AuroraBackground
    // behind the whole IndexedStack, and an opaque fill here would hide
    // it for this tab only.
    return SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: aquariumProvider.isLoading
            ? const _HomeLoadingSkeleton(key: ValueKey('home-loading'))
            : SingleChildScrollView(
                key: const ValueKey('home-content'),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Brand Header with Notification Bell
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Image.asset(
                            'assets/NameIcon2.png',
                            height: 24, // Optimized height for the top bar
                            fit: BoxFit.contain,
                          ),
                        ),
                        Tappable(
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('No new notifications.'),
                            duration: Duration(seconds: 1),
                          )),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: const Icon(Icons.notifications_none_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // 2. Status and Aquarium Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLive
                                    ? AppColors.cyan500
                                    : (notPaired
                                        ? Colors.white24
                                        : AppColors.amber400),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isLive
                                  ? 'ONLINE'
                                  : (notPaired ? 'NOT PAIRED' : 'OFFLINE'),
                              style: GoogleFonts.outfit(
                                color: isLive
                                    ? AppColors.cyan400
                                    : (notPaired
                                        ? Colors.white38
                                        : AppColors.amber400),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          aquarium.name,
                          style: AppText.pageTitle(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    if (notPaired || offline) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.amber400.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: AppColors.amber400.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.amber400, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                notPaired
                                    ? 'No aquarium paired yet. Go to Settings → Pair New Device to connect your ESP32 hub.'
                                    : "Device hasn't checked in recently — showing the last synced reading.",
                                style: GoogleFonts.outfit(
                                  color: AppColors.amber400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (!notPaired && aquarium.missedFeedingsCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.report_problem_outlined,
                                color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                aquarium.missedFeedingsCount == 1
                                    ? '1 scheduled feeding was missed.'
                                    : '${aquarium.missedFeedingsCount} scheduled feedings were missed.',
                                style: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Tappable(
                              onTap: () => context
                                  .read<AquariumProvider>()
                                  .acknowledgeMissedFeedings(),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Text('Dismiss',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (waterChangeDue) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cyan500.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: AppColors.cyan500.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.opacity_rounded,
                                color: AppColors.cyan400, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                daysSinceWaterChange == null
                                    ? 'No water change logged yet for this tank.'
                                    : 'Water change due — last one was $daysSinceWaterChange days ago.',
                                style: GoogleFonts.outfit(
                                  color: AppColors.cyan400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Tappable(
                              onTap: () => context
                                  .read<AquariumProvider>()
                                  .recordWaterChange(),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                child: Text('Mark done',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    // Water temperature — big glass card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.thermostat_rounded,
                                    color: AppColors.cyan400, size: 14),
                                const SizedBox(width: 6),
                                Text('Water Temp',
                                    style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              tempDisplay,
                              key: ValueKey(tempDisplay),
                              style: AppText.mono(
                                  size: 56, weight: FontWeight.w300),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.water_drop_outlined,
                            iconColor: Colors.blue.shade300,
                            value: waterDisplay,
                            label: 'Water Level',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.set_meal_outlined,
                            iconColor: Colors.orange.shade300,
                            value: foodDisplay,
                            label: 'Food Level',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: _MetricCard(
                            icon: Icons.science_outlined,
                            iconColor: Colors.purple.shade300,
                            value: phDisplay,
                            label: 'pH Level',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (!notPaired) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _HardwareToggleCard(
                              icon: Icons.lightbulb_outline_rounded,
                              label: 'Light',
                              sublabel: aquarium.lightPhase,
                              value: aquarium.isLightOn,
                              onChanged: (v) => context
                                  .read<AquariumProvider>()
                                  .toggleLight(v),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: _HardwareToggleCard(
                              icon: Icons.water_rounded,
                              label: 'Pump',
                              sublabel: null,
                              value: aquarium.isPumpOn,
                              onChanged: (v) => context
                                  .read<AquariumProvider>()
                                  .togglePump(v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Tappable(
                      onTap: notPaired ? null : () => _sendManualFeed(context),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.cyan500
                                  .withValues(alpha: notPaired ? 0.3 : 1),
                              AppColors.blue600
                                  .withValues(alpha: notPaired ? 0.3 : 1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.set_meal_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Manual Feed',
                                        style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      notPaired
                                          ? 'Pair a device first'
                                          : 'Tap to dispense food now',
                                      style: GoogleFonts.outfit(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (!notPaired)
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.chevron_right,
                                      color: AppColors.blue600, size: 22),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!notPaired) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      Text('Recent Feeding Activity',
                          style: AppText.sectionLabel(color: Colors.white70)),
                      const SizedBox(height: AppSpacing.md),
                      feedingHistory.isEmpty
                          ? Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xl),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: const EmptyState(
                                icon: Icons.set_meal_outlined,
                                title: 'No feeding activity yet',
                                subtitle: 'Logged feedings will show up here.',
                              ),
                            )
                          : Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xl),
                                border: Border.all(color: AppColors.hairline),
                              ),
                              child: Column(
                                children: [
                                  for (int i = 0;
                                      i < feedingHistory.length;
                                      i++) ...[
                                    if (i > 0)
                                      Divider(
                                          height: 1,
                                          color: Colors.white
                                              .withValues(alpha: 0.06)),
                                    FeedingHistoryTile(
                                        entry: feedingHistory[i]),
                                  ],
                                ],
                              ),
                            ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// Shown while AquariumProvider's first Firestore snapshot is still in
/// flight, instead of silently rendering "—" placeholders that look
/// indistinguishable from "this metric doesn't exist."
class _HomeLoadingSkeleton extends StatefulWidget {
  const _HomeLoadingSkeleton({super.key});

  @override
  State<_HomeLoadingSkeleton> createState() => _HomeLoadingSkeletonState();
}

class _HomeLoadingSkeletonState extends State<_HomeLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _block({double width = double.infinity, double height = 16}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final t = _shimmerController.value;
        final opacity =
            0.05 + (0.04 * (0.5 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2)));
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(height / 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, 120),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _block(width: 90, height: 12),
          const SizedBox(height: 10),
          _block(width: 180, height: 28),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            width: double.infinity,
            height: 140,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(width: 100, height: 20),
                const Spacer(),
                _block(width: 120, height: 40),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? AppSpacing.lg : 0),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.hairline),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.hairline),
            ),
          ),
        ],
      ),
    );
  }
}

class _HardwareToggleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _HardwareToggleCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: value
                ? AppColors.cyan400.withValues(alpha: 0.4)
                : AppColors.hairline,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: value ? AppColors.cyan400 : Colors.white38, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(
                    sublabel ?? (value ? 'On' : 'Off'),
                    style:
                        GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.cyan400,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // Content-sized (no AspectRatio) fixed the 3-cards-per-row squeeze,
    // but that alone still assumes one specific text size. If the
    // device has a larger system text-scale setting (accessibility
    // "larger text"), the value/label render bigger than assumed and
    // can overflow again on the exact same layout. Wrapping the value
    // in FittedBox makes it shrink to fit instead of overflowing,
    // regardless of text-scale factor or how narrow the card gets.
    // (Left exactly as-is per the "don't break responsiveness" constraint.)
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: AppText.mono(size: 26, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
