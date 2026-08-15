import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message_model.dart';
import '../../providers/aquarium_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/tappable.dart';

class AquaAiTab extends StatefulWidget {
  const AquaAiTab({super.key});

  @override
  State<AquaAiTab> createState() => _AquaAiTabState();
}

class _AquaAiTabState extends State<AquaAiTab> {
  final TextEditingController _chatController = TextEditingController();

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  void _send(BuildContext context) {
    final text = _chatController.text;
    if (text.trim().isEmpty) return;
    // The user never has to type "my pH is 7.2, I fed at 9am" — the
    // live sensor state and recent feeding log ride along automatically
    // so Aqua AI is always answering from the tank's actual condition.
    final aquarium = context.read<AquariumProvider>().aquarium;
    final feedingHistory = context.read<ScheduleProvider>().feedingHistory;
    context.read<ChatProvider>().sendMessage(
          text,
          aquariumContext: aquarium,
          feedingHistory: feedingHistory,
        );
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aqua AI', style: AppText.pageTitle()),
                  const SizedBox(height: 2),
                  Text('Smart Assistant',
                      style: AppText.body(color: AppColors.cyan400, size: 13)),
                ],
              ),
              GlassIconButton(
                icon: Icons.refresh_rounded,
                onTap: () => context.read<ChatProvider>().resetChat(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: chatProvider.messages.length + (chatProvider.isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              // reverse:true means index 0 renders at the bottom (newest),
              // which is exactly where the typing indicator and latest
              // message belong — this also gives free auto-scroll-to-
              // -bottom behavior on new messages without a ScrollController.
              if (chatProvider.isTyping && index == 0) {
                return const _TypingIndicator();
              }
              final messageIndex = chatProvider.messages.length -
                  1 -
                  (index - (chatProvider.isTyping ? 1 : 0));
              final msg = chatProvider.messages[messageIndex];
              final bubble = msg.sender == ChatSender.bot
                  ? _buildBotBubble(msg)
                  : _buildUserBubble(msg);
              // Newest message (index 0, or index 1 while typing) gets a
              // gentle entrance instead of just popping into place.
              final isNewest = index == (chatProvider.isTyping ? 1 : 0);
              if (!isNewest) return bubble;
              return TweenAnimationBuilder<double>(
                key: ValueKey(msg.hashCode),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 8),
                    child: child,
                  ),
                ),
                child: bubble,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 95),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    onSubmitted: (_) => _send(context),
                    style: AppText.body(size: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ask Aqua AI...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Tappable(
                  onTap: () => _send(context),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: AppColors.cyan400, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.black, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBotBubble(ChatMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline)),
            child: const Icon(Icons.smart_toy_outlined,
                color: AppColors.cyan400, size: 16),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: msg.isError
                    ? AppColors.statusRed.withValues(alpha: 0.15)
                    : AppColors.chatSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(msg.text, style: AppText.body()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(ChatMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(msg.text, style: AppText.body()),
        ),
      ),
    );
  }
}

/// Three breathing dots instead of a static "Aqua AI is typing…" line —
/// reads as "still working" at a glance instead of needing to be read.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 42),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.chatSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_controller.value - (i * 0.2)) % 1.0 + 1.0) % 1.0;
                final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: 0.4 + 0.6 * scale,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.cyan400,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
