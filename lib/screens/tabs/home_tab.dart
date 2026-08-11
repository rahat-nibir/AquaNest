import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/aquarium_provider.dart';

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

  Future<void> _sendManualFeed(BuildContext context, String aquariumId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('aquariums')
          .doc(aquariumId)
          .collection('commands')
          .add({
        'type': 'feed_now',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
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
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: notPaired
                    ? null
                    : () => _sendManualFeed(context, aquarium.id),
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
                            child: Icon(Icons.chevron_right,
                                color: _kBlue600, size: 22),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(value, style: _mono(size: 32, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
