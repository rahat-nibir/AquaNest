import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message_model.dart';
import '../../providers/aquarium_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_icon_button.dart';

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
    final aquarium = context.read<AquariumProvider>().aquarium;
    context.read<ChatProvider>().sendMessage(text, aquariumContext: aquarium);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aqua AI',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Smart Assistant',
                      style: TextStyle(color: AppColors.neonCyan, fontSize: 13)),
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: chatProvider.messages.length + (chatProvider.isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == chatProvider.messages.length) {
                return _buildTypingIndicator();
              }
              final msg = chatProvider.messages[index];
              return msg.sender == ChatSender.bot
                  ? _buildBotBubble(msg)
                  : _buildUserBubble(msg);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 95),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    onSubmitted: (_) => _send(context),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ask Aqua AI...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _send(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: AppColors.neonCyan, shape: BoxShape.circle),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10)),
            child: const Icon(Icons.smart_toy_outlined,
                color: AppColors.neonCyan, size: 16),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: msg.isError
                    ? AppColors.statusRed.withValues(alpha: 0.15)
                    : AppColors.chatSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(msg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(ChatMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16, left: 42),
      child: Text('Aqua AI is typing…',
          style: TextStyle(color: Colors.white38, fontSize: 12)),
    );
  }
}
