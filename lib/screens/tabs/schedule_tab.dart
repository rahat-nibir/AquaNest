import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/feeding_history_tile.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/tappable.dart';

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
      backgroundColor: AppColors.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text('Feed History Logs', style: AppText.cardTitle(size: 18)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: scheduleProvider.feedingHistoryLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.cyan400))
                          : history.isEmpty
                              ? const EmptyState(
                                  icon: Icons.history_rounded,
                                  title: 'No feeding history yet',
                                )
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
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Schedule', style: AppText.pageTitle()),
              const SizedBox(height: 4),
              Text('Automated feeding cycles', style: AppText.pageSubtitle()),
              const SizedBox(height: AppSpacing.xxl),
              if (scheduleProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                      child: CircularProgressIndicator(color: AppColors.cyan400)),
                )
              else if (scheduleProvider.schedules.isEmpty)
                const EmptyState(
                  icon: Icons.schedule_rounded,
                  title: 'No feeding times set yet',
                  subtitle: 'Add one below to automate feeding.',
                  padding: EdgeInsets.symmetric(vertical: 24),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scheduleProvider.schedules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
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
                                  style: AppText.mono(size: 22, weight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: AppText.cardSubtitle(
                                  color: item.isActive
                                      ? AppColors.cyan400
                                      : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: item.isActive,
                            onChanged: (val) =>
                                scheduleProvider.toggleActive(item, val),
                            activeThumbColor: AppColors.cyan400,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.xl),
              Tappable(
                onTap: () => _addNewSchedule(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.cyan400.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: AppColors.cyan400, size: 20),
                      const SizedBox(width: 8),
                      Text('Add New Time', style: AppText.cardTitle(color: AppColors.cyan400)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Tappable(
                onTap: () => _showFeedHistorySheet(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('View Feed History Logs',
                          style: AppText.body(color: Colors.white70, size: 15)),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: AppColors.cyan400, size: 16),
                    ],
                  ),
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
