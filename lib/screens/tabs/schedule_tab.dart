import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/feeding_history_tile.dart';

class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key});

  Future<void> _addNewSchedule(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null || !context.mounted) return;

    final formattedTime = pickedTime.format(context);
    await context.read<ScheduleProvider>().addSchedule(
          formattedTime,
          'Every day · Standard portion',
        );
  }

  void _showFeedHistorySheet(BuildContext context) {
    final scheduleProvider = context.read<ScheduleProvider>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B182B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetContext, scrollController) {
            return AnimatedBuilder(
              animation: scheduleProvider,
              builder: (context, _) {
                final history = scheduleProvider.feedingHistory;
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text('Feed History Logs',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: scheduleProvider.feedingHistoryLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.neonCyan))
                          : history.isEmpty
                              ? const Center(
                                  child: Text('No feeding history yet.',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 13)))
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  itemCount: history.length,
                                  separatorBuilder: (_, __) => Divider(
                                      height: 1,
                                      color:
                                          Colors.white.withValues(alpha: 0.06)),
                                  itemBuilder: (context, index) =>
                                      FeedingHistoryTile(entry: history[index]),
                                ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, scheduleProvider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Schedule',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Automated feeding cycles',
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 24),
              if (scheduleProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.neonCyan)),
                )
              else if (scheduleProvider.schedules.isEmpty)
                const Text('No feeding times set yet.',
                    style: TextStyle(color: Colors.white38))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scheduleProvider.schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = scheduleProvider.schedules[index];
                    return GlassCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.time,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: TextStyle(
                                    color: item.isActive
                                        ? AppColors.neonCyan
                                        : Colors.white38,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          Switch(
                            value: item.isActive,
                            onChanged: (val) => scheduleProvider.toggleActive(
                                item, val),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _addNewSchedule(context),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.neonCyan.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: AppColors.neonCyan, size: 20),
                      SizedBox(width: 8),
                      Text('Add New Time',
                          style: TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _showFeedHistorySheet(context),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('View Feed History Logs',
                        style: TextStyle(color: Colors.white70, fontSize: 15)),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.neonCyan, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }
}
