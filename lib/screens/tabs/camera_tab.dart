import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/aquarium_ai_analysis.dart';
import '../../providers/aquarium_provider.dart';
import '../../providers/camera_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tappable.dart';

class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  bool _connectAttempted = false;

  @override
  Widget build(BuildContext context) {
    final aquarium = context.watch<AquariumProvider>().aquarium;
    final cameraProvider = context.watch<CameraProvider>();

    // Connect to the stream once we know the URL (comes from Firestore,
    // set by whoever provisioned the ESP32-CAM's IP/mDNS address).
    if (!_connectAttempted && aquarium.esp32StreamUrl.isNotEmpty) {
      _connectAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CameraProvider>().connect(aquarium.esp32StreamUrl);
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Camera', style: AppText.pageTitle()),
          const SizedBox(height: AppSpacing.xl),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.hairline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cameraProvider.latestFrame != null)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Image.memory(
                        cameraProvider.latestFrame!,
                        key: ValueKey(cameraProvider.latestFrame.hashCode),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  else if (aquarium.esp32StreamUrl.isEmpty)
                    const EmptyState(
                      icon: Icons.videocam_off_outlined,
                      title: 'No camera stream configured',
                      subtitle: 'Set esp32StreamUrl on this device in Firestore.',
                    )
                  else if (cameraProvider.streamError != null)
                    EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Stream unavailable',
                      subtitle: cameraProvider.streamError,
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.cyan400),
                    ),
                  if (cameraProvider.isLive)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const _PulsingDot(),
                            const SizedBox(width: 6),
                            Text('LIVE', style: AppText.cardTitle(color: Colors.redAccent, size: 11)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Text('ESP32-CAM  ·  720p',
                        style: AppText.cardSubtitle()),
                  ),
                  if (cameraProvider.isLive)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: _AiStatusBadge(status: cameraProvider.aiStatus),
                    ),
                ],
              ),
            ),
          ),
          if (cameraProvider.isLive && cameraProvider.aiAnalysis != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _AiSummaryLine(analysis: cameraProvider.aiAnalysis!),
          ],
          const SizedBox(height: AppSpacing.lg),
          Tappable(
            onTap: cameraProvider.isSaving
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await cameraProvider.saveSnapshot();
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Snapshot saved!'),
                            duration: Duration(seconds: 1)),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Could not save snapshot: $e')),
                      );
                    }
                  },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  cameraProvider.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.cyan400),
                        )
                      : const Icon(Icons.camera_alt_outlined,
                          color: AppColors.cyan400, size: 20),
                  const SizedBox(width: 8),
                  Text('Save Snapshot', style: AppText.cardTitle()),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
              'Recent Gallery (${cameraProvider.recentSnapshots.length} Saved)',
              style: AppText.cardTitle(size: 16)),
          const SizedBox(height: AppSpacing.md),
          if (cameraProvider.recentSnapshots.isEmpty)
            const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No snapshots yet',
              padding: EdgeInsets.symmetric(vertical: 24),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cameraProvider.recentSnapshots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final snap = cameraProvider.recentSnapshots[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Image.network(
                      snap['url'] ?? '',
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, wasSyncLoaded) {
                        if (wasSyncLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: child,
                        );
                      },
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.cyan400),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white24),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

/// The "traffic signal" badge: a colored dot + label reflecting the
/// most recent silent AI frame analysis. Grey/"Monitoring" before the
/// first analysis completes — deliberately not green-by-default, since
/// a badge that says "Healthy" before the AI has looked at anything
/// would just be a lie dressed up as reassurance.
class _AiStatusBadge extends StatelessWidget {
  final AiHealthStatus status;
  const _AiStatusBadge({required this.status});

  (Color, String) get _visual => switch (status) {
        AiHealthStatus.healthy => (AppColors.statusGreen, 'Healthy'),
        AiHealthStatus.warning => (AppColors.amber400, 'Warning'),
        AiHealthStatus.critical => (AppColors.statusRed, 'Critical'),
        AiHealthStatus.unknown => (Colors.white38, 'Monitoring…'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, label) = _visual;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.cardTitle(color: color, size: 11)),
        ],
      ),
    );
  }
}

/// One-line caption under the video: what the AI last saw and when.
/// Kept intentionally terse — this is a passive status line, not
/// another chat surface.
class _AiSummaryLine extends StatelessWidget {
  final AquariumAiAnalysis analysis;
  const _AiSummaryLine({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (analysis.species != null && analysis.species!.isNotEmpty)
        analysis.species!,
      if (analysis.activityLevel != null && analysis.activityLevel!.isNotEmpty)
        '${analysis.activityLevel} activity',
    ];
    final label = parts.isEmpty
        ? (analysis.summary ?? 'AI health check')
        : parts.join(' · ');

    return Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: AppColors.cyan400, size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppText.cardSubtitle(size: 12),
          ),
        ),
        Text(
          shortRelativeTimeLabel(analysis.analyzedAt),
          style: AppText.cardSubtitle(color: Colors.white24, size: 11),
        ),
      ],
    );
  }
}

/// Small breathing "LIVE" dot instead of a flat, static one — a cheap
/// but very legible signal that the feed is actually live right now.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_controller),
      child: const CircleAvatar(radius: 3, backgroundColor: Colors.red),
    );
  }
}
