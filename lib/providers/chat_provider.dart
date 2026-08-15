import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../models/aquarium_model.dart';
import '../models/feeding_log_model.dart';
import '../services/gemini_service.dart';

class ChatProvider extends ChangeNotifier {
  final GeminiService _geminiService;

  ChatProvider({required GeminiService geminiService})
      : _geminiService = geminiService {
    _resetGreeting();
  }

  final List<ChatMessageModel> _messages = [];
  List<ChatMessageModel> get messages => List.unmodifiable(_messages);

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  void _resetGreeting() {
    _messages.clear();
    _messages.add(ChatMessageModel(
      sender: ChatSender.bot,
      text: 'Hello! How can I assist you with your aquarium today?',
    ));
  }

  void resetChat() {
    _geminiService.startNewSession();
    _resetGreeting();
    notifyListeners();
  }

  Future<void> sendMessage(
    String text, {
    AquariumModel? aquariumContext,
    List<FeedingLogEntry>? feedingHistory,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    _messages.add(ChatMessageModel(sender: ChatSender.user, text: trimmed));
    _isTyping = true;
    notifyListeners();

    try {
      final reply = await _geminiService.sendMessage(
        trimmed,
        context: aquariumContext,
        feedingHistory: feedingHistory,
      );
      _messages.add(ChatMessageModel(sender: ChatSender.bot, text: reply));
    } catch (e) {
      _messages.add(ChatMessageModel(
        sender: ChatSender.bot,
        text: 'Something went wrong reaching Aqua AI: $e',
        isError: true,
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }
}
