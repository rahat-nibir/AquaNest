import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/feeding_log_model.dart';
import '../theme/app_theme.dart';
import '../utils/date_format_utils.dart';

/// One row in a feeding-history list — used on the Home tab's "Recent
/// Feeding Activity" preview and the Schedule tab's full history sheet,
/// so the two stay visually consistent instead of drifting apart.
class FeedingHistoryTile extends StatelessWidget {
  final FeedingLogEntry entry;

  const FeedingHistoryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final bool missed = entry.isMissed;
    final Color accent = missed ? AppColors.statusRed : AppColors.neonCyan;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              missed ? Icons.close_rounded : Icons.check_rounded,
              color: accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missed ? 'Missed feeding' : 'Fed successfully',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  entry.source == 'manual' ? 'Manual' : 'Scheduled',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${relativeDayLabel(entry.feedAt)} · ${clockTimeLabel(entry.feedAt)}',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
