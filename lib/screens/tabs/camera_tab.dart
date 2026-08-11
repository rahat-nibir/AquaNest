import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aquarium_provider.dart';
import '../../providers/camera_provider.dart';
import '../../theme/app_theme.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Camera',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cameraProvider.latestFrame != null)
                    Image.memory(
                      cameraProvider.latestFrame!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  else if (aquarium.esp32StreamUrl.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_off_outlined,
                                color: Colors.white24, size: 32),
                            SizedBox(height: 10),
                            Text(
                              'No camera stream configured.\nSet esp32StreamUrl on this device in Firestore.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (cameraProvider.streamError != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Stream unavailable: ${cameraProvider.streamError}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.neonCyan),
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
                        child: const Row(
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: Colors.red),
                            SizedBox(width: 6),
                            Text('LIVE',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  const Positioned(
                    bottom: 16,
                    left: 16,
                    child: Text('ESP32-CAM  ·  720p',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
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
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  cameraProvider.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.neonCyan),
                        )
                      : const Icon(Icons.camera_alt_outlined,
                          color: AppColors.neonCyan, size: 20),
                  const SizedBox(width: 8),
                  const Text('Save Snapshot',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
              'Recent Gallery (${cameraProvider.recentSnapshots.length} Saved)',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (cameraProvider.recentSnapshots.isEmpty)
            const Text('No snapshots yet.',
                style: TextStyle(color: Colors.white38, fontSize: 13))
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
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      border: Border.all(color: AppColors.neonCyan),
                    ),
                    child: Image.network(
                      snap['url'] ?? '',
                      fit: BoxFit.cover,
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
