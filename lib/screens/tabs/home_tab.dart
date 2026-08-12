import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/aquarium_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/feeding_history_tile.dart';

const _kBackground = Color(0xFF030712);
const _kCyan400 = Color(0xFF22D3EE);
const _kCyan500 = Color(0xFF06B6D4);
const _kBlue600 = Color(0xFF2563EB);
const _kAmber400 = Color(0xFFFBBF24);

TextStyle _mono(
    {required double size,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white}) {
  return GoogleFonts.jetBrainsMono(
      fontSize: size, fontWeight: weight, color: color);
}

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
    final bool waterChangeDue =
        !notPaired && (daysSinceWaterChange == null || daysSinceWaterChange >= 7);

    // NOTE: this deliberately does NOT wrap in its own Scaffold — this
    // widget lives inside DashboardScreen's IndexedStack, which is
    // already inside one Scaffold. A second nested Scaffold here was a
    // structural bug (risk of layout/z-order issues with the floating
    // bottom nav bar), not a style choice.
    return Container(
      color: _kBackground,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                                  ? _kCyan500
                                  : (notPaired ? Colors.white24 : _kAmber400),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isLive
                                ? 'ONLINE'
                                : (notPaired ? 'NOT PAIRED' : 'OFFLINE'),
                            style: GoogleFonts.outfit(
                              color: isLive
                                  ? _kCyan400
                                  : (notPaired ? Colors.white38 : _kAmber400),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        aquarium.name,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(Icons.notifications_none_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (notPaired || offline) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kAmber400.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: _kAmber400.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: _kAmber400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notPaired
                              ? 'No aquarium paired yet. Go to Settings → Pair New Device to connect your ESP32 hub.'
                              : "Device hasn't checked in recently — showing the last synced reading.",
                          style: GoogleFonts.outfit(
                            color: _kAmber400,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (!notPaired && aquarium.missedFeedingsCount > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
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
                      GestureDetector(
                        onTap: () => context
                            .read<AquariumProvider>()
                            .acknowledgeMissedFeedings(),
                        child: Text('Dismiss',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (waterChangeDue) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kCyan500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: _kCyan500.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.opacity_rounded,
                          color: _kCyan400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          daysSinceWaterChange == null
                              ? 'No water change logged yet for this tank.'
                              : 'Water change due — last one was $daysSinceWaterChange days ago.',
                          style: GoogleFonts.outfit(
                            color: _kCyan400,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context
                            .read<AquariumProvider>()
                            .recordWaterChange(),
                        child: Text('Mark done',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              // Water temperature — big glass card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.thermostat_rounded,
                              color: _kCyan400, size: 14),
                          const SizedBox(width: 6),
                          Text('Water Temp',
                              style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(tempDisplay,
                        style: _mono(size: 56, weight: FontWeight.w300)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.set_meal_outlined,
                      iconColor: Colors.orange.shade300,
                      value: foodDisplay,
                      label: 'Food Level',
                    ),
                  ),
                  const SizedBox(width: 16),
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
              const SizedBox(height: 16),
              if (!notPaired) ...[
                Row(
                  children: [
                    Expanded(
                      child: _HardwareToggleCard(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Light',
                        sublabel: aquarium.lightPhase,
                        value: aquarium.isLightOn,
                        onChanged: (v) =>
                            context.read<AquariumProvider>().toggleLight(v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _HardwareToggleCard(
                        icon: Icons.water_rounded,
                        label: 'Pump',
                        sublabel: null,
                        value: aquarium.isPumpOn,
                        onChanged: (v) =>
                            context.read<AquariumProvider>().togglePump(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              GestureDetector(
                onTap: notPaired ? null : () => _sendManualFeed(context),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kCyan500.withValues(alpha: notPaired ? 0.3 : 1),
                        _kBlue600.withValues(alpha: notPaired ? 0.3 : 1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
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
                                color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.chevron_right,
                                color: _kBlue600, size: 22),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!notPaired && feedingHistory.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Recent Feeding Activity',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    )),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < feedingHistory.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.06)),
                        FeedingHistoryTile(entry: feedingHistory[i]),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value
              ? _kCyan400.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? _kCyan400 : Colors.white38, size: 22),
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
                  style: GoogleFonts.outfit(
                      color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _kCyan400,
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: _mono(size: 26, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 3),
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
